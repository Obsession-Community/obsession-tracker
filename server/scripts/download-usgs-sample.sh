#!/bin/bash
# Download Sample USGS Historical Topo for Testing
#
# Downloads a properly georeferenced historical topo map from USGS TopoView
# for testing the MBTiles generation pipeline.
#
# The USGS provides georeferenced GeoTIFFs through their National Map API.
#
# Usage:
#   ./download-usgs-sample.sh [output_dir]

set -e

OUTPUT_DIR="${1:-./usgs_downloads}"
mkdir -p "$OUTPUT_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ============================================
# USGS TopoView API
# ============================================
#
# TopoView provides historical USGS topographic maps as GeoTIFFs.
# API endpoint: https://tnmaccess.nationalmap.gov/api/v1/products
#
# Parameters:
#   - datasets: Historical Topographic Maps
#   - bbox: bounding box (minX,minY,maxX,maxY in WGS84)
#   - prodFormats: GeoTIFF
#   - max: number of results

# Lander, Wyoming area (good for testing - has historical maps from 1900s)
# Approximate bounds: -108.9 to -108.5 longitude, 42.7 to 43.0 latitude
BBOX="-109.0,42.5,-108.0,43.5"
STATE="WY"

log "Searching for historical topos in Wyoming (Lander area)..."
log "Bounding box: $BBOX"

# Query the USGS API for historical topos
SEARCH_URL="https://tnmaccess.nationalmap.gov/api/v1/products?datasets=Historical%20Topographic%20Maps&bbox=${BBOX}&prodFormats=GeoTIFF&max=5"

log "Querying: $SEARCH_URL"

# Get the search results
RESULTS=$(curl -s "$SEARCH_URL")

# Parse and show available maps
log ""
log "Available historical maps:"
echo "$RESULTS" | python3 -c "
import json
import sys

try:
    data = json.load(sys.stdin)
    items = data.get('items', [])

    if not items:
        print('  No maps found in this area')
        sys.exit(0)

    for i, item in enumerate(items[:5]):
        title = item.get('title', 'Unknown')
        date = item.get('publicationDate', 'Unknown')
        scale = item.get('mapScale', 'Unknown')
        url = item.get('downloadURL', '')
        size = item.get('sizeInBytes', 0)
        size_mb = size / (1024 * 1024) if size else 0

        print(f'  {i+1}. {title}')
        print(f'     Date: {date}, Scale: 1:{scale}')
        print(f'     Size: {size_mb:.1f} MB')
        print(f'     URL: {url[:80]}...' if len(url) > 80 else f'     URL: {url}')
        print()

        # Save first URL for download
        if i == 0:
            with open('/tmp/usgs_download_url.txt', 'w') as f:
                f.write(url)
            with open('/tmp/usgs_download_name.txt', 'w') as f:
                f.write(title.replace(' ', '_').replace(',', ''))
except Exception as e:
    print(f'Error parsing results: {e}')
    sys.exit(1)
"

# Check if we found any maps
if [ ! -f /tmp/usgs_download_url.txt ]; then
    log "No maps found. Try adjusting the bounding box."
    exit 1
fi

DOWNLOAD_URL=$(cat /tmp/usgs_download_url.txt)
MAP_NAME=$(cat /tmp/usgs_download_name.txt)

if [ -z "$DOWNLOAD_URL" ]; then
    log "No download URL found"
    exit 1
fi

log ""
log "Downloading first map: $MAP_NAME"
log "URL: $DOWNLOAD_URL"

# Download the GeoTIFF
OUTPUT_FILE="${OUTPUT_DIR}/${MAP_NAME}.tif"
curl -L -o "$OUTPUT_FILE" "$DOWNLOAD_URL"

# Verify it's a valid GeoTIFF
if command -v gdalinfo &> /dev/null; then
    log ""
    log "Verifying GeoTIFF..."
    gdalinfo "$OUTPUT_FILE" | head -20

    log ""
    log "Coordinate system:"
    gdalinfo "$OUTPUT_FILE" | grep -A5 "Coordinate System"
else
    log "gdalinfo not available - install GDAL to verify the file"
fi

# Get file size
SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
log ""
log "Downloaded: $OUTPUT_FILE ($SIZE)"
log ""
log "Next steps:"
log "  1. Run: ./process-historical-maps.sh WY $OUTPUT_DIR ./test_output"
log "  2. Copy the MBTiles to the downloads server"
log "  3. Test in the app"

# Cleanup
rm -f /tmp/usgs_download_url.txt /tmp/usgs_download_name.txt
