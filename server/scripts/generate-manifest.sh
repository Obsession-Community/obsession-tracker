#!/bin/bash
# Generate static manifest.json for a state's historical maps
#
# This script generates a manifest.json file that contains:
# - Quadrangle bounds (from MBTiles metadata)
# - File sizes
# - SHA256 checksums
# - Era groupings
#
# The resulting manifest.json is served instantly by the API instead
# of dynamically generating it on each request (which takes 10+ seconds
# for large states like California with 686 quadrangles).
#
# Usage:
#   ./generate-manifest.sh <state_code>     # Generate for single state
#   ./generate-manifest.sh all              # Generate for all states with maps
#
# Remote Usage (from local machine):
#   ssh root@YOUR_SERVER_IP "cd /var/www/obsession/infrastructure && ./scripts/generate-manifest.sh WY"

set -e

STATE_CODE="${1:-}"
DOWNLOADS_PATH="${DOWNLOADS_PATH:-/var/www/downloads}"

# Era definitions (must match server ERA_DEFINITIONS)
declare -A ERA_NAMES=(
    ["survey"]="Survey Era Maps"
    ["early_topo"]="Early Topos"
    ["midcentury"]="Mid-Century Maps"
)

declare -A ERA_DESCRIPTIONS=(
    ["survey"]="GLO survey plats from the 1850s-1890s showing original land surveys and mining claims"
    ["early_topo"]="USGS topographic maps from the 1890s-1920s showing mining districts and settlements"
    ["midcentury"]="USGS topographic maps from the 1940s-1960s with modern features"
)

declare -A ERA_YEAR_RANGES=(
    ["survey"]="1850-1890"
    ["early_topo"]="1890-1920"
    ["midcentury"]="1940-1960"
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Read bounds from MBTiles metadata table
get_mbtiles_bounds() {
    local file="$1"
    sqlite3 -separator ',' "$file" "SELECT value FROM metadata WHERE name = 'bounds';" 2>/dev/null || echo ""
}

# Extract year from filename (e.g., laramie_1897.mbtiles -> 1897)
extract_year() {
    local filename="$1"
    echo "$filename" | grep -oE '_[0-9]{4}\.' | tr -d '_.' || echo "0"
}

# Convert filename to display name (e.g., south_pass_1891 -> South Pass)
filename_to_name() {
    local filename="$1"
    # Remove extension and year suffix
    local base=$(echo "$filename" | sed 's/\.mbtiles$//' | sed 's/_[0-9]*$//')
    # Title case with spaces
    echo "$base" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

# Calculate SHA256 checksum
calculate_checksum() {
    local file="$1"
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

    # Only calculate checksum for files under 50MB (larger files slow down generation)
    if [ "$size" -lt 52428800 ]; then
        sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1 || echo ""
    else
        echo ""
    fi
}

# Generate manifest for a single state
generate_state_manifest() {
    local state="$1"
    local state_path="${DOWNLOADS_PATH}/states/${state}"
    local maps_path="${state_path}/maps"
    local manifest_file="${maps_path}/manifest.json"

    if [ ! -d "$maps_path" ]; then
        log "No maps directory for $state, skipping..."
        return 0
    fi

    log "Generating manifest for $state..."
    local start_time=$(date +%s)

    # Start building JSON
    local eras_json=""
    local first_era=true
    local total_quads=0

    # Process each era
    for era in survey early_topo midcentury; do
        local quads_path="${maps_path}/${era}/quads"

        if [ ! -d "$quads_path" ]; then
            continue
        fi

        local quad_files=$(ls -1 "$quads_path"/*.mbtiles 2>/dev/null || true)
        if [ -z "$quad_files" ]; then
            continue
        fi

        # Build quadrangles array
        local quads_json=""
        local first_quad=true

        while IFS= read -r quad_file; do
            local filename=$(basename "$quad_file")
            local id=$(echo "$filename" | sed 's/\.mbtiles$//')
            local name=$(filename_to_name "$filename")
            local size=$(stat -f%z "$quad_file" 2>/dev/null || stat -c%s "$quad_file" 2>/dev/null)
            local year=$(extract_year "$filename")
            local bounds=$(get_mbtiles_bounds "$quad_file")
            local checksum=$(calculate_checksum "$quad_file")

            # Check if file has tiles (skip empty/corrupt files)
            local tile_count=$(sqlite3 "$quad_file" "SELECT COUNT(*) FROM tiles;" 2>/dev/null || echo "0")
            if [ "$tile_count" -eq 0 ]; then
                continue  # Skip files with no tiles
            fi

            # Parse bounds (west,south,east,north)
            if [ -n "$bounds" ]; then
                local west=$(echo "$bounds" | cut -d',' -f1)
                local south=$(echo "$bounds" | cut -d',' -f2)
                local east=$(echo "$bounds" | cut -d',' -f3)
                local north=$(echo "$bounds" | cut -d',' -f4)

                local quad_json="{"
                quad_json+="\"id\":\"$id\","
                quad_json+="\"name\":\"$name\","
                quad_json+="\"file\":\"maps/${era}/quads/${filename}\","
                quad_json+="\"size\":$size,"
                quad_json+="\"bounds\":{\"west\":$west,\"south\":$south,\"east\":$east,\"north\":$north},"
                quad_json+="\"year\":$year"
                if [ -n "$checksum" ]; then
                    quad_json+=",\"checksum\":\"sha256:$checksum\""
                fi
                quad_json+="}"

                if [ "$first_quad" = true ]; then
                    quads_json="$quad_json"
                    first_quad=false
                else
                    quads_json+=",${quad_json}"
                fi

                total_quads=$((total_quads + 1))
            fi
        done <<< "$quad_files"

        if [ -n "$quads_json" ]; then
            local era_name="${ERA_NAMES[$era]}"
            local era_desc="${ERA_DESCRIPTIONS[$era]}"
            local era_years="${ERA_YEAR_RANGES[$era]}"

            local era_json="{"
            era_json+="\"id\":\"$era\","
            era_json+="\"name\":\"$era_name\","
            era_json+="\"description\":\"$era_desc\","
            era_json+="\"yearRange\":\"$era_years\","
            era_json+="\"quadrangles\":[$quads_json]"
            era_json+="}"

            if [ "$first_era" = true ]; then
                eras_json="$era_json"
                first_era=false
            else
                eras_json+=",${era_json}"
            fi
        fi
    done

    if [ -z "$eras_json" ]; then
        log "No quadrangles found for $state, skipping..."
        return 0
    fi

    # Build final manifest
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local manifest="{"
    manifest+="\"state\":\"$state\","
    manifest+="\"version\":\"2026.01\","
    manifest+="\"generatedAt\":\"$now\","
    manifest+="\"eras\":[$eras_json]"
    manifest+="}"

    # Write to file (use jq for pretty formatting if available)
    if command -v jq &> /dev/null; then
        echo "$manifest" | jq '.' > "$manifest_file"
    else
        echo "$manifest" > "$manifest_file"
    fi

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local size=$(stat -f%z "$manifest_file" 2>/dev/null || stat -c%s "$manifest_file" 2>/dev/null)
    local size_kb=$((size / 1024))

    log "Generated $state manifest: $total_quads quads, ${size_kb}KB, ${elapsed}s"
}

# Generate manifests for all states
generate_all_manifests() {
    local states_path="${DOWNLOADS_PATH}/states"

    if [ ! -d "$states_path" ]; then
        log "ERROR: States directory not found: $states_path"
        exit 1
    fi

    local states=($(ls -1 "$states_path" | grep -E '^[A-Z]{2}$' || true))
    local count=0
    local total=${#states[@]}

    log "Generating manifests for $total states..."

    for state in "${states[@]}"; do
        count=$((count + 1))
        generate_state_manifest "$state"
    done

    log "Completed: $count states processed"
}

# Main
if [ -z "$STATE_CODE" ]; then
    echo "Usage: $0 <state_code|all>"
    echo ""
    echo "Examples:"
    echo "  $0 WY      Generate manifest for Wyoming"
    echo "  $0 all     Generate manifests for all states"
    exit 1
fi

if [ "$STATE_CODE" = "all" ]; then
    generate_all_manifests
else
    STATE_CODE=$(echo "$STATE_CODE" | tr '[:lower:]' '[:upper:]')
    generate_state_manifest "$STATE_CODE"
fi
