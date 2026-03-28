#!/bin/bash
# USGS Historical Topographic Maps Bulk Downloader
# Uses the TNM Access API to download all historical maps for a state
#
# Usage:
#   ./download-usgs-maps.sh <state_code> [output_dir] [format]
#
# Examples:
#   ./download-usgs-maps.sh WY                    # Download Wyoming maps as GeoTIFF
#   ./download-usgs-maps.sh SD ./maps GeoTIFF     # Download South Dakota as GeoTIFF
#   ./download-usgs-maps.sh WY ./maps GeoPDF      # Download as GeoPDF (smaller)

set -e

# ============================================
# Configuration
# ============================================

STATE_CODE="${1:-WY}"
OUTPUT_DIR="${2:-./usgs_downloads/${STATE_CODE}}"
FORMAT="${3:-GeoTIFF}"  # GeoTIFF, GeoPDF, JPEG, KMZ
START_DATE="${4:-1880-01-01}"  # Filter by publication date
END_DATE="${5:-1925-01-01}"    # End date for historical era

# TNM API base URL
API_BASE="https://tnmaccess.nationalmap.gov/api/v1"

# State FIPS codes (used by TNM API) - compatible with all bash versions
get_state_fips() {
    case "$1" in
        AL) echo "01";; AK) echo "02";; AZ) echo "04";; AR) echo "05";; CA) echo "06";;
        CO) echo "08";; CT) echo "09";; DE) echo "10";; FL) echo "12";; GA) echo "13";;
        HI) echo "15";; ID) echo "16";; IL) echo "17";; IN) echo "18";; IA) echo "19";;
        KS) echo "20";; KY) echo "21";; LA) echo "22";; ME) echo "23";; MD) echo "24";;
        MA) echo "25";; MI) echo "26";; MN) echo "27";; MS) echo "28";; MO) echo "29";;
        MT) echo "30";; NE) echo "31";; NV) echo "32";; NH) echo "33";; NJ) echo "34";;
        NM) echo "35";; NY) echo "36";; NC) echo "37";; ND) echo "38";; OH) echo "39";;
        OK) echo "40";; OR) echo "41";; PA) echo "42";; RI) echo "44";; SC) echo "45";;
        SD) echo "46";; TN) echo "47";; TX) echo "48";; UT) echo "49";; VT) echo "50";;
        VA) echo "51";; WA) echo "53";; WV) echo "54";; WI) echo "55";; WY) echo "56";;
        *) echo "";;
    esac
}

# ============================================
# Functions
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_dependencies() {
    if ! command -v curl &> /dev/null; then
        echo "ERROR: curl not found"
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq not found. Install with: brew install jq"
        exit 1
    fi
}

get_fips_code() {
    local state="$1"
    local fips=$(get_state_fips "$state")
    if [ -z "$fips" ]; then
        echo "ERROR: Unknown state code: $state" >&2
        exit 1
    fi
    echo "$fips"
}

# Query the TNM API for products
query_products() {
    local fips_code="$1"
    local offset="${2:-0}"
    local max="${3:-1000}"

    local url="${API_BASE}/products"
    url+="?datasets=Historical%20Topographic%20Maps"
    url+="&polyType=state"
    url+="&polyCode=${fips_code}"
    url+="&prodFormats=${FORMAT}"
    url+="&dateType=Publication"
    url+="&start=${START_DATE}"
    url+="&end=${END_DATE}"
    url+="&max=${max}"
    url+="&offset=${offset}"
    url+="&outputFormat=JSON"

    curl -s "$url"
}

# Extract download URLs from API response
extract_download_urls() {
    local json="$1"

    # Extract URLs for the specified format
    echo "$json" | jq -r --arg fmt "$FORMAT" '
        .items[]? |
        .urls |
        to_entries[] |
        select(.key | ascii_downcase | contains($fmt | ascii_downcase)) |
        .value
    ' 2>/dev/null || echo ""
}

# Download a single file with retry
download_file() {
    local url="$1"
    local output_dir="$2"
    local filename=$(basename "$url" | sed 's/\?.*//')  # Remove query params
    local output_path="${output_dir}/${filename}"

    if [ -f "$output_path" ]; then
        log "  Skipping (exists): $filename"
        return 0
    fi

    log "  Downloading: $filename"

    # Download with retry
    local retries=3
    while [ $retries -gt 0 ]; do
        if curl -sL -o "$output_path" "$url"; then
            # Verify file was downloaded
            if [ -s "$output_path" ]; then
                return 0
            fi
        fi
        retries=$((retries - 1))
        log "    Retry remaining: $retries"
        sleep 2
    done

    log "  ERROR: Failed to download $filename"
    rm -f "$output_path"
    return 1
}

# ============================================
# Main
# ============================================

main() {
    log "USGS Historical Topographic Maps Downloader"
    log "State: $STATE_CODE"
    log "Format: $FORMAT"
    log "Date Range: $START_DATE to $END_DATE"
    log "Output: $OUTPUT_DIR"
    echo ""

    check_dependencies

    # Get FIPS code for state
    local fips_code=$(get_fips_code "$STATE_CODE")
    log "State FIPS code: $fips_code"

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Query API for total count first
    log "Querying TNM API for available maps..."
    local initial_response=$(query_products "$fips_code" 0 1)
    local total=$(echo "$initial_response" | jq -r '.total // 0')

    if [ "$total" == "0" ] || [ -z "$total" ]; then
        log "No historical maps found for $STATE_CODE"
        log "Try a different format: GeoTIFF, GeoPDF, JPEG"
        exit 1
    fi

    log "Found $total historical maps for $STATE_CODE"

    # Collect all download URLs
    local all_urls=""
    local offset=0
    local batch_size=100

    while [ $offset -lt $total ]; do
        log "Fetching products $offset - $((offset + batch_size))..."
        local response=$(query_products "$fips_code" "$offset" "$batch_size")
        local urls=$(extract_download_urls "$response")

        if [ -n "$urls" ]; then
            all_urls+="$urls"$'\n'
        fi

        offset=$((offset + batch_size))
    done

    # Count unique URLs
    local url_count=$(echo "$all_urls" | grep -c "http" || echo "0")
    log "Found $url_count downloadable files"

    if [ "$url_count" == "0" ]; then
        log "No download URLs found. The API may not have $FORMAT files available."
        log "Available formats vary by map - try GeoPDF which has better coverage."
        exit 1
    fi

    # Download files
    log ""
    log "Starting downloads..."
    local downloaded=0
    local failed=0

    echo "$all_urls" | grep "http" | sort -u | while read -r url; do
        if [ -n "$url" ]; then
            if download_file "$url" "$OUTPUT_DIR"; then
                downloaded=$((downloaded + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done

    log ""
    log "Download complete!"
    log "Output directory: $OUTPUT_DIR"
    log "Files downloaded: $(ls -1 "$OUTPUT_DIR" | wc -l | tr -d ' ')"
    log ""
    log "Next step: Process to MBTiles"
    log "  ./process-historical-maps.sh $STATE_CODE $OUTPUT_DIR ./output"
}

# ============================================
# Help
# ============================================

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    cat <<EOF
USGS Historical Topographic Maps Bulk Downloader

Downloads historical topographic maps for a US state using the TNM Access API.

USAGE:
    $0 <state_code> [output_dir] [format] [start_date] [end_date]

ARGUMENTS:
    state_code    Two-letter state code (e.g., WY, SD, CO)
    output_dir    Output directory (default: ./usgs_downloads/{state})
    format        File format: GeoTIFF, GeoPDF, JPEG, KMZ (default: GeoTIFF)
    start_date    Publication date filter start (default: 1880-01-01)
    end_date      Publication date filter end (default: 1925-01-01)

EXAMPLES:
    $0 WY                                          # Download WY 1880-1925 as GeoTIFF
    $0 WY ./wy_maps GeoTIFF 1890-01-01 1920-01-01  # Download WY 1890-1920
    $0 SD ./sd_maps GeoPDF                         # Download SD as GeoPDF

DATE RANGES FOR TREASURE HUNTING:
    1880-1925 (default) - Early era, most relevant for historical research
    1940-1960           - Mid-century, shows transition period
    1960-1990           - Modern era, better detail but less "historical"

NOTES:
    - GeoTIFF is best for processing to MBTiles (~9MB per map)
    - For WY 1880-1925: ~264 maps, ~2.4GB download, ~500MB-1GB as MBTiles
    - Script will skip already-downloaded files (resumable)

API DOCUMENTATION:
    https://tnmaccess.nationalmap.gov/api/v1/docs

NEXT STEPS:
    After downloading, process to MBTiles:
    ./process-historical-maps.sh WY ./usgs_downloads/WY ./output
EOF
    exit 0
fi

main
