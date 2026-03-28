#!/usr/bin/env python3
"""
Process OpenCelliD cell tower data into state-level ZIP files for Obsession Tracker.

Data Source: OpenCelliD (CC-BY-SA 4.0)
- Download from: https://opencellid.org/downloads.php
- Format: CSV with columns: radio,mcc,net,area,cell,unit,lon,lat,range,samples,changeable,created,updated,averageSignal

Usage:
    1. Download US cell data from OpenCelliD (MCC 310, 311, 312, 313, 316)
    2. Run: python3 process-cell-coverage.py <input_csv> <output_dir>

Example:
    python3 process-cell-coverage.py cell_towers_us.csv ./output/states

Output Structure:
    output/states/
    ├── WY/
    │   └── cell.zip
    │       ├── data.json
    │       └── version.json
    ├── CO/
    │   └── cell.zip
    ...
"""

import argparse
import csv
import json
import os
import sys
import zipfile
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

# US state bounding boxes (approximate, used to assign towers to states)
# Format: {state_code: (min_lon, min_lat, max_lon, max_lat)}
STATE_BOUNDS = {
    'AL': (-88.47, 30.22, -84.89, 35.01),
    'AK': (-179.15, 51.21, 179.77, 71.35),
    'AZ': (-114.81, 31.33, -109.05, 37.00),
    'AR': (-94.62, 33.00, -89.64, 36.50),
    'CA': (-124.41, 32.53, -114.13, 42.01),
    'CO': (-109.06, 36.99, -102.04, 41.00),
    'CT': (-73.73, 40.95, -71.79, 42.05),
    'DE': (-75.79, 38.45, -75.05, 39.84),
    'FL': (-87.63, 24.52, -80.03, 31.00),
    'GA': (-85.61, 30.36, -80.84, 35.00),
    'HI': (-160.24, 18.91, -154.81, 22.24),
    'ID': (-117.24, 41.99, -111.04, 49.00),
    'IL': (-91.51, 36.97, -87.02, 42.51),
    'IN': (-88.10, 37.77, -84.78, 41.76),
    'IA': (-96.64, 40.38, -90.14, 43.50),
    'KS': (-102.05, 36.99, -94.59, 40.00),
    'KY': (-89.57, 36.50, -81.96, 39.15),
    'LA': (-94.04, 28.93, -89.00, 33.02),
    'ME': (-71.08, 43.06, -66.95, 47.46),
    'MD': (-79.49, 37.91, -75.05, 39.72),
    'MA': (-73.51, 41.24, -69.93, 42.89),
    'MI': (-90.42, 41.70, -82.41, 48.30),
    'MN': (-97.24, 43.50, -89.49, 49.38),
    'MS': (-91.66, 30.17, -88.10, 35.00),
    'MO': (-95.77, 35.99, -89.10, 40.61),
    'MT': (-116.05, 44.36, -104.04, 49.00),
    'NE': (-104.05, 40.00, -95.31, 43.00),
    'NV': (-120.00, 35.00, -114.04, 42.00),
    'NH': (-72.56, 42.70, -70.70, 45.31),
    'NJ': (-75.56, 38.93, -73.89, 41.36),
    'NM': (-109.05, 31.33, -103.00, 37.00),
    'NY': (-79.76, 40.50, -71.86, 45.02),
    'NC': (-84.32, 33.84, -75.46, 36.59),
    'ND': (-104.05, 45.94, -96.55, 49.00),
    'OH': (-84.82, 38.40, -80.52, 42.00),
    'OK': (-103.00, 33.62, -94.43, 37.00),
    'OR': (-124.57, 41.99, -116.46, 46.29),
    'PA': (-80.52, 39.72, -74.69, 42.27),
    'RI': (-71.86, 41.15, -71.12, 42.02),
    'SC': (-83.35, 32.03, -78.54, 35.22),
    'SD': (-104.06, 42.48, -96.44, 45.95),
    'TN': (-90.31, 34.98, -81.65, 36.68),
    'TX': (-106.65, 25.84, -93.51, 36.50),
    'UT': (-114.05, 37.00, -109.04, 42.00),
    'VT': (-73.44, 42.73, -71.47, 45.02),
    'VA': (-83.68, 36.54, -75.24, 39.47),
    'WA': (-124.76, 45.54, -116.92, 49.00),
    'WV': (-82.64, 37.20, -77.72, 40.64),
    'WI': (-92.89, 42.49, -86.25, 47.08),
    'WY': (-111.06, 40.99, -104.05, 45.01),
    'DC': (-77.12, 38.79, -76.91, 38.99),
}

# MCC/MNC to carrier name mapping (US carriers)
# MCC 310, 311, 312, 313, 316 are US mobile country codes
CARRIER_MAP = {
    # Major carriers
    (310, 260): 'T-Mobile',
    (310, 200): 'T-Mobile',
    (310, 210): 'T-Mobile',
    (310, 220): 'T-Mobile',
    (310, 230): 'T-Mobile',
    (310, 240): 'T-Mobile',
    (310, 250): 'T-Mobile',
    (310, 270): 'T-Mobile',
    (310, 310): 'T-Mobile',
    (310, 490): 'T-Mobile',
    (310, 580): 'T-Mobile',
    (310, 660): 'T-Mobile',
    (310, 800): 'T-Mobile',
    (311, 490): 'T-Mobile',
    (311, 660): 'T-Mobile',
    (311, 882): 'T-Mobile',
    (311, 883): 'T-Mobile',
    (311, 884): 'T-Mobile',
    (311, 885): 'T-Mobile',
    (311, 886): 'T-Mobile',
    (312, 250): 'T-Mobile',

    (310, 410): 'AT&T',
    (310, 150): 'AT&T',
    (310, 170): 'AT&T',
    (310, 380): 'AT&T',
    (310, 560): 'AT&T',
    (310, 680): 'AT&T',
    (310, 980): 'AT&T',
    (311, 180): 'AT&T',
    (312, 670): 'AT&T',
    (312, 680): 'AT&T',

    (311, 480): 'Verizon',
    (310, 4): 'Verizon',
    (310, 10): 'Verizon',
    (310, 12): 'Verizon',
    (310, 13): 'Verizon',
    (311, 110): 'Verizon',
    (311, 270): 'Verizon',
    (311, 271): 'Verizon',
    (311, 272): 'Verizon',
    (311, 273): 'Verizon',
    (311, 274): 'Verizon',
    (311, 275): 'Verizon',
    (311, 276): 'Verizon',
    (311, 277): 'Verizon',
    (311, 278): 'Verizon',
    (311, 279): 'Verizon',
    (311, 280): 'Verizon',
    (311, 281): 'Verizon',
    (311, 282): 'Verizon',
    (311, 283): 'Verizon',
    (311, 284): 'Verizon',
    (311, 285): 'Verizon',
    (311, 286): 'Verizon',
    (311, 287): 'Verizon',
    (311, 288): 'Verizon',
    (311, 289): 'Verizon',
    (312, 770): 'Verizon',

    (310, 120): 'Sprint',
    (311, 490): 'Sprint',
    (311, 870): 'Sprint',
    (311, 880): 'Sprint',
    (312, 530): 'Sprint',

    (311, 370): 'US Cellular',
    (311, 580): 'US Cellular',
    (311, 581): 'US Cellular',
    (311, 582): 'US Cellular',
    (311, 583): 'US Cellular',
    (311, 584): 'US Cellular',
    (311, 585): 'US Cellular',
    (311, 586): 'US Cellular',
    (311, 587): 'US Cellular',
    (311, 588): 'US Cellular',
    (311, 589): 'US Cellular',

    # Dish Network
    (311, 890): 'Dish',
    (312, 190): 'Dish',
}

# Radio type mapping
RADIO_TYPES = {
    'GSM': {'name': '2G (GSM)', 'color': '#FF6B6B', 'order': 1},
    'CDMA': {'name': '2G (CDMA)', 'color': '#FF6B6B', 'order': 1},
    'UMTS': {'name': '3G (UMTS)', 'color': '#FFA94D', 'order': 2},
    'LTE': {'name': '4G (LTE)', 'color': '#69DB7C', 'order': 3},
    'NR': {'name': '5G (NR)', 'color': '#4DABF7', 'order': 4},
}


def get_carrier_name(mcc: int, mnc: int) -> str | None:
    """Look up carrier name from MCC/MNC code."""
    return CARRIER_MAP.get((mcc, mnc))


def get_state_for_coords(lon: float, lat: float) -> str | None:
    """Determine which US state a coordinate falls within."""
    for state_code, (min_lon, min_lat, max_lon, max_lat) in STATE_BOUNDS.items():
        if min_lon <= lon <= max_lon and min_lat <= lat <= max_lat:
            return state_code
    return None


def parse_csv_row(row: dict) -> dict | None:
    """Parse a single CSV row into a cell tower record."""
    try:
        radio = row.get('radio', '').upper()
        if radio not in RADIO_TYPES:
            return None

        mcc = int(row.get('mcc', 0))
        mnc = int(row.get('net', 0))

        # Only process US MCCs
        if mcc not in (310, 311, 312, 313, 316):
            return None

        lon = float(row.get('lon', 0))
        lat = float(row.get('lat', 0))

        # Validate coordinates
        if not (-180 <= lon <= 180 and -90 <= lat <= 90):
            return None
        if lon == 0 and lat == 0:
            return None

        range_meters = int(float(row.get('range', 0)))
        if range_meters <= 0:
            range_meters = 5000  # Default 5km if not provided

        samples = int(row.get('samples', 0))

        # Generate unique ID
        area = row.get('area', '0')
        cell = row.get('cell', '0')
        tower_id = f"{mcc}-{mnc}-{area}-{cell}"

        # Get carrier name
        carrier = get_carrier_name(mcc, mnc)

        # Parse updated timestamp
        updated = row.get('updated', '')
        if updated:
            try:
                updated_date = datetime.fromtimestamp(int(updated), tz=timezone.utc).date().isoformat()
            except (ValueError, OSError):
                updated_date = None
        else:
            updated_date = None

        return {
            'id': tower_id,
            'lat': lat,
            'lon': lon,
            'radio': radio,
            'mcc': mcc,
            'mnc': mnc,
            'carrier': carrier,
            'range_meters': range_meters,
            'samples': samples,
            'updated': updated_date,
        }
    except (ValueError, KeyError, TypeError) as e:
        return None


def process_csv(input_file: str) -> dict[str, list[dict]]:
    """Process CSV file and return towers grouped by state."""
    state_towers: dict[str, list[dict]] = defaultdict(list)

    total_rows = 0
    processed = 0
    skipped_non_us = 0
    skipped_invalid = 0
    skipped_no_state = 0

    print(f"Processing {input_file}...")

    # OpenCelliD CSV format (no header in downloaded files)
    fieldnames = ['radio', 'mcc', 'net', 'area', 'cell', 'unit', 'lon', 'lat',
                  'range', 'samples', 'changeable', 'created', 'updated', 'averageSignal']

    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, fieldnames=fieldnames)

        for row in reader:
            total_rows += 1

            if total_rows % 100000 == 0:
                print(f"  Processed {total_rows:,} rows...")

            tower = parse_csv_row(row)

            if tower is None:
                skipped_invalid += 1
                continue

            state = get_state_for_coords(tower['lon'], tower['lat'])

            if state is None:
                skipped_no_state += 1
                continue

            state_towers[state].append(tower)
            processed += 1

    print(f"\nProcessing complete:")
    print(f"  Total rows: {total_rows:,}")
    print(f"  Processed: {processed:,}")
    print(f"  Skipped (invalid): {skipped_invalid:,}")
    print(f"  Skipped (outside US states): {skipped_no_state:,}")
    print(f"  States with data: {len(state_towers)}")

    return state_towers


def write_state_zip(state_code: str, towers: list[dict], output_dir: str) -> None:
    """Write a state's cell tower data to a ZIP file."""
    state_dir = Path(output_dir) / state_code
    state_dir.mkdir(parents=True, exist_ok=True)

    zip_path = state_dir / 'cell.zip'

    # Build data.json content
    data = {
        'version': datetime.now(timezone.utc).strftime('%Y-%m'),
        'source': 'OpenCelliD',
        'attribution': 'Data from OpenCelliD (CC-BY-SA 4.0)',
        'towers': towers,
        'types': RADIO_TYPES,
    }

    # Build version.json content
    version = {
        'version': datetime.now(timezone.utc).strftime('%Y-%m'),
        'source': 'OpenCelliD',
        'record_count': len(towers),
        'generated_at': datetime.now(timezone.utc).isoformat(),
    }

    # Write ZIP file
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.writestr('data.json', json.dumps(data, separators=(',', ':')))
        zf.writestr('version.json', json.dumps(version, indent=2))

    file_size = zip_path.stat().st_size
    print(f"  {state_code}: {len(towers):,} towers ({file_size / 1024:.1f} KB)")


def main():
    parser = argparse.ArgumentParser(
        description='Process OpenCelliD data into state-level ZIP files'
    )
    parser.add_argument('input_csv', help='Input CSV file from OpenCelliD')
    parser.add_argument('output_dir', help='Output directory for state ZIPs')
    parser.add_argument('--state', help='Process only a specific state (e.g., WY)')

    args = parser.parse_args()

    if not os.path.exists(args.input_csv):
        print(f"Error: Input file not found: {args.input_csv}")
        sys.exit(1)

    # Process CSV
    state_towers = process_csv(args.input_csv)

    # Filter to specific state if requested
    if args.state:
        state_code = args.state.upper()
        if state_code not in state_towers:
            print(f"Error: No data found for state {state_code}")
            sys.exit(1)
        state_towers = {state_code: state_towers[state_code]}

    # Write output files
    print(f"\nWriting ZIP files to {args.output_dir}...")

    for state_code in sorted(state_towers.keys()):
        towers = state_towers[state_code]
        if towers:
            write_state_zip(state_code, towers, args.output_dir)

    print(f"\nDone! Created {len(state_towers)} state ZIP files.")


if __name__ == '__main__':
    main()
