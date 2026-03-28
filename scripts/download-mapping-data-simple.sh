#!/bin/bash

# PAD-US Geodatabase Download Script for Obsession Tracker BFF
# Downloads state-specific protected areas data for treasure hunting application

set -e

# Configuration
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$(pwd)/mapping-data}"
PAD_US_VERSION="4.1"

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Create download directory
mkdir -p "$DOWNLOAD_DIR/pad-us-$PAD_US_VERSION"
cd "$DOWNLOAD_DIR/pad-us-$PAD_US_VERSION"

print_status "Starting PAD-US $PAD_US_VERSION geodatabase download (South Dakota test)..."

# Function to download and extract state data
download_state() {
    local state_code=$1
    local download_id=$2
    local expected_size=$3
    local filename="PADUS${PAD_US_VERSION}_State_${state_code}_GDB_KMZ.zip"
    
    print_info "Downloading $state_code ($filename)..."
    
    # Download with progress bar
    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar \
             -o "$filename" \
             "https://sciencebase.usgs.gov/manager/download/$download_id"
    elif command -v wget >/dev/null 2>&1; then
        wget --progress=bar \
             -O "$filename" \
             "https://sciencebase.usgs.gov/manager/download/$download_id"
    else
        print_warning "Neither curl nor wget found. Please install one of them."
        return 1
    fi
    
    # Verify download
    if [[ -f "$filename" ]]; then
        local actual_size
        if [[ "$OSTYPE" == "darwin"* ]]; then
            actual_size=$(stat -f%z "$filename" 2>/dev/null)
        else
            actual_size=$(stat -c%s "$filename" 2>/dev/null)
        fi
        print_status "$state_code downloaded: ${actual_size} bytes"
        
        # Extract the geodatabase
        if command -v unzip >/dev/null 2>&1; then
            print_info "Extracting $state_code geodatabase..."
            unzip -q "$filename" -d "${state_code}_extracted"
            
            # Find and organize the .gdb file
            local gdb_file=$(find "${state_code}_extracted" -name "*.gdb" -type d | head -1)
            if [[ -n "$gdb_file" ]]; then
                mv "$gdb_file" "PADUS_${state_code}.gdb"
                print_status "$state_code geodatabase ready: PADUS_${state_code}.gdb"
            else
                print_warning "No .gdb file found for $state_code"
            fi
            
            # Clean up
            rm -rf "${state_code}_extracted"
        else
            print_warning "unzip not found. Keeping zip file: $filename"
        fi
        
    else
        print_warning "Failed to download $state_code"
        return 1
    fi
}

# Test download: South Dakota only
print_info "Testing download with South Dakota..."

# South Dakota: Download ID and expected size
download_state "SD" "cm8wkiwi100170upn5qznfdec" "57067221"

# Create metadata file
cat > "download_metadata.json" << EOF
{
    "pad_us_version": "$PAD_US_VERSION",
    "download_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "download_source": "USGS PAD-US Data Download",
    "citation": "U.S. Geological Survey (USGS) Gap Analysis Project (GAP), 2024, Protected Areas Database of the United States (PAD-US) 4.1",
    "states_downloaded": ["SD"],
    "test_run": true,
    "purpose": "Obsession Tracker BFF - Land ownership data for treasure hunting application",
    "data_format": "ESRI Geodatabase (.gdb)",
    "coordinate_system": "Geographic (WGS84)",
    "data_use_disclaimer": "This data is not suitable for legal survey purposes. Consult official land management agencies for definitive boundaries."
}
EOF

# Download summary
print_status "PAD-US test download completed!"
echo ""
print_info "Downloaded geodatabases:"
ls -lah *.gdb 2>/dev/null || echo "No .gdb files found (check for zip files)"
echo ""
print_info "All files in directory:"
ls -lah
echo ""
print_info "Total download size:"
du -sh . 2>/dev/null || echo "Unable to calculate size"
echo ""

if [[ -d "PADUS_SD.gdb" ]]; then
    print_status "SUCCESS: South Dakota geodatabase ready for processing!"
    print_info "Next steps:"
    echo "  1. Test with additional states (WY, CO, NM)"
    echo "  2. Set up PostGIS database"  
    echo "  3. Process geodatabase into PostgreSQL"
    echo "  4. Configure BFF Spring Boot service"
else
    print_warning "Geodatabase extraction may have failed. Check zip file contents."
fi

echo ""
print_warning "Legal notice:"
echo "This data is for mapping purposes only and is not legally authoritative."
echo "Always consult official land management agencies for legal boundary information."