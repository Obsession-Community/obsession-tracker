# Cell Coverage Data Processing Guide

This guide walks through downloading and processing cell tower data for the Obsession Tracker app.

## Data Source

**OpenCelliD** - The world's largest open database of cell towers
- Website: https://opencellid.org/
- License: CC-BY-SA 4.0 (attribution required)
- Coverage: 40+ million cell towers globally

## Quick Start

### Prerequisites

```bash
# Python 3.9+
python3 --version

# No additional packages required - uses standard library only
```

### Step 1: Download OpenCelliD Data

1. Go to https://opencellid.org/downloads.php
2. Register for a free API token (required for downloads)
3. Download US cell tower data:
   - MCC 310 (primary US MCC)
   - MCC 311, 312, 313, 316 (additional US MCCs)
4. Save CSV files to `./source_data/`

**Alternative: Use the full world download and filter locally:**
```bash
# Download full database (warning: ~1GB compressed)
wget "https://opencellid.org/ocid/downloads?token=YOUR_TOKEN&file=cell_towers.csv.gz"
gunzip cell_towers.csv.gz
```

### Step 2: Process Cell Tower Data

```bash
# Process all US states
python3 process-cell-coverage.py cell_towers.csv ./output/states

# Process a single state (for testing)
python3 process-cell-coverage.py cell_towers.csv ./output/states --state WY
```

### Step 3: Verify Output

```bash
# Check file sizes
ls -lh output/states/*/cell.zip

# Verify ZIP contents
unzip -l output/states/WY/cell.zip

# Check tower count
unzip -p output/states/WY/cell.zip version.json | jq .
```

Expected output:
```json
{
  "version": "2026-01",
  "source": "OpenCelliD",
  "record_count": 12345,
  "generated_at": "2026-01-25T..."
}
```

### Step 4: Upload to Server

```bash
# SSH to droplet
ssh root@YOUR_SERVER_IP

# Create directories if needed
for state in AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC; do
  mkdir -p /var/www/downloads/states/$state
done

# Upload cell.zip files (from local machine)
for state in output/states/*/; do
  state_code=$(basename $state)
  scp $state/cell.zip root@YOUR_SERVER_IP:/var/www/downloads/states/$state_code/
done

# Verify on server
ls -lh /var/www/downloads/states/*/cell.zip | head -20
```

## Data Format

### Input (OpenCelliD CSV)

```csv
radio,mcc,net,area,cell,unit,lon,lat,range,samples,changeable,created,updated,averageSignal
LTE,310,260,12345,67890,0,-104.8213,41.1397,5000,42,1,1609459200,1704067200,-75
```

### Output (cell.zip/data.json)

```json
{
  "version": "2026-01",
  "source": "OpenCelliD",
  "attribution": "Data from OpenCelliD (CC-BY-SA 4.0)",
  "towers": [
    {
      "id": "310-260-12345-67890",
      "lat": 41.1397,
      "lon": -104.8213,
      "radio": "LTE",
      "mcc": 310,
      "mnc": 260,
      "carrier": "T-Mobile",
      "range_meters": 5000,
      "samples": 42,
      "updated": "2024-01-01"
    }
  ],
  "types": {
    "GSM": { "name": "2G (GSM)", "color": "#FF6B6B", "order": 1 },
    "UMTS": { "name": "3G (UMTS)", "color": "#FFA94D", "order": 2 },
    "LTE": { "name": "4G (LTE)", "color": "#69DB7C", "order": 3 },
    "NR": { "name": "5G (NR)", "color": "#4DABF7", "order": 4 }
  }
}
```

## Radio Types

| Code | Name | Color | Description |
|------|------|-------|-------------|
| GSM | 2G | Red | Oldest technology, voice/SMS |
| CDMA | 2G | Red | Legacy Verizon/Sprint 2G |
| UMTS | 3G | Orange | Basic data, slow speeds |
| LTE | 4G | Green | Good data speeds |
| NR | 5G | Blue | Latest technology, fastest |

## File Sizes

Expected compressed sizes per state:

| Size | Example States |
|------|---------------|
| < 500 KB | WY, MT, ND, SD, VT |
| 500 KB - 1 MB | NM, NE, ID, ME |
| 1 - 2 MB | CO, AZ, OR, UT |
| 2 - 5 MB | WA, GA, NC, PA |
| 5 - 10 MB | FL, NY, IL, OH |
| > 10 MB | CA, TX |

## Troubleshooting

### "No data found for state X"

The state may have very few towers in the OpenCelliD database. Check:
1. Verify the input CSV contains US data (MCC 310-316)
2. Some rural states may have <1000 towers

### "Invalid coordinates"

OpenCelliD data sometimes contains invalid entries. The script filters these automatically.

### File too large

If a state ZIP exceeds 5MB, consider:
1. Filtering to only LTE/NR towers
2. Reducing `range_meters` precision
3. Removing low-sample entries

## Updating Data

OpenCelliD data is updated continuously. Recommended update schedule:

1. **Quarterly**: Download fresh data and reprocess
2. **Version bump**: Update version string in script to `YYYY-MM`
3. **Deploy**: Upload new cell.zip files to server

## Attribution

When displaying cell coverage data, include attribution:

> Cell coverage data from [OpenCelliD](https://opencellid.org/) (CC-BY-SA 4.0)

This is required by the license and should appear in the app's About/Legal section.
