#!/bin/bash
# Historical Map Processing Pipeline
# Converts GeoTIFFs to MBTiles for the Obsession Tracker app
#
# Prerequisites:
#   - GDAL installed: brew install gdal (macOS) or apt install gdal-bin (Linux)
#   - mb-util installed: pip install mbutil (optional, for inspection)
#
# Usage:
#   ./process-historical-maps.sh <state_code> <input_dir> <output_dir>
#
# Example:
#   ./process-historical-maps.sh WY ./source_maps ./output
#
# Notes:
#   - Uses JPEG format for smaller file sizes (~10x smaller than PNG)
#   - Zoom levels 10-13 are optimal for historical maps
#   - For better results with many files, use process-historical-maps-batch.sh

set -e

# ============================================
# Configuration
# ============================================

STATE_CODE="${1:-WY}"
INPUT_DIR="${2:-./source_maps}"
OUTPUT_DIR="${3:-./output}"

# MBTiles settings
TILE_SIZE=256
MIN_ZOOM=10
MAX_ZOOM=13
TILE_FORMAT="JPEG"  # Use JPEG for historical maps (smaller file size, good for scanned documents)
TILE_EXT="jpg"      # File extension for tiles

# ============================================
# Functions
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_dependencies() {
    log "Checking dependencies..."

    if ! command -v gdal_translate &> /dev/null; then
        echo "ERROR: gdal_translate not found. Install GDAL first."
        echo "  macOS: brew install gdal"
        echo "  Ubuntu: apt install gdal-bin"
        exit 1
    fi

    if ! command -v gdalwarp &> /dev/null; then
        echo "ERROR: gdalwarp not found. Install GDAL first."
        exit 1
    fi

    if ! command -v gdal2tiles.py &> /dev/null; then
        echo "ERROR: gdal2tiles.py not found. Install GDAL with Python bindings."
        exit 1
    fi

    log "All dependencies found."
}

process_geotiff_to_mbtiles() {
    local input_file="$1"
    local output_name="$2"
    local layer_id="$3"

    local base_name=$(basename "$input_file" .tif)
    local temp_dir="${OUTPUT_DIR}/temp_${base_name}"
    local tiles_dir="${temp_dir}/tiles"
    local output_mbtiles="${OUTPUT_DIR}/${STATE_CODE}/${output_name}.mbtiles"

    log "Processing: $input_file -> $output_mbtiles"

    # Create output directories
    mkdir -p "${OUTPUT_DIR}/${STATE_CODE}"
    mkdir -p "$temp_dir"

    # Step 1: Reproject to Web Mercator (EPSG:3857) with automatic datum transformation
    # Historical USGS topos use NAD27-based American Polyconic projection (embedded in file).
    # GDAL auto-detects the source CRS and handles NAD27->WGS84 datum shift automatically.
    log "  Step 1: Reprojecting to Web Mercator..."
    local reprojected="${temp_dir}/reprojected.tif"
    gdalwarp -t_srs EPSG:3857 -r lanczos -co COMPRESS=LZW "$input_file" "$reprojected"

    # Step 2: Generate tiles using gdal2tiles.py
    log "  Step 2: Generating tiles (zoom ${MIN_ZOOM}-${MAX_ZOOM})..."
    gdal2tiles.py \
        --zoom="${MIN_ZOOM}-${MAX_ZOOM}" \
        --processes=4 \
        --tilesize=${TILE_SIZE} \
        --resampling=lanczos \
        --webviewer=none \
        --tiledriver=${TILE_FORMAT} \
        "$reprojected" \
        "$tiles_dir"

    # Step 3: Convert tiles to MBTiles using mb-util (if available) or manual SQLite
    log "  Step 3: Creating MBTiles..."
    create_mbtiles_from_tiles "$tiles_dir" "$output_mbtiles" "$layer_id"

    # Cleanup
    log "  Cleaning up temporary files..."
    rm -rf "$temp_dir"

    # Get file size
    local size_bytes=$(stat -f%z "$output_mbtiles" 2>/dev/null || stat -c%s "$output_mbtiles" 2>/dev/null)
    log "  Created: $output_mbtiles ($(numfmt --to=iec-i --suffix=B $size_bytes 2>/dev/null || echo "$size_bytes bytes"))"
}

create_mbtiles_from_tiles() {
    local tiles_dir="$1"
    local output_mbtiles="$2"
    local layer_id="$3"

    # Check if mb-util is available
    if command -v mb-util &> /dev/null; then
        mb-util "$tiles_dir" "$output_mbtiles" --image_format=jpeg --scheme=tms
    else
        # Manual SQLite approach
        create_mbtiles_manual "$tiles_dir" "$output_mbtiles" "$layer_id"
    fi
}

create_mbtiles_manual() {
    local tiles_dir="$1"
    local output_mbtiles="$2"
    local layer_id="$3"

    # Remove existing file
    rm -f "$output_mbtiles"

    # Create MBTiles database
    sqlite3 "$output_mbtiles" <<EOF
CREATE TABLE metadata (name TEXT, value TEXT);
CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);

INSERT INTO metadata VALUES ('name', '$layer_id');
INSERT INTO metadata VALUES ('format', 'jpeg');
INSERT INTO metadata VALUES ('type', 'overlay');
INSERT INTO metadata VALUES ('scheme', 'tms');
INSERT INTO metadata VALUES ('minzoom', '$MIN_ZOOM');
INSERT INTO metadata VALUES ('maxzoom', '$MAX_ZOOM');
EOF

    # Insert tiles
    find "$tiles_dir" -name "*.${TILE_EXT}" | while read tile_path; do
        # Extract z/x/y from path like tiles/12/1234/5678.jpg
        local rel_path="${tile_path#$tiles_dir/}"
        local z=$(echo "$rel_path" | cut -d'/' -f1)
        local x=$(echo "$rel_path" | cut -d'/' -f2)
        local y=$(basename "$rel_path" ".${TILE_EXT}")

        # Skip non-numeric directories
        if [[ ! "$z" =~ ^[0-9]+$ ]] || [[ ! "$x" =~ ^[0-9]+$ ]] || [[ ! "$y" =~ ^[0-9]+$ ]]; then
            continue
        fi

        # Insert tile (using hex encoding for binary data)
        sqlite3 "$output_mbtiles" "INSERT INTO tiles VALUES ($z, $x, $y, readfile('$tile_path'));" 2>/dev/null || true
    done

    # Optimize
    sqlite3 "$output_mbtiles" "VACUUM;"
}

generate_manifest() {
    local state_code="$1"
    local manifest_file="${OUTPUT_DIR}/${state_code}/manifest.json"

    log "Generating manifest for $state_code..."

    # Get list of mbtiles files and their sizes
    local layers_json="["
    local first=true

    for mbtiles_file in "${OUTPUT_DIR}/${state_code}"/*.mbtiles; do
        if [ -f "$mbtiles_file" ]; then
            local filename=$(basename "$mbtiles_file")
            local layer_id="${filename%.mbtiles}"
            local size_bytes=$(stat -f%z "$mbtiles_file" 2>/dev/null || stat -c%s "$mbtiles_file" 2>/dev/null)
            local updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

            # Determine layer name and era based on ID
            local name=""
            local era=""
            case "$layer_id" in
                maps_survey)
                    name="Survey Era Maps"
                    era="1850-1890"
                    ;;
                maps_early_topo)
                    name="Early USGS Topos"
                    era="1890-1920"
                    ;;
                maps_midcentury)
                    name="Mid-Century Maps"
                    era="1940-1960"
                    ;;
                *)
                    name="Historical Map"
                    era=""
                    ;;
            esac

            if [ "$first" = true ]; then
                first=false
            else
                layers_json+=","
            fi

            layers_json+=$(cat <<EOF

    {
      "id": "$layer_id",
      "name": "$name",
      "description": "Historical topographic maps from the $era era",
      "file": "$filename",
      "size": $size_bytes,
      "type": "raster",
      "format": "mbtiles",
      "era": "$era",
      "updatedAt": "$updated_at"
    }
EOF
)
        fi
    done

    layers_json+="
  ]"

    # Write manifest
    cat > "$manifest_file" <<EOF
{
  "state": "$state_code",
  "version": "$(date +%Y.%m.%d)",
  "generatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "layers": $layers_json
}
EOF

    log "Manifest written to: $manifest_file"
}

# ============================================
# Main
# ============================================

main() {
    log "Historical Map Processing Pipeline"
    log "State: $STATE_CODE"
    log "Input: $INPUT_DIR"
    log "Output: $OUTPUT_DIR"
    echo ""

    check_dependencies

    # Create output directory
    mkdir -p "${OUTPUT_DIR}/${STATE_CODE}"

    # Process each GeoTIFF in the input directory
    if [ -d "$INPUT_DIR" ]; then
        for tif_file in "$INPUT_DIR"/*.tif "$INPUT_DIR"/*.TIF; do
            if [ -f "$tif_file" ]; then
                local base_name=$(basename "$tif_file" .tif)
                base_name=$(basename "$base_name" .TIF)

                # Determine layer ID from filename or subdirectory
                local layer_id="maps_${base_name}"

                process_geotiff_to_mbtiles "$tif_file" "$layer_id" "$layer_id"
            fi
        done
    else
        log "ERROR: Input directory not found: $INPUT_DIR"
        exit 1
    fi

    # Generate manifest
    generate_manifest "$STATE_CODE"

    log ""
    log "Processing complete!"
    log "Output files:"
    ls -la "${OUTPUT_DIR}/${STATE_CODE}/"
}

# ============================================
# Help
# ============================================

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<EOF
Historical Map Processing Pipeline

Converts GeoTIFF historical maps to MBTiles format for mobile offline use.

USAGE:
    $0 <state_code> <input_dir> <output_dir>

ARGUMENTS:
    state_code    Two-letter state code (e.g., WY, SD, CO)
    input_dir     Directory containing GeoTIFF files (.tif)
    output_dir    Output directory for MBTiles and manifest

EXAMPLE:
    $0 WY ./wyoming_maps ./output

SOURCE DATA:
    USGS Historical Topos: https://ngmdb.usgs.gov/topoview/
    GLO Survey Plats: https://glorecords.blm.gov/

PREREQUISITES:
    - GDAL (gdal_translate, gdalwarp, gdal2tiles.py)
    - SQLite3
    - Optional: mb-util (pip install mbutil)

OUTPUT:
    Creates MBTiles files and manifest.json in:
    <output_dir>/<state_code>/
        ├── manifest.json
        ├── maps_survey.mbtiles
        └── maps_early_topo.mbtiles
EOF
    exit 0
fi

main
