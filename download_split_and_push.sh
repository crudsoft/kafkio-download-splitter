#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./download_split_and_push.sh <url> [repo_dir] [chunk_mb] [branch] [remote]
#
# Example:
#   ./download_split_and_push.sh \
#     "https://example.com/file.zip" \
#     . \
#     20 \
#     main \
#     origin

URL="${1:-}"
REPO_DIR="${2:-.}"
CHUNK_MB="${3:-20}"
BRANCH="${4:-main}"
REMOTE="${5:-origin}"

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <url> [repo_dir] [chunk_mb] [branch] [remote]" >&2
  exit 1
fi

for cmd in curl split git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if ! [[ "$CHUNK_MB" =~ ^[0-9]+$ ]] || [[ "$CHUNK_MB" -le 0 ]]; then
  echo "chunk_mb must be a positive integer" >&2
  exit 1
fi

REPO_DIR="$(cd "$REPO_DIR" && pwd)"
cd "$REPO_DIR"

if [[ ! -d .git ]]; then
  echo "repo_dir is not a git repository: $REPO_DIR" >&2
  exit 1
fi

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "git remote '$REMOTE' does not exist" >&2
  exit 1
fi

filename_from_url() {
  local url="$1"
  local path
  path="$(printf '%s' "$url" | sed 's/[?#].*$//')"
  basename "$path"
}

safe_slug() {
  local s="$1"
  s="${s,,}"
  s="$(printf '%s' "$s" | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  printf '%s' "${s:-download}"
}

ORIGINAL_NAME="$(filename_from_url "$URL")"
if [[ -z "$ORIGINAL_NAME" || "$ORIGINAL_NAME" == "/" || "$ORIGINAL_NAME" == "." ]]; then
  ORIGINAL_NAME="download.bin"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
SLUG="$(safe_slug "$ORIGINAL_NAME")"
WORK_DIR="artifacts/${SLUG}-${STAMP}"
PARTS_DIR="${WORK_DIR}/parts"
META_DIR="${WORK_DIR}/meta"
DOWNLOADED_FILE="${WORK_DIR}/${ORIGINAL_NAME}"
PART_PREFIX="${PARTS_DIR}/${SLUG}.part-"

mkdir -p "$PARTS_DIR" "$META_DIR"

echo "Downloading: $URL"
curl -L --fail --show-error --output "$DOWNLOADED_FILE" "$URL"

FILE_SIZE="$(wc -c < "$DOWNLOADED_FILE" | tr -d ' ')"
PART_BYTES=$((CHUNK_MB * 1024 * 1024))

{
  echo "url=$URL"
  echo "original_name=$ORIGINAL_NAME"
  echo "slug=$SLUG"
  echo "downloaded_at=$STAMP"
  echo "chunk_mb=$CHUNK_MB"
  echo "file_size_bytes=$FILE_SIZE"
} > "${META_DIR}/info.txt"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$DOWNLOADED_FILE" | tee "${META_DIR}/sha256.txt"
fi

split -b "$PART_BYTES" -d -a 4 "$DOWNLOADED_FILE" "$PART_PREFIX"

part_count=0
for f in "${PART_PREFIX}"*; do
  [[ -e "$f" ]] || continue
  mv "$f" "${f}.png"
  part_count=$((part_count + 1))
done

cat > "${META_DIR}/reconstruct.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TARGET_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PARTS_DIR="${1:-$TARGET_DIR/parts}"
OUT_NAME="${2:-reconstructed.bin}"
cat "$PARTS_DIR"/*.png > "$TARGET_DIR/$OUT_NAME"
echo "Reconstructed: $TARGET_DIR/$OUT_NAME"
EOF
chmod +x "${META_DIR}/reconstruct.sh"

cat > "${WORK_DIR}/README.txt" <<EOF
Original URL: $URL
Original filename: $ORIGINAL_NAME
Downloaded at: $STAMP
Chunk size: ${CHUNK_MB} MB
Parts created: $part_count

Reconstruct:
  cd ${META_DIR}
  ./reconstruct.sh ../parts "$ORIGINAL_NAME"
EOF

rm -f "$DOWNLOADED_FILE"

git add "$WORK_DIR"
git commit -m "Add split upload for ${ORIGINAL_NAME} (${part_count} parts)"
git push "$REMOTE" "$BRANCH"

echo "Done. Uploaded ${part_count} parts to ${REMOTE}/${BRANCH} under ${WORK_DIR}"
