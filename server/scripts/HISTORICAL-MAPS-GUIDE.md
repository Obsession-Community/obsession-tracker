# Historical Maps Processing Guide

This guide walks through downloading and processing historical maps for the Obsession Tracker app.

## Production Status (January 2026)

**All 48 continental US states are now processed and deployed.**

| Metric | Value |
|--------|-------|
| States | 48 (continental US) |
| Total Quadrangles | 16,142 |
| Total Storage | ~46 GB |
| Era | Early Topos (1880-1925) |

Server location: `/var/www/downloads/states/{STATE}/maps/early_topo/quads/`

To check current production status:
```bash
ssh root@YOUR_SERVER_IP "cd /var/www/downloads/states && for d in */maps/early_topo/quads; do count=\$(ls -1 \"\$d\"/*.mbtiles 2>/dev/null | wc -l); if [ \$count -gt 0 ]; then echo \"\$(dirname \$(dirname \$(dirname \"\$d\"))): \$count quads\"; fi; done | sort"
```

---

## Quick Start (Wyoming Pilot)

### Prerequisites

```bash
# Install GDAL (macOS)
brew install gdal

# Install GDAL (Ubuntu/Debian)
sudo apt install gdal-bin python3-gdal

# Optional: Install mb-util for easier MBTiles creation
pip install mbutil
```

### Step 1: Download Source Maps

**USGS Historical Topographic Maps:**
1. Go to https://ngmdb.usgs.gov/topoview/
2. Navigate to Wyoming
3. Search for quads covering your area of interest
4. Download as GeoTIFF (not GeoPDF)
5. Save to `./source_maps/wyoming/`

**For a simpler start, download pre-georeferenced state mosaics:**
- USGS HTMC (Historical Topographic Map Collection): https://www.usgs.gov/programs/national-geospatial-program/historical-topographic-maps-preserving-past

**GLO Survey Plats:**
1. Go to https://glorecords.blm.gov/
2. Click "Survey Plats"
3. Search by state (WY) and township
4. Download as TIF
5. Note: These may need georeferencing if not already georeferenced

### Step 2: Organize Source Files

```
source_maps/
└── WY/
    ├── survey/           # GLO survey plats (for maps_survey.mbtiles)
    │   ├── T42N_R104W.tif
    │   └── T43N_R104W.tif
    └── early_topo/       # 1890s-1920s USGS topos (for maps_early_topo.mbtiles)
        ├── laramie_1897.tif
        └── cheyenne_1905.tif
```

### Step 3: Process to MBTiles

```bash
# Process survey era maps
gdal2tiles.py --zoom=8-15 --processes=4 ./source_maps/WY/survey/*.tif ./temp/survey_tiles
mb-util ./temp/survey_tiles ./output/WY/maps_survey.mbtiles --image_format=png --scheme=tms

# Process early topos
gdal2tiles.py --zoom=8-15 --processes=4 ./source_maps/WY/early_topo/*.tif ./temp/early_tiles
mb-util ./temp/early_tiles ./output/WY/maps_early_topo.mbtiles --image_format=png --scheme=tms
```

Or use the processing script:
```bash
./process-historical-maps.sh WY ./source_maps/WY ./output
```

### Step 4: Verify Output

```bash
# Check file size
ls -lh output/WY/*.mbtiles

# Verify MBTiles structure
sqlite3 output/WY/maps_survey.mbtiles ".tables"
# Should show: metadata  tiles

sqlite3 output/WY/maps_survey.mbtiles "SELECT * FROM metadata;"
# Should show layer metadata

sqlite3 output/WY/maps_survey.mbtiles "SELECT COUNT(*) FROM tiles;"
# Should show tile count
```

### Step 5: Upload to Server

```bash
# SSH to droplet
ssh root@YOUR_SERVER_IP

# Create directory if needed
mkdir -p /var/www/downloads/states/WY

# Upload MBTiles files (from local machine)
scp output/WY/*.mbtiles root@YOUR_SERVER_IP:/var/www/downloads/states/WY/

# Verify on server
ls -lh /var/www/downloads/states/WY/
```

### Step 6: Test API Response

```bash
# Test manifest endpoint
curl https://api.obsessiontracker.com/api/v1/downloads/states/WY/manifest | jq

# Should include historical map layers:
# {
#   "state": "WY",
#   "layers": [
#     { "id": "land", ... },
#     { "id": "trails", ... },
#     { "id": "historical_places", ... },
#     { "id": "maps_survey", "type": "raster", "era": "1850-1890", ... },
#     { "id": "maps_early_topo", "type": "raster", "era": "1890-1920", ... }
#   ]
# }
```

---

## Recommended Starting Quads for Wyoming

For "Beyond the Maps Edge" (1873-era treasure hunt), these areas are historically significant:

### Yellowstone Region
- **Old Faithful quad** (1904) - Early park development
- **Mammoth quad** (1896) - Original park headquarters area

### Mining Districts
- **South Pass City** (1891) - Gold rush era, ghost towns
- **Atlantic City** (1891) - Historic mining district

### GLO Survey Plats
- T30N R100W - Fremont County, mining claims
- T32N R98W - South Pass area

---

## File Size Estimates

| Layer | Expected Size | Notes |
|-------|--------------|-------|
| maps_survey.mbtiles | 50-100 MB | Depends on coverage density |
| maps_early_topo.mbtiles | 100-200 MB | Full state coverage |

---

## Troubleshooting

### GeoTIFF not georeferenced
```bash
# Check if file has projection info
gdalinfo source.tif | grep "Coordinate System"

# If missing, you need to georeference in QGIS or use GCPs
```

### GDAL memory issues with large files
```bash
# Process in smaller batches or use virtual raster (VRT)
gdalbuildvrt mosaic.vrt source_maps/*.tif
gdal2tiles.py --zoom=8-12 mosaic.vrt ./tiles
```

### MBTiles too large
```bash
# Reduce zoom levels (8-14 instead of 8-16)
# Or use WebP format instead of PNG (smaller but less compatible)
gdal2tiles.py --zoom=8-14 --tiledriver=webp source.tif ./tiles
```

---

## Production Processing Workflow

### Scripts Overview

| Script | Purpose |
|--------|---------|
| `process-quadrangles.sh` | Convert individual GeoTIFFs to MBTiles |
| `generate-manifest.sh` | Generate JSON manifest for API serving |
| `process-historical-maps.sh` | Legacy combined MBTiles processing |
| `process-historical-maps-batch.sh` | Batch wrapper for multiple files |

### Step-by-Step for New State

```bash
# 1. Download GeoTIFFs from USGS TopoView
#    https://ngmdb.usgs.gov/topoview/
#    Save to ./downloads/{STATE}/

# 2. Process to individual MBTiles (4-8 parallel cores)
./process-quadrangles.sh CA ./downloads/CA ./output early_topo 8

# 3. Upload to server
scp -r ./output/CA/maps/early_topo/quads root@YOUR_SERVER_IP:/var/www/downloads/states/CA/maps/early_topo/

# 4. Generate manifest on server
ssh root@YOUR_SERVER_IP "cd /var/www/obsession/infrastructure && ./scripts/generate-manifest.sh CA"

# 5. Verify API serves manifest
curl https://api.obsessiontracker.com/api/v1/downloads/states/CA/maps/manifest
```

### MBTiles Structure

Each quadrangle MBTiles file contains:
- **Tiles**: JPEG tiles at zoom levels 10-13
- **Metadata table**: bounds, name, year, minzoom, maxzoom

```bash
# Inspect MBTiles
sqlite3 laramie_342388_1897.mbtiles ".tables"
# metadata  tiles

sqlite3 laramie_342388_1897.mbtiles "SELECT * FROM metadata;"
# bounds|-109.5,40.875,-109.375,41.0
# name|Laramie
# year|1897
# ...
```

### Server File Structure

```
/var/www/downloads/states/
├── AK/  (Alaska - not processed, no USGS coverage)
├── AL/
│   └── maps/
│       └── early_topo/
│           └── quads/
│               ├── manifest.json        # Auto-generated index
│               ├── birmingham_1234_1902.mbtiles
│               └── mobile_5678_1911.mbtiles
├── ...
└── WY/
    └── maps/
        └── early_topo/
            └── quads/
                ├── manifest.json
                ├── laramie_342388_1897.mbtiles
                └── south_pass_456789_1891.mbtiles
```

---

## API Reference

### Manifest Endpoint

```
GET /api/v1/downloads/states/:state/maps/manifest
```

Returns JSON with all available quadrangles for a state:

```json
{
  "state": "WY",
  "version": "2026.01",
  "generatedAt": "2026-01-25T...",
  "eras": [
    {
      "id": "early_topo",
      "name": "Early Topos",
      "description": "USGS topographic maps from the 1890s-1920s...",
      "yearRange": "1890-1920",
      "quadrangles": [
        {
          "id": "laramie_342388_1897",
          "name": "Laramie",
          "file": "maps/early_topo/quads/laramie_342388_1897.mbtiles",
          "size": 5242880,
          "bounds": {
            "west": -109.5,
            "south": 40.875,
            "east": -109.375,
            "north": 41.0
          },
          "year": 1897
        }
      ]
    }
  ]
}
```

### Download Endpoint

```
GET /api/v1/downloads/states/:state/maps/:era/quads/:filename
```

Returns the MBTiles file for direct download. Requires NHP premium authentication.

---

## Regenerating Manifests

If quadrangles are added or removed, regenerate the manifest:

```bash
# Single state
ssh root@YOUR_SERVER_IP "cd /var/www/obsession/infrastructure && ./scripts/generate-manifest.sh WY"

# All states
ssh root@YOUR_SERVER_IP "cd /var/www/obsession/infrastructure && ./scripts/generate-manifest.sh all"
```

---

*Last Updated: January 2026*
