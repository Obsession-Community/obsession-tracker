#!/bin/bash
# Quick progress check for historical maps processing

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/historical_maps_workspace"
LOG_FILE="${BASE_DIR}/processing.log"
OUTPUT_DIR="${BASE_DIR}/output"
DOWNLOADS_DIR="${BASE_DIR}/downloads"

echo "=== Historical Maps Processing Status ==="
echo ""

# Check if still running
if pgrep -f "run-all-states.sh" > /dev/null; then
    echo "Status: RUNNING"
    PID=$(pgrep -f "run-all-states.sh")
    echo "PID: $PID"
else
    echo "Status: NOT RUNNING (completed or stopped)"
fi
echo ""

# Show current state being processed
echo "Last log entries:"
tail -10 "$LOG_FILE" 2>/dev/null || echo "No log file found"
echo ""

# Count completed states
echo "=== Completed States ==="
for state_dir in "$OUTPUT_DIR"/*/; do
    state=$(basename "$state_dir")
    quads_dir="${state_dir}maps/early_topo/quads"
    if [ -d "$quads_dir" ]; then
        count=$(find "$quads_dir" -name "*.mbtiles" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            size=$(du -sh "$quads_dir" 2>/dev/null | cut -f1)
            echo "  $state: $count quads ($size)"
        fi
    fi
done

echo ""
echo "=== Downloads Status ==="
for state_dir in "$DOWNLOADS_DIR"/*/; do
    state=$(basename "$state_dir")
    count=$(find "$state_dir" -name "*.tif" -o -name "*.TIF" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        echo "  $state: $count GeoTIFFs downloaded"
    fi
done

echo ""
total_quads=$(find "$OUTPUT_DIR" -name "*.mbtiles" 2>/dev/null | wc -l | tr -d ' ')
total_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
echo "Total: $total_quads quadrangles ($total_size)"
