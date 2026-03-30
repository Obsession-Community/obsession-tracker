#!/bin/bash
# Historical Map Batch Processing Pipeline
# Efficiently processes multiple GeoTIFFs to a single MBTiles file
#
# This script is optimized for processing many maps at once by:
# 1. Reprojecting all files to Web Mercator
# 2. Creating a virtual raster (VRT) that combines all maps
# 3. Generating tiles from the combined VRT
# 4. Packaging into a single MBTiles file
#
# Prerequisites:
#   - GDAL installed: brew install gdal (macOS) or apt install gdal-bin (Linux)
#
# Usage:
#   ./process-historical-maps-batch.sh <state_code> <input_dir> <output_dir> [layer_id]
#
# Example:
#   ./process-historical-maps-batch.sh WY ./usgs_downloads/WY ./output maps_early_topo

set -e

# ============================================
# Configuration
# ============================================

STATE_CODE="${1:-WY}"
INPUT_DIR="${2:-./source_maps}"
OUTPUT_DIR="${3:-./output}"
LAYER_ID="${4:-maps_early_topo}"

# MBTiles settings
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

    if ! command -v gdalwarp &> /dev/null; then
        echo "ERROR: gdalwarp not found. Install GDAL first."
        echo "  macOS: brew install gdal"
        echo "  Ubuntu: apt install gdal-bin"
        exit 1
    fi

    if ! command -v gdalbuildvrt &> /dev/null; then
        echo "ERROR: gdalbuildvrt not found. Install GDAL first."
        exit 1
    fi

    if ! command -v gdal2tiles.py &> /dev/null; then
        echo "ERROR: gdal2tiles.py not found. Install GDAL with Python bindings."
        exit 1
    fi

    log "All dependencies found."
}

# ============================================
# Main
# ============================================

main() {
    log "Historical Map Batch Processing Pipeline"
    log "State: $STATE_CODE"
    log "Input: $INPUT_DIR"
    log "Output: $OUTPUT_DIR"
    log "Layer ID: $LAYER_ID"
    echo ""

    check_dependencies

    # Count input files
    local file_count=$(ls -1 "$INPUT_DIR"/*.tif "$INPUT_DIR"/*.TIF 2>/dev/null | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        log "ERROR: No GeoTIFF files found in $INPUT_DIR"
        exit 1
    fi
    log "Found $file_count GeoTIFF files to process"

    # Create directories
    local temp_dir="${OUTPUT_DIR}/temp_${STATE_CODE}_${LAYER_ID}"
    local reprojected_dir="${temp_dir}/reprojected"
    local tiles_dir="${temp_dir}/tiles"
    local output_mbtiles="${OUTPUT_DIR}/${STATE_CODE}/${LAYER_ID}.mbtiles"

    mkdir -p "$reprojected_dir"
    mkdir -p "${OUTPUT_DIR}/${STATE_CODE}"

    # Step 1: Reproject all files to Web Mercator (EPSG:3857) with automatic datum transformation
    # Historical USGS topos use NAD27-based American Polyconic projection (embedded in file).
    # GDAL auto-detects the source CRS and handles NAD27->WGS84 datum shift automatically.
    log "Step 1: Reprojecting files to Web Mercator..."
    local processed=0
    for tif_file in "$INPUT_DIR"/*.tif "$INPUT_DIR"/*.TIF; do
        if [ -f "$tif_file" ]; then
            local base_name=$(basename "$tif_file")
            gdalwarp -t_srs EPSG:3857 -r lanczos -co COMPRESS=LZW -overwrite \
                "$tif_file" "${reprojected_dir}/${base_name}" 2>/dev/null
            processed=$((processed + 1))
            printf "\r  Processed: %d/%d files" "$processed" "$file_count"
        fi
    done
    echo ""
    log "  Reprojection complete: $processed files"

    # Step 2: Create VRT from all reprojected files
    log "Step 2: Creating virtual raster..."
    gdalbuildvrt "${temp_dir}/merged.vrt" "${reprojected_dir}"/*.tif

    # Step 3: Generate tiles
    log "Step 3: Generating tiles (zoom ${MIN_ZOOM}-${MAX_ZOOM})..."
    gdal2tiles.py \
        --zoom="${MIN_ZOOM}-${MAX_ZOOM}" \
        --processes=4 \
        --webviewer=none \
        --tiledriver=${TILE_FORMAT} \
        "${temp_dir}/merged.vrt" \
        "$tiles_dir" 2>&1 | grep -v "FutureWarning"

    # Count tiles
    local tile_count=$(find "$tiles_dir" -name "*.${TILE_EXT}" | wc -l | tr -d ' ')
    local tiles_size=$(du -sh "$tiles_dir" | cut -f1)
    log "  Generated $tile_count tiles ($tiles_size)"

    # Step 4: Create MBTiles
    log "Step 4: Creating MBTiles..."
    rm -f "$output_mbtiles"

    sqlite3 "$output_mbtiles" <<EOF
CREATE TABLE metadata (name TEXT, value TEXT);
CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);

INSERT INTO metadata VALUES ('name', '$LAYER_ID');
INSERT INTO metadata VALUES ('format', 'jpeg');
INSERT INTO metadata VALUES ('type', 'overlay');
INSERT INTO metadata VALUES ('scheme', 'tms');
INSERT INTO metadata VALUES ('minzoom', '$MIN_ZOOM');
INSERT INTO metadata VALUES ('maxzoom', '$MAX_ZOOM');
INSERT INTO metadata VALUES ('description', 'Historical topographic maps for $STATE_CODE');
EOF

    # Insert tiles
    local inserted=0
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

    # Get final stats
    local final_tiles=$(sqlite3 "$output_mbtiles" "SELECT COUNT(*) FROM tiles;")
    local final_size=$(ls -lh "$output_mbtiles" | awk '{print $5}')

    log "  Created: $output_mbtiles ($final_size, $final_tiles tiles)"

    # Step 5: Cleanup
    log "Step 5: Cleaning up temporary files..."
    rm -rf "$temp_dir"

    log ""
    log "Processing complete!"
    log "Output: $output_mbtiles"
}

# ============================================
# Help
# ============================================

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<EOF
Historical Map Batch Processing Pipeline

Efficiently processes multiple GeoTIFFs to a single MBTiles file.
Optimized for large numbers of files (10x faster than individual processing).

USAGE:
    $0 <state_code> <input_dir> <output_dir> [layer_id]

ARGUMENTS:
    state_code    Two-letter state code (e.g., WY, SD, CO)
    input_dir     Directory containing GeoTIFF files (.tif)
    output_dir    Output directory for MBTiles
    layer_id      Layer identifier (default: maps_early_topo)

EXAMPLES:
    $0 WY ./usgs_downloads/WY ./output maps_early_topo
    $0 SD ./sd_maps ./output maps_survey

LAYER IDS:
    maps_survey     - GLO survey plats (1850s-1880s)
    maps_early_topo - Early USGS topographic maps (1890s-1920s)
    maps_midcentury - Mid-century USGS maps (1940s-1960s)

OUTPUT:
    Creates a single MBTiles file at:
    <output_dir>/<state_code>/<layer_id>.mbtiles
EOF
    exit 0
fi

main
