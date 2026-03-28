#!/bin/bash
# Parallel Historical Maps Reprocessor
# Re-downloads and reprocesses states with the NAD27->WGS84 datum fix
# Uses multiple cores for faster processing
#
# Usage:
#   ./reprocess-states-parallel.sh [region] [num_cores]
#
# Examples:
#   ./reprocess-states-parallel.sh west 8     # Reprocess western states with 8 cores
#   ./reprocess-states-parallel.sh all 4      # All states with 4 cores
#   ./reprocess-states-parallel.sh WY 8       # Single state

set -e

# ============================================
# Configuration
# ============================================

REGION="${1:-all}"
NUM_CORES="${2:-8}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPTS_DIR}/historical_maps_workspace"
DOWNLOADS_DIR="${BASE_DIR}/downloads"
OUTPUT_DIR="${BASE_DIR}/output"
SERVER_HOST="root@YOUR_SERVER_IP"
SERVER_PATH="/var/www/downloads/states"

# Date ranges
EARLY_TOPO_START="1880-01-01"
EARLY_TOPO_END="1925-01-01"

# States - these already have MBTiles that need datum fix
COMPLETED_STATES=(
    WY MT CO SD ID NM AZ NV UT OR WA CA TX OK KS NE ND  # West
    MN IA MO AR LA WI IL IN OH MI KY TN MS AL GA FL SC NC VA WV PA  # East completed
)

# States still in progress (NY and remaining)
REMAINING_STATES=(
    NY NJ CT RI MA VT NH ME MD DE DC
)

# ============================================
# Functions
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_section() {
    echo ""
    echo "============================================"
    echo "  $1"
    echo "============================================"
}

# Parallel gdalwarp with datum fix
parallel_reproject() {
    local input_dir="$1"
    local output_dir="$2"
    local num_cores="$3"

    mkdir -p "$output_dir"

    # Use xargs for parallel processing with proper NAD27 datum transformation
    find "$input_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | \
    xargs -P "$num_cores" -I {} bash -c '
        input_file="{}"
        base_name=$(basename "$input_file")
        output_file="'"$output_dir"'/${base_name}"

        # Skip if already processed
        if [ -f "$output_file" ]; then
            echo "  Skip (exists): $base_name"
            exit 0
        fi

        # Reproject to Web Mercator - GDAL auto-detects source CRS and handles datum shift
        gdalwarp -t_srs EPSG:3857 -r lanczos -co COMPRESS=LZW -overwrite \
            "$input_file" "$output_file" 2>/dev/null && \
        echo "  Done: $base_name" || echo "  FAIL: $base_name"
    '
}

# Download state maps (uses existing script)
download_state() {
    local state="$1"
    local output_dir="${DOWNLOADS_DIR}/${state}/early_topo"

    mkdir -p "$output_dir"

    log "Downloading $state..."

    "${SCRIPTS_DIR}/download-usgs-maps.sh" \
        "$state" \
        "$output_dir" \
        "GeoTIFF" \
        "$EARLY_TOPO_START" \
        "$EARLY_TOPO_END" 2>&1 | grep -E "Downloading:|Found|ERROR" || true
}

# Process state with parallel reprojection
process_state_parallel() {
    local state="$1"
    local num_cores="$2"
    local input_dir="${DOWNLOADS_DIR}/${state}/early_topo"
    local output_quads_dir="${OUTPUT_DIR}/${state}/maps/early_topo/quads"

    # Count input files
    local file_count=$(find "$input_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        log "No GeoTIFFs for $state, skipping..."
        return 0
    fi

    # DELETE old output files to force reprocessing with datum fix
    if [ -d "$output_quads_dir" ]; then
        log "Deleting old MBTiles for $state (to apply datum fix)..."
        rm -rf "$output_quads_dir"
    fi

    log "Processing $file_count GeoTIFFs for $state with $num_cores cores..."

    # Use the fixed process-quadrangles.sh which now has the datum fix
    "${SCRIPTS_DIR}/process-quadrangles.sh" \
        "$state" \
        "$input_dir" \
        "$OUTPUT_DIR" \
        "early_topo" \
        "$num_cores" || {
        log "WARNING: Processing failed for $state"
        return 1
    }
}

# Upload to server
upload_state() {
    local state="$1"
    local local_dir="${OUTPUT_DIR}/${state}/maps"

    if [ ! -d "$local_dir" ]; then
        log "No maps for $state, skipping upload..."
        return 0
    fi

    log "Uploading $state to server..."

    # Create remote directory and upload
    ssh "$SERVER_HOST" "mkdir -p ${SERVER_PATH}/${state}/maps" && \
    rsync -avz --progress \
        "$local_dir/" \
        "${SERVER_HOST}:${SERVER_PATH}/${state}/maps/" && \
    log "Upload complete for $state" || {
        log "Upload failed for $state"
        return 1
    }

    # Generate manifest
    ssh "$SERVER_HOST" "cd /var/www/obsession/obsession-tracker/server/scripts && ./generate-manifest.sh $state" 2>/dev/null || true
}

# Process a single state completely
process_single_state() {
    local state="$1"
    local num_cores="$2"

    log_section "Processing $state with $num_cores cores"

    # 1. Download
    download_state "$state"

    # 2. Process with parallelization
    process_state_parallel "$state" "$num_cores"

    # 3. Upload
    upload_state "$state"

    # 4. Keep downloads for verification (don't delete until confirmed working)
    # rm -rf "${DOWNLOADS_DIR}/${state}"
    log "Source files preserved at: ${DOWNLOADS_DIR}/${state}"

    log "Completed: $state"
}

# Get states to process
get_states() {
    local region="$1"
    case "$region" in
        completed)
            echo "${COMPLETED_STATES[@]}"
            ;;
        remaining)
            echo "${REMAINING_STATES[@]}"
            ;;
        all)
            echo "${COMPLETED_STATES[@]} ${REMAINING_STATES[@]}"
            ;;
        *)
            echo "$region"  # Assume single state code
            ;;
    esac
}

# ============================================
# Main
# ============================================

main() {
    log_section "Parallel Historical Maps Reprocessor"
    log "Region: $REGION"
    log "Cores: $NUM_CORES"
    log "Working directory: $BASE_DIR"
    echo ""

    # Check dependencies
    for cmd in curl jq sqlite3 gdalwarp gdal2tiles.py; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "ERROR: $cmd not found"
            exit 1
        fi
    done

    # Create directories
    mkdir -p "$DOWNLOADS_DIR" "$OUTPUT_DIR"

    # Get states
    local states=($(get_states "$REGION"))
    local total=${#states[@]}

    log "Processing $total states: ${states[*]}"
    echo ""

    # Process each state
    local current=0
    for state in "${states[@]}"; do
        current=$((current + 1))
        log "[$current/$total] $state"
        process_single_state "$state" "$NUM_CORES"
    done

    log_section "Reprocessing Complete!"
    log "All $total states processed with NAD27->WGS84 datum fix"
}

# Help
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    cat <<EOF
Parallel Historical Maps Reprocessor

Re-downloads and reprocesses states with the NAD27->WGS84 datum fix.
Uses multiple cores for faster processing.

USAGE:
    $0 [region|state] [num_cores]

REGIONS:
    completed   - States already processed (need datum fix)
    remaining   - States not yet processed
    all         - All states
    WY/CO/etc   - Single state code

EXAMPLES:
    $0 completed 8   # Reprocess all completed states with 8 cores
    $0 WY 8          # Reprocess just Wyoming
    $0 all 4         # All states with 4 cores

COMPLETED STATES (need datum fix):
    ${COMPLETED_STATES[*]}

REMAINING STATES:
    ${REMAINING_STATES[*]}
EOF
    exit 0
fi

main
