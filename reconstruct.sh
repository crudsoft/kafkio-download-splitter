#!/usr/bin/env bash
set -euo pipefail
PARTS_DIR="${1:-parts}"
OUTPUT_FILE="${2:-KafkIO-win-2.1.15-x64.zip}"
cat "${PARTS_DIR}"/*.png > "$OUTPUT_FILE"
echo "Reconstructed: $OUTPUT_FILE"
if command -v sha256sum >/dev/null 2>&1 && [ -f "$OUTPUT_FILE.sha256" ]; then
  sha256sum -c "$OUTPUT_FILE.sha256"
fi
