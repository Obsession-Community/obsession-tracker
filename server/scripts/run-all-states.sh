#!/bin/bash
# Historical Maps Processing Script
# Downloads USGS historical topographic maps and converts to MBTiles
#
# Usage:
#   ./run-all-states.sh                    # Process all 48 states (skip completed)
#   ./run-all-states.sh --force            # Force reprocess all (keeps downloads)
#   ./run-all-states.sh IL IN KY           # Process specific states
#   ./run-all-states.sh --force IL IN KY   # Force reprocess specific states
#
# Downloads are preserved for verification. Output is replaced on reprocess.

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPTS_DIR}/historical_maps_workspace"
DOWNLOADS_DIR="${BASE_DIR}/downloads"
OUTPUT_DIR="${BASE_DIR}/output"
LOG_FILE="${BASE_DIR}/processing.log"

# All 48 continental states
ALL_STATES=(
    AL AR AZ CA CO CT DE FL GA IA ID IL IN KS KY LA MA MD ME MI
    MN MO MS MT NC ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN
    TX UT VA VT WA WI WV WY
)

# Date range for early topo era
START_DATE="1880-01-01"
END_DATE="1925-01-01"
NUM_CORES=8

# Rate limit settings
DELAY_BETWEEN_STATES=3       # Seconds between states
RETRY_DELAY_BASE=60          # Base seconds to wait on failure
RETRY_DELAY_MAX=600          # Max delay between retries (10 min)
MAX_RETRIES=10               # Max retries per state download (with backoff, ~2 hours total)

# Flags
FORCE_REPROCESS=false
STATES_TO_PROCESS=()

# ============================================
# Functions
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    cat << EOF
Historical Maps Processing Script

Downloads USGS historical topographic maps (1880-1925) and converts to MBTiles.

USAGE:
    $0 [OPTIONS] [STATE_CODES...]

OPTIONS:
    --force     Force reprocess (removes output, keeps downloads)
    --help      Show this help message

ARGUMENTS:
    STATE_CODES Optional list of 2-letter state codes to process.
                If omitted, processes all 48 continental US states.

EXAMPLES:
    $0                      # Process all states (skip completed)
    $0 --force              # Force reprocess all (uses existing downloads)
    $0 IL IN KY LA          # Process only these states
    $0 --force IL IN        # Force reprocess IL and IN (uses existing downloads)

RATE LIMITING:
    - ${DELAY_BETWEEN_STATES}s delay between states
    - ${MAX_RETRIES} retry attempts with exponential backoff
    - Downloads preserved for verification

OUTPUT:
    historical_maps_workspace/output/{STATE}/maps/early_topo/quads/*.mbtiles
EOF
    exit 0
}

# Download with retry and rate limit handling
download_with_retry() {
    local state="$1"
    local download_dir="$2"
    local retries=0
    local delay=$RETRY_DELAY_BASE

    while [ $retries -lt $MAX_RETRIES ]; do
        retries=$((retries + 1))
        log "Download attempt $retries/$MAX_RETRIES for $state..."

        # Run download script
        local download_output
        local exit_code=0
        download_output=$("${SCRIPTS_DIR}/download-usgs-maps.sh" \
            "$state" \
            "$download_dir" \
            "GeoTIFF" \
            "$START_DATE" \
            "$END_DATE" 2>&1) || exit_code=$?

        # Log output
        echo "$download_output" >> "$LOG_FILE"

        # Check if files were downloaded FIRST (before checking for errors)
        local file_count
        file_count=$(find "$download_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | wc -l | tr -d ' ')

        if [ "$file_count" -gt 0 ]; then
            log "Successfully downloaded $file_count files for $state"
            return 0
        fi

        # Only check for rate limits if we have NO files
        # Look for explicit rate limit messages (not just any occurrence of numbers)
        if echo "$download_output" | grep -qi "rate.limit\|too.many.requests\|HTTP.*429\|HTTP.*503\|throttl"; then
            log "Rate limit detected (0 files). Waiting ${delay}s before retry..."
            sleep $delay
            delay=$((delay * 2))
            [ $delay -gt $RETRY_DELAY_MAX ] && delay=$RETRY_DELAY_MAX
            continue
        fi

        # Check if API explicitly returned 0 downloadable files
        if echo "$download_output" | grep -q "Found 0 downloadable"; then
            log "API returned 0 downloadable files for $state. Waiting ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
            [ $delay -gt $RETRY_DELAY_MAX ] && delay=$RETRY_DELAY_MAX
            continue
        fi

        # Script failed for another reason
        if [ $exit_code -ne 0 ]; then
            log "Download script failed (exit $exit_code). Waiting ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
            [ $delay -gt $RETRY_DELAY_MAX ] && delay=$RETRY_DELAY_MAX
            continue
        fi

        # Unknown issue - retry anyway
        log "Download returned 0 files (unknown reason). Waiting ${delay}s..."
        sleep $delay
        delay=$((delay * 2))
        [ $delay -gt $RETRY_DELAY_MAX ] && delay=$RETRY_DELAY_MAX
    done

    log "ERROR: All $MAX_RETRIES attempts failed for $state"
    return 1
}

# Check if state has complete output
is_state_complete() {
    local state="$1"
    local output_quads="${OUTPUT_DIR}/${state}/maps/early_topo/quads"

    if [ ! -d "$output_quads" ]; then
        return 1
    fi

    local mbtiles_count
    mbtiles_count=$(find "$output_quads" -name "*.mbtiles" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$mbtiles_count" -eq 0 ]; then
        return 1
    fi

    # Sample check - verify a few files have completion markers
    local sample_check
    sample_check=$(find "$output_quads" -name "*.mbtiles" 2>/dev/null | head -5 | while read -r mbtiles; do
        marker=$(sqlite3 "$mbtiles" "SELECT value FROM metadata WHERE name='processing_complete';" 2>/dev/null || echo "")
        tiles=$(sqlite3 "$mbtiles" "SELECT COUNT(*) FROM tiles;" 2>/dev/null || echo "0")
        if [ "$marker" != "1" ] || [ "$tiles" = "0" ]; then
            echo "incomplete"
            break
        fi
    done)

    if [ "$sample_check" = "incomplete" ]; then
        return 1
    fi

    return 0
}

# Process a single state
process_state() {
    local state="$1"
    local download_dir="${DOWNLOADS_DIR}/${state}/early_topo"
    local output_quads="${OUTPUT_DIR}/${state}/maps/early_topo/quads"

    # Check if already complete (unless force)
    if [ "$FORCE_REPROCESS" = false ] && is_state_complete "$state"; then
        local count
        count=$(find "$output_quads" -name "*.mbtiles" 2>/dev/null | wc -l | tr -d ' ')
        log "$state: Already complete ($count quads verified) - skipping"
        return 0
    fi

    # Force mode: remove existing output (but keep downloads)
    if [ "$FORCE_REPROCESS" = true ] && [ -d "$output_quads" ]; then
        log "$state: Removing existing output for reprocessing..."
        rm -rf "$output_quads"
    fi

    # Create download directory
    mkdir -p "$download_dir"

    # Check existing downloads
    local existing_downloads
    existing_downloads=$(find "$download_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | wc -l | tr -d ' ')

    # Download only if no existing downloads (force does NOT re-download)
    if [ "$existing_downloads" = "0" ]; then
        if ! download_with_retry "$state" "$download_dir"; then
            log "WARNING: Download failed for $state"
            return 1
        fi
    else
        log "$state: Using existing $existing_downloads downloads"
    fi

    # Verify we have files to process
    local file_count
    file_count=$(find "$download_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$file_count" -eq 0 ]; then
        log "WARNING: No GeoTIFFs for $state after download"
        return 1
    fi

    log "$state: Processing $file_count GeoTIFFs with $NUM_CORES cores..."

    # Process to MBTiles
    if "${SCRIPTS_DIR}/process-quadrangles.sh" \
        "$state" \
        "$download_dir" \
        "$OUTPUT_DIR" \
        "early_topo" \
        "$NUM_CORES" 2>&1 | tee -a "$LOG_FILE" | grep -E "Created:|FAILED:|Total:|complete" | tail -5; then

        local final_count
        final_count=$(find "$output_quads" -name "*.mbtiles" 2>/dev/null | wc -l | tr -d ' ')
        log "$state: Created $final_count quadrangles"
        return 0
    else
        log "ERROR: Processing failed for $state"
        return 1
    fi
}

# ============================================
# Parse Arguments
# ============================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_REPROCESS=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            # Validate state code (2 letters)
            if [[ "$1" =~ ^[A-Z]{2}$ ]]; then
                STATES_TO_PROCESS+=("$1")
            else
                echo "ERROR: Invalid state code '$1'. Use 2-letter codes like IL, NY, CA."
                exit 1
            fi
            shift
            ;;
    esac
done

# Default to all states if none specified
if [ ${#STATES_TO_PROCESS[@]} -eq 0 ]; then
    STATES_TO_PROCESS=("${ALL_STATES[@]}")
fi

# ============================================
# Main
# ============================================

mkdir -p "$DOWNLOADS_DIR" "$OUTPUT_DIR"

# Append to existing log or create new
echo "" >> "$LOG_FILE"
log "=========================================="
log "Historical Maps Processing"
log "=========================================="
log "States to process: ${#STATES_TO_PROCESS[@]}"
log "Force reprocess: $FORCE_REPROCESS"
log "Rate limit: ${DELAY_BETWEEN_STATES}s between states, ${MAX_RETRIES} retries"
log "States: ${STATES_TO_PROCESS[*]}"
log ""

total=${#STATES_TO_PROCESS[@]}
current=0
completed=0
failed=0
skipped=0

for state in "${STATES_TO_PROCESS[@]}"; do
    current=$((current + 1))

    # Rate limit protection - delay between states
    if [ $current -gt 1 ]; then
        log "Waiting ${DELAY_BETWEEN_STATES}s before next state..."
        sleep $DELAY_BETWEEN_STATES
    fi

    log ""
    log "=========================================="
    log "[$current/$total] Processing $state"
    log "=========================================="

    if process_state "$state"; then
        # Check if it was skipped (already complete)
        if [ "$FORCE_REPROCESS" = false ] && is_state_complete "$state"; then
            skipped=$((skipped + 1))
        else
            completed=$((completed + 1))
        fi
    else
        failed=$((failed + 1))
    fi
done

log ""
log "=========================================="
log "PROCESSING COMPLETE"
log "=========================================="
log "Total states: $total"
log "Newly completed: $completed"
log "Skipped (already done): $skipped"
log "Failed: $failed"
log ""

# Generate summary
log "Output summary:"
for state in "${STATES_TO_PROCESS[@]}"; do
    quads_dir="${OUTPUT_DIR}/${state}/maps/early_topo/quads"
    if [ -d "$quads_dir" ]; then
        count=$(find "$quads_dir" -name "*.mbtiles" 2>/dev/null | wc -l | tr -d ' ')
        size=$(du -sh "$quads_dir" 2>/dev/null | cut -f1)
        log "  $state: $count quads ($size)"
    else
        log "  $state: No output"
    fi
done
