#!/bin/bash
# Quadrangle-Level Historical Map Processing
# Converts individual GeoTIFFs to individual MBTiles files for granular downloads
#
# This script creates one MBTiles file per GeoTIFF, enabling:
# - Individual quadrangle downloads in the app
# - Proper bounds metadata for each quad
# - Named files that match USGS quad names
#
# Server expects files at:
#   /var/www/downloads/states/{STATE}/maps/{ERA}/quads/{quadId}.mbtiles
#
# Prerequisites:
#   - GDAL installed: brew install gdal (macOS) or apt install gdal-bin (Linux)
#
# Usage:
#   ./process-quadrangles.sh <state_code> <input_dir> <output_dir> <era_id> [num_cores]
#
# Example:
#   ./process-quadrangles.sh WY ./test_downloads/WY ./test_output early_topo 8

set -e

# ============================================
# Configuration
# ============================================

STATE_CODE="${1:-WY}"
INPUT_DIR="${2:-./test_downloads/WY}"
OUTPUT_DIR="${3:-./test_output}"
ERA_ID="${4:-early_topo}"  # survey, early_topo, midcentury
MAX_PARALLEL="${5:-4}"  # Number of parallel processes (default 4)

# MBTiles settings - optimized for historical maps
MIN_ZOOM=10
MAX_ZOOM=13
TILE_FORMAT="JPEG"
TILE_EXT="jpg"

# ============================================
# Functions
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_dependencies() {
    log "Checking dependencies..."

    local missing=0
    for cmd in gdalwarp gdal2tiles.py gdalinfo sqlite3; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "ERROR: $cmd not found"
            missing=1
        fi
    done

    if [ "$missing" -eq 1 ]; then
        echo ""
        echo "Install GDAL:"
        echo "  macOS: brew install gdal"
        echo "  Ubuntu: apt install gdal-bin python3-gdal"
        exit 1
    fi

    log "All dependencies found."
}

# Extract quad name from USGS filename
# Example: WY_Laramie_342388_1897_125000_geo.tif -> laramie_342388_1897
get_quad_id() {
    local filename="$1"
    local base=$(basename "$filename" .tif)
    base=$(basename "$base" .TIF)

    # Decode URL encoding (e.g., %20 -> space)
    base=$(echo "$base" | sed 's/%20/ /g' | sed 's/%27/'"'"'/g')

    # Extract state, name, usgs_id, year from USGS naming convention
    # Format: STATE_QuadName_ID_YEAR_SCALE_geo.tif
    local state=$(echo "$base" | cut -d'_' -f1)
    local name=$(echo "$base" | cut -d'_' -f2 | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    local usgs_id=$(echo "$base" | cut -d'_' -f3)
    local year=$(echo "$base" | cut -d'_' -f4)

    # Validate year is 4 digits
    if [[ ! "$year" =~ ^[0-9]{4}$ ]]; then
        # Try different position
        year=$(echo "$base" | grep -oE '[0-9]{4}' | head -1)
    fi

    # Return quad_id with USGS ID for uniqueness: name_id_year (e.g., laramie_342388_1897)
    echo "${name}_${usgs_id}_${year}"
}

# Get human-readable name from filename
get_display_name() {
    local filename="$1"
    local base=$(basename "$filename" .tif)
    base=$(basename "$base" .TIF)

    # Decode URL encoding
    base=$(echo "$base" | sed 's/%20/ /g' | sed 's/%27/'"'"'/g')

    # Extract name and title case it
    local name=$(echo "$base" | cut -d'_' -f2)
    echo "$name"
}

# Extract year from filename
get_year() {
    local filename="$1"
    local base=$(basename "$filename")

    # Look for 4-digit year in filename
    echo "$base" | grep -oE '[0-9]{4}' | head -1
}

# Process a single GeoTIFF to MBTiles
process_single_geotiff() {
    local input_file="$1"
    local output_dir="$2"
    local quad_id="$3"
    local display_name="$4"
    local year="$5"

    local output_mbtiles="${output_dir}/${quad_id}.mbtiles"
    local temp_dir="${output_dir}/.temp_${quad_id}"

    # Skip if output already exists AND is complete (has completion marker + tiles)
    if [ -f "$output_mbtiles" ]; then
        local is_complete=$(sqlite3 "$output_mbtiles" "SELECT value FROM metadata WHERE name='processing_complete';" 2>/dev/null || echo "")
        local existing_tiles=$(sqlite3 "$output_mbtiles" "SELECT COUNT(*) FROM tiles;" 2>/dev/null || echo "0")
        if [ "$is_complete" = "1" ] && [ "$existing_tiles" -gt 0 ]; then
            log "  Skipping (complete): $quad_id ($existing_tiles tiles)"
            return 0
        else
            log "  Removing incomplete file for reprocessing: $quad_id (complete=$is_complete, tiles=$existing_tiles)"
            rm -f "$output_mbtiles"
        fi
    fi

    log "  Processing: $quad_id ($display_name $year)"

    mkdir -p "$temp_dir"

    # Step 1: Get original bounds (in WGS84)
    local bounds_info=$(gdalinfo -json "$input_file" 2>/dev/null | grep -A 10 '"wgs84Extent"' | head -15)

    # Step 2: Reproject to Web Mercator (EPSG:3857) with automatic datum transformation
    # Historical USGS topos use NAD27-based American Polyconic projection (embedded in file).
    # GDAL auto-detects the source CRS and handles NAD27->WGS84 datum shift automatically.
    # Do NOT force -s_srs as it conflicts with the embedded projected CRS.
    local reprojected="${temp_dir}/reprojected.tif"
    gdalwarp -t_srs EPSG:3857 -r lanczos -co COMPRESS=LZW -overwrite \
        "$input_file" "$reprojected" 2>/dev/null

    # Step 3: Generate tiles (suppress verbose output for cleaner parallel logs)
    local tiles_dir="${temp_dir}/tiles"
    gdal2tiles.py \
        --zoom="${MIN_ZOOM}-${MAX_ZOOM}" \
        --processes=2 \
        --webviewer=none \
        --tiledriver=${TILE_FORMAT} \
        "$reprojected" \
        "$tiles_dir" > /dev/null 2>&1

    # Step 4: Get bounds from the reprojected file (convert back to WGS84)
    local bounds=$(gdalinfo "$input_file" -json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'wgs84Extent' in data:
    coords = data['wgs84Extent']['coordinates'][0]
    lons = [c[0] for c in coords]
    lats = [c[1] for c in coords]
    print(f'{min(lons)},{min(lats)},{max(lons)},{max(lats)}')
else:
    # Fallback to cornerCoordinates
    cc = data.get('cornerCoordinates', {})
    if cc:
        print(f\"{cc.get('lowerLeft', [0,0])[0]},{cc.get('lowerLeft', [0,0])[1]},{cc.get('upperRight', [0,0])[0]},{cc.get('upperRight', [0,0])[1]}\")
" 2>/dev/null || echo "-180,-90,180,90")

    # Step 5: Create MBTiles with metadata
    rm -f "$output_mbtiles"

    sqlite3 "$output_mbtiles" <<EOF
CREATE TABLE metadata (name TEXT, value TEXT);
CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);

INSERT INTO metadata VALUES ('name', '$display_name');
INSERT INTO metadata VALUES ('format', 'jpeg');
INSERT INTO metadata VALUES ('type', 'overlay');
INSERT INTO metadata VALUES ('scheme', 'tms');
INSERT INTO metadata VALUES ('minzoom', '$MIN_ZOOM');
INSERT INTO metadata VALUES ('maxzoom', '$MAX_ZOOM');
INSERT INTO metadata VALUES ('bounds', '$bounds');
INSERT INTO metadata VALUES ('description', '$display_name ($year) - USGS Historical Topographic Map');
EOF

    # Insert tiles
    find "$tiles_dir" -name "*.${TILE_EXT}" | while read tile_path; do
        local rel_path="${tile_path#$tiles_dir/}"
        local z=$(echo "$rel_path" | cut -d'/' -f1)
        local x=$(echo "$rel_path" | cut -d'/' -f2)
        local y=$(basename "$rel_path" ".${TILE_EXT}")

        if [[ "$z" =~ ^[0-9]+$ ]] && [[ "$x" =~ ^[0-9]+$ ]] && [[ "$y" =~ ^[0-9]+$ ]]; then
            sqlite3 "$output_mbtiles" "INSERT INTO tiles VALUES ($z, $x, $y, readfile('$tile_path'));" 2>/dev/null
        fi
    done

    # Optimize
    sqlite3 "$output_mbtiles" "VACUUM;"

    # Verify tiles were actually inserted before marking complete
    local tile_count=$(sqlite3 "$output_mbtiles" "SELECT COUNT(*) FROM tiles;")

    if [ "$tile_count" -eq 0 ]; then
        log "    FAILED: $quad_id (0 tiles inserted - deleting file)"
        rm -f "$output_mbtiles"
        rm -rf "$temp_dir"
        return 1
    fi

    # Mark as complete ONLY if tiles were successfully inserted
    sqlite3 "$output_mbtiles" "INSERT INTO metadata VALUES ('processing_complete', '1');"

    # Cleanup temp
    rm -rf "$temp_dir"

    # Report size
    local size=$(ls -lh "$output_mbtiles" | awk '{print $5}')
    log "    Created: $quad_id.mbtiles ($size, $tile_count tiles)"
}

# ============================================
# Main
# ============================================

main() {
    log "Quadrangle-Level Historical Map Processing"
    log "State: $STATE_CODE"
    log "Era: $ERA_ID"
    log "Input: $INPUT_DIR"
    log "Output: $OUTPUT_DIR"
    log "Parallel: $MAX_PARALLEL cores"
    echo ""

    check_dependencies

    # Create output directory structure
    local quads_dir="${OUTPUT_DIR}/${STATE_CODE}/maps/${ERA_ID}/quads"
    mkdir -p "$quads_dir"

    # Count input files
    local file_count=$(ls -1 "$INPUT_DIR"/*.tif "$INPUT_DIR"/*.TIF 2>/dev/null | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        log "ERROR: No GeoTIFF files found in $INPUT_DIR"
        exit 1
    fi
    log "Found $file_count GeoTIFF files to process with $MAX_PARALLEL parallel workers"
    echo ""

    # Export variables for parallel subprocesses
    export MIN_ZOOM MAX_ZOOM TILE_FORMAT TILE_EXT
    export QUADS_DIR="$quads_dir"
    export SCRIPT_PATH="$(realpath "$0")"

    # Create wrapper script for parallel processing
    # The wrapper sources the main script to get all functions
    local wrapper_script=$(mktemp)
    cat > "$wrapper_script" << 'WRAPPER_EOF'
#!/bin/bash
tif_file="$1"

# Source the main script to get all functions (but skip main execution)
SOURCING=1
source "$SCRIPT_PATH"

quad_id=$(get_quad_id "$tif_file")
display_name=$(get_display_name "$tif_file")
year=$(get_year "$tif_file")

if [ -z "$quad_id" ] || [ "$quad_id" = "_" ]; then
    log "  Skipping (invalid filename): $(basename "$tif_file")"
    exit 0
fi

if process_single_geotiff "$tif_file" "$QUADS_DIR" "$quad_id" "$display_name" "$year"; then
    :  # Success
else
    log "  FAILED: $quad_id"
fi
WRAPPER_EOF
    chmod +x "$wrapper_script"

    # Process GeoTIFFs in parallel using xargs with -n 1
    find "$INPUT_DIR" \( -name "*.tif" -o -name "*.TIF" \) -type f 2>/dev/null | \
    xargs -P "$MAX_PARALLEL" -n 1 bash "$wrapper_script"

    # Cleanup wrapper
    rm -f "$wrapper_script"

    echo ""
    log "Processing complete!"
    echo ""
    log "Output directory: $quads_dir"
    log "Files created:"
    ls -lh "$quads_dir"/*.mbtiles 2>/dev/null | head -20

    local total_count=$(ls -1 "$quads_dir"/*.mbtiles 2>/dev/null | wc -l | tr -d ' ')
    local total_size=$(du -sh "$quads_dir" 2>/dev/null | cut -f1)
    echo ""
    log "Total: $total_count quadrangles ($total_size)"
    echo ""
    log "Next step: Upload to server"
    log "  scp -r $quads_dir root@YOUR_SERVER_IP:/var/www/downloads/states/${STATE_CODE}/maps/${ERA_ID}/"

    # Cleanup
    rm -f "$stats_file"
}

# ============================================
# Help
# ============================================

# Skip execution when sourced
if [ -n "$SOURCING" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<EOF
Quadrangle-Level Historical Map Processing

Converts individual USGS GeoTIFFs to individual MBTiles files,
enabling granular downloads in the app.

USAGE:
    $0 <state_code> <input_dir> <output_dir> <era_id> [num_cores]

ARGUMENTS:
    state_code    Two-letter state code (e.g., WY, SD, CO)
    input_dir     Directory containing GeoTIFF files (.tif)
    output_dir    Output directory for MBTiles
    era_id        Era identifier: survey, early_topo, or midcentury
    num_cores     Number of parallel processes (default: 4)

EXAMPLES:
    $0 WY ./test_downloads/WY ./test_output early_topo 8
    $0 SD ./sd_maps ./output survey 4

OUTPUT STRUCTURE:
    <output_dir>/<state>/maps/<era>/quads/
        laramie_1897.mbtiles
        south_pass_1891.mbtiles
        ...

UPLOAD TO SERVER:
    scp -r <output_dir>/<state>/maps/<era>/quads \\
        root@YOUR_SERVER_IP:/var/www/downloads/states/<state>/maps/<era>/

VERIFY API:
    curl https://api.obsessiontracker.com/api/v1/downloads/states/WY/maps/manifest
EOF
    exit 0
fi

main
