#!/bin/bash
# Bulk Historical Maps Processor
# Downloads and processes USGS historical topographic maps for multiple states
#
# This script orchestrates the full pipeline:
#   1. Download GeoTIFFs from USGS TNM API
#   2. Process each GeoTIFF to individual MBTiles (quadrangle-level)
#   3. Upload to production server
#
# Usage:
#   ./process-all-states.sh [region]
#
# Regions:
#   west     - All Western states (default)
#   east     - All Eastern states
#   all      - All 48 continental states
#   single   - Process a single state (prompts for state code)
#
# Prerequisites:
#   - GDAL installed (gdal2tiles.py, gdalwarp)
#   - jq installed (for API parsing)
#   - SQLite3 installed
#   - ~10GB free disk space per state (temporary)

set -e

# ============================================
# Configuration
# ============================================

REGION="${1:-west}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPTS_DIR}/historical_maps_workspace"
DOWNLOADS_DIR="${BASE_DIR}/downloads"
OUTPUT_DIR="${BASE_DIR}/output"
SERVER_HOST="root@YOUR_SERVER_IP"
SERVER_PATH="/var/www/downloads/states"

# Date ranges for different eras
EARLY_TOPO_START="1880-01-01"
EARLY_TOPO_END="1925-01-01"
MIDCENTURY_START="1940-01-01"
MIDCENTURY_END="1965-01-01"

# Western states (treasure hunting focus)
WEST_STATES=(
    WY MT CO SD ID    # Core Rocky Mountain
    NM AZ NV UT       # Southwest
    OR WA CA          # Pacific
    TX OK KS NE ND    # Plains
)

# Eastern states
EAST_STATES=(
    MN IA MO AR LA    # Mississippi border
    WI IL IN OH MI    # Great Lakes
    KY TN MS AL       # South Central
    GA FL SC NC VA    # Southeast
    WV PA NY VT NH    # Northeast
    ME MA RI CT NJ DE MD DC
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

check_dependencies() {
    log "Checking dependencies..."
    local missing=0

    for cmd in curl jq sqlite3 gdalwarp gdal2tiles.py; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "ERROR: $cmd not found"
            missing=1
        fi
    done

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo "Install missing dependencies:"
        echo "  macOS: brew install gdal jq"
        echo "  Ubuntu: apt install gdal-bin python3-gdal jq"
        exit 1
    fi

    log "All dependencies found."
}

# Get states based on region
get_states() {
    local region="$1"
    case "$region" in
        west)
            echo "${WEST_STATES[@]}"
            ;;
        east)
            echo "${EAST_STATES[@]}"
            ;;
        all)
            echo "${WEST_STATES[@]} ${EAST_STATES[@]}"
            ;;
        single)
            read -p "Enter state code (e.g., WY): " state_code
            echo "${state_code^^}"  # Uppercase
            ;;
        *)
            echo "$region"  # Assume it's a state code
            ;;
    esac
}

# Download maps for a single state
download_state() {
    local state="$1"
    local era="${2:-early_topo}"
    local start_date="$EARLY_TOPO_START"
    local end_date="$EARLY_TOPO_END"

    if [ "$era" == "midcentury" ]; then
        start_date="$MIDCENTURY_START"
        end_date="$MIDCENTURY_END"
    fi

    local output_dir="${DOWNLOADS_DIR}/${state}/${era}"
    mkdir -p "$output_dir"

    log "Downloading $state ($era: $start_date to $end_date)..."

    # Call the download script
    "${SCRIPTS_DIR}/download-usgs-maps.sh" \
        "$state" \
        "$output_dir" \
        "GeoTIFF" \
        "$start_date" \
        "$end_date" || {
        log "WARNING: Download failed for $state $era, continuing..."
        return 1
    }

    # Count downloaded files
    local count=$(find "$output_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | wc -l | tr -d ' ')
    log "Downloaded $count GeoTIFFs for $state $era"
}

# Process downloaded maps to MBTiles
process_state() {
    local state="$1"
    local era="${2:-early_topo}"
    local input_dir="${DOWNLOADS_DIR}/${state}/${era}"
    local output_dir="${OUTPUT_DIR}"

    # Check if there are files to process
    local file_count=$(find "$input_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        log "No GeoTIFFs found for $state $era, skipping..."
        return 0
    fi

    log "Processing $file_count GeoTIFFs for $state $era..."

    # Call the quadrangle processing script
    "${SCRIPTS_DIR}/process-quadrangles.sh" \
        "$state" \
        "$input_dir" \
        "$output_dir" \
        "$era" || {
        log "WARNING: Processing failed for $state $era, continuing..."
        return 1
    }

    # Report output
    local quads_dir="${output_dir}/${state}/maps/${era}/quads"
    if [ -d "$quads_dir" ]; then
        local mbtiles_count=$(ls -1 "$quads_dir"/*.mbtiles 2>/dev/null | wc -l | tr -d ' ')
        local total_size=$(du -sh "$quads_dir" 2>/dev/null | cut -f1)
        log "Created $mbtiles_count quadrangle MBTiles ($total_size) for $state $era"
    fi
}

# Upload to server
upload_state() {
    local state="$1"
    local local_dir="${OUTPUT_DIR}/${state}/maps"

    if [ ! -d "$local_dir" ]; then
        log "No processed maps for $state, skipping upload..."
        return 0
    fi

    log "Uploading $state maps to server..."

    # Create remote directory
    ssh "$SERVER_HOST" "mkdir -p ${SERVER_PATH}/${state}/maps" || {
        log "ERROR: Failed to create remote directory for $state"
        return 1
    }

    # Upload using rsync for efficiency
    rsync -avz --progress \
        "$local_dir/" \
        "${SERVER_HOST}:${SERVER_PATH}/${state}/maps/" || {
        log "WARNING: Upload failed for $state"
        return 1
    }

    log "Upload complete for $state"

    # Generate static manifest.json for instant API responses
    log "Generating manifest.json for $state..."
    ssh "$SERVER_HOST" "cd /var/www/obsession/obsession-tracker/server/scripts && ./generate-manifest.sh $state" || {
        log "WARNING: Manifest generation failed for $state (API will use dynamic generation)"
    }
}

# Generate state summary
generate_summary() {
    log_section "Processing Summary"

    echo ""
    printf "%-6s %-12s %-12s %-10s\n" "State" "Early Topo" "Midcentury" "Total Size"
    printf "%-6s %-12s %-12s %-10s\n" "-----" "----------" "----------" "----------"

    for state in $(get_states "$REGION"); do
        local early_count=0
        local mid_count=0
        local total_size="0"

        local early_dir="${OUTPUT_DIR}/${state}/maps/early_topo/quads"
        local mid_dir="${OUTPUT_DIR}/${state}/maps/midcentury/quads"

        if [ -d "$early_dir" ]; then
            early_count=$(ls -1 "$early_dir"/*.mbtiles 2>/dev/null | wc -l | tr -d ' ')
        fi
        if [ -d "$mid_dir" ]; then
            mid_count=$(ls -1 "$mid_dir"/*.mbtiles 2>/dev/null | wc -l | tr -d ' ')
        fi

        if [ -d "${OUTPUT_DIR}/${state}" ]; then
            total_size=$(du -sh "${OUTPUT_DIR}/${state}" 2>/dev/null | cut -f1)
        fi

        printf "%-6s %-12s %-12s %-10s\n" "$state" "$early_count quads" "$mid_count quads" "$total_size"
    done

    echo ""
    local grand_total=$(du -sh "${OUTPUT_DIR}" 2>/dev/null | cut -f1)
    log "Total output size: $grand_total"
}

# Cleanup temporary files
cleanup() {
    log "Cleaning up temporary files..."
    # Keep downloads for now in case we need to reprocess
    # rm -rf "${DOWNLOADS_DIR}"
    log "Cleanup complete (downloads preserved for reprocessing)"
}

# ============================================
# Main
# ============================================

main() {
    log_section "Bulk Historical Maps Processor"
    log "Region: $REGION"
    log "Working directory: $BASE_DIR"
    echo ""

    check_dependencies

    # Create working directories
    mkdir -p "$DOWNLOADS_DIR" "$OUTPUT_DIR"

    # Get list of states
    local states=($(get_states "$REGION"))
    local total_states=${#states[@]}

    log "Processing $total_states states: ${states[*]}"
    echo ""

    # Process each state
    local current=0
    for state in "${states[@]}"; do
        current=$((current + 1))
        log_section "State $current/$total_states: $state"

        # Download and process early_topo era
        log "--- Early Topo Era (1880-1925) ---"
        if download_state "$state" "early_topo"; then
            process_state "$state" "early_topo"
        fi

        # Optionally download and process midcentury era
        # Uncomment if you want both eras:
        # log "--- Midcentury Era (1940-1965) ---"
        # if download_state "$state" "midcentury"; then
        #     process_state "$state" "midcentury"
        # fi

        # Upload to server
        upload_state "$state"

        # Keep GeoTIFFs for verification (don't delete until confirmed working)
        # rm -rf "${DOWNLOADS_DIR}/${state}"
        log "Source files preserved at: ${DOWNLOADS_DIR}/${state}"

        log "Completed: $state ($current/$total_states)"
    done

    # Generate summary
    generate_summary

    log_section "All Processing Complete!"
    log "Output directory: $OUTPUT_DIR"
    log ""
    log "Server locations:"
    log "  ${SERVER_HOST}:${SERVER_PATH}/{STATE}/maps/{ERA}/quads/"
    log ""
    log "API verification:"
    log "  curl https://api.obsessiontracker.com/api/v1/downloads/states/WY/maps/manifest"
}

# ============================================
# Help
# ============================================

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    cat <<EOF
Bulk Historical Maps Processor

Downloads USGS historical topographic maps and converts them to
quadrangle-level MBTiles for the Obsession Tracker app.

USAGE:
    $0 [region|state_code]

REGIONS:
    west      - Western states: WY MT CO SD ID NM AZ NV UT OR WA CA TX OK KS NE ND
    east      - Eastern states: All states east of the Mississippi
    all       - All 48 continental states
    single    - Interactive: prompts for a single state code

SINGLE STATE:
    $0 WY     - Process only Wyoming
    $0 CO     - Process only Colorado

EXAMPLES:
    $0 west              # Process all Western states
    $0 WY                # Process only Wyoming
    $0 all               # Process all 48 states (takes many hours)

OUTPUT STRUCTURE:
    historical_maps_workspace/
    ├── downloads/        # Temporary GeoTIFFs (cleaned after upload)
    └── output/
        └── WY/
            └── maps/
                └── early_topo/
                    └── quads/
                        ├── laramie_1897.mbtiles
                        └── cheyenne_1905.mbtiles

DISK SPACE:
    - ~10GB temporary space per state during processing
    - ~500MB-2GB final MBTiles per state
    - Full west region: ~15-30GB total

ESTIMATED TIME:
    - Single state: 30-60 minutes
    - All western states: 6-12 hours
    - All 48 states: 12-24 hours

SERVER UPLOAD:
    Files are automatically uploaded to:
    $SERVER_HOST:$SERVER_PATH/{STATE}/maps/{ERA}/quads/
EOF
    exit 0
fi

main
