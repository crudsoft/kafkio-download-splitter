#!/usr/bin/env bash
set -euo pipefail

URL="${1:-https://kafkio.com/download/kafkio/2.1.15/KafkIO-win-2.1.15-x64.zip}"
OUTDIR="${2:-output}"
PART_MB="${3:-20}"
BASE_NAME="${4:-KafkIO-win-2.1.15-x64.zip}"

mkdir -p "$OUTDIR"
cd "$OUTDIR"

echo "Downloading: $URL"
curl -L --fail --output "$BASE_NAME" "$URL"

if command -v sha256sum >/dev/null 2>&1; then
  echo "SHA256:"
  sha256sum "$BASE_NAME" | tee "$BASE_NAME.sha256"
fi

part_bytes=$((PART_MB * 1024 * 1024))
mkdir -p parts
split -b "$part_bytes" -d -a 3 "$BASE_NAME" "parts/${BASE_NAME}.part-"

count=0
for f in parts/${BASE_NAME}.part-*; do
  new="${f}.png"
  mv "$f" "$new"
  count=$((count + 1))
done

echo "Created $count parts in $(pwd)/parts"

echo "Writing reconstruction helpers..."
cat > reconstruct.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PARTS_DIR="${1:-parts}"
OUTPUT_FILE="${2:-KafkIO-win-2.1.15-x64.zip}"
cat "${PARTS_DIR}"/*.png > "$OUTPUT_FILE"
echo "Reconstructed: $OUTPUT_FILE"
if command -v sha256sum >/dev/null 2>&1 && [ -f "$OUTPUT_FILE.sha256" ]; then
  sha256sum -c "$OUTPUT_FILE.sha256"
fi
EOF
chmod +x reconstruct.sh

echo "Done."
