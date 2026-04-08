# kafkio-download-splitter

Helper script to download the official KafkIO Windows portable ZIP from the vendor site, split it into 20 MB chunks, and rename each chunk to `.png`.

This repo does **not** redistribute the KafkIO binary. It only automates downloading it from the official source and splitting the local copy.

## What it does

- downloads the ZIP from `kafkio.com`
- optionally writes a SHA256 file using the local `sha256sum` tool
- splits the ZIP into 20 MB chunks
- renames each chunk to `.png`
- writes a small reconstruction script

## Usage

```bash
chmod +x split_kafkio.sh
./split_kafkio.sh
```

## Push split parts to this repo

There is also a generic helper that:

- downloads any file from a URL
- splits it into parts of up to 20 MB
- renames each part to `.png`
- commits and pushes the parts into this git repo

```bash
chmod +x download_split_and_push.sh
./download_split_and_push.sh "https://example.com/file.zip"
```

Custom usage:

```bash
./download_split_and_push.sh \
  "https://example.com/file.zip" \
  . \
  20 \
  main \
  origin
```

Arguments:

1. download URL
2. repo directory
3. chunk size in MB
4. branch
5. remote name

Custom usage:

```bash
./split_kafkio.sh \
  "https://kafkio.com/download/kafkio/2.1.15/KafkIO-win-2.1.15-x64.zip" \
  output \
  20 \
  KafkIO-win-2.1.15-x64.zip
```

Arguments:

1. download URL
2. output directory
3. chunk size in MB
4. output filename

## Reconstruct the ZIP

After you have all `.png` parts in `parts/`:

```bash
cd output
./reconstruct.sh parts KafkIO-win-2.1.15-x64.zip
```

Or manually:

```bash
cat parts/*.png > KafkIO-win-2.1.15-x64.zip
```

## Notes

- The `.png` extension is only a rename of raw binary chunks.
- Chunk order depends on the numeric filenames created by `split`.
- Verify checksums against the official vendor page when possible.
