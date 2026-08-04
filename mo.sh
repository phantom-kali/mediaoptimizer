#!/bin/bash

# Web Media Optimizer for Linux
# Compress images and videos for web use with lossy compression
# Supports: JPG, PNG, WebP, GIF, MP4, MOV, AVI, MKV, WebM

set -e

# Default settings
IMAGE_QUALITY=85
VIDEO_CRF=23
MAX_WIDTH=1920
OUTPUT_DIR="optimized"
RECURSIVE=0
CONVERT_TO_WEBP=0
VIDEO_PRESET="medium"

usage() {
    cat << EOF
Web Media Optimizer

Usage: $0 [OPTIONS] <file_or_directory>

OPTIONS:
    -q, --quality NUM       Image quality (1-100, default: 85)
    -c, --crf NUM          Video CRF quality (0-51, lower=better, default: 23)
    -w, --max-width NUM    Maximum width in pixels (default: 1920)
    -o, --output DIR       Output directory (default: optimized)
    -r, --recursive        Process directories recursively
    --webp                 Convert images to WebP format
    --preset PRESET        Video encoding preset (default: medium)
    -h, --help            Display this help message

EXAMPLES:
    $0 image.jpg
    $0 -r ./images
    $0 -q 90 --webp -r ./media
    $0 -c 20 --preset slow video.mp4

INSTALLATION (Fedora):
    sudo dnf install imagemagick jpegoptim optipng ffmpeg
EOF
    exit 0
}

check_dependencies() {
    local missing_tools=()
    command -v convert &> /dev/null || missing_tools+=("imagemagick")
    command -v jpegoptim &> /dev/null || missing_tools+=("jpegoptim")
    command -v optipng &> /dev/null || missing_tools+=("optipng")
    command -v ffmpeg &> /dev/null || missing_tools+=("ffmpeg")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "ERROR: Missing tools: ${missing_tools[*]}"
        echo "Install: sudo dnf install ${missing_tools[*]}"
        exit 1
    fi
}

get_file_size() { du -h "$1" | cut -f1; }

calc_compression() {
    local orig=$(stat -c%s "$1")
    local comp=$(stat -c%s "$2")
    echo $(((orig - comp) * 100 / orig))
}

optimize_jpeg() {
    echo "[JPEG] $(basename "$1")"
    convert "$1" -resize "${MAX_WIDTH}x>" -quality ${IMAGE_QUALITY} -strip "$2"
    jpegoptim --max=${IMAGE_QUALITY} --strip-all "$2" &> /dev/null
}

optimize_png() {
    echo "[PNG] $(basename "$1")"
    convert "$1" -resize "${MAX_WIDTH}x>" -strip "$2"
    optipng -o2 -strip all "$2" &> /dev/null
}

convert_webp() {
    echo "[WebP] $(basename "$1")"
    convert "$1" -resize "${MAX_WIDTH}x>" -quality ${IMAGE_QUALITY} -define webp:method=6 "$2"
}

optimize_gif() {
    echo "[GIF] $(basename "$1")"
    convert "$1" -resize "${MAX_WIDTH}x>" -layers Optimize -strip "$2"
}

optimize_video() {
    echo "[VIDEO] $(basename "$1") - may take a while..."
    local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$1" 2>/dev/null)
    local scale=""
    [ "$width" -gt "$MAX_WIDTH" ] 2>/dev/null && scale="-vf scale=${MAX_WIDTH}:-2"
    ffmpeg -i "$1" -c:v libx264 -crf ${VIDEO_CRF} -preset ${VIDEO_PRESET} ${scale} \
        -c:a aac -b:a 128k -movflags +faststart -y "$2" 2>&1 | grep -v "frame=" || true
}

process_file() {
    local input="$1"
    local base=$(basename "$input")
    local ext="${base##*.}"
    local name="${base%.*}"
    
    mkdir -p "$OUTPUT_DIR"
    local orig_size=$(get_file_size "$input")
    local output=""
    
    case "${ext,,}" in
        jpg|jpeg)
            [ $CONVERT_TO_WEBP -eq 1 ] && output="$OUTPUT_DIR/${name}.webp" || output="$OUTPUT_DIR/$base"
            [ $CONVERT_TO_WEBP -eq 1 ] && convert_webp "$input" "$output" || optimize_jpeg "$input" "$output"
            ;;
        png)
            [ $CONVERT_TO_WEBP -eq 1 ] && output="$OUTPUT_DIR/${name}.webp" || output="$OUTPUT_DIR/$base"
            [ $CONVERT_TO_WEBP -eq 1 ] && convert_webp "$input" "$output" || optimize_png "$input" "$output"
            ;;
        webp)
            output="$OUTPUT_DIR/$base"
            convert_webp "$input" "$output"
            ;;
        gif)
            output="$OUTPUT_DIR/$base"
            optimize_gif "$input" "$output"
            ;;
        mp4|mov|avi|mkv|webm)
            output="$OUTPUT_DIR/${name}.mp4"
            optimize_video "$input" "$output"
            ;;
        *)
            echo "SKIP: $base"
            return
            ;;
    esac
    
    local new_size=$(get_file_size "$output")
    local pct=$(calc_compression "$input" "$output")
    echo "✓ $base: $orig_size → $new_size (${pct}% smaller)"
    echo ""
}

process_directory() {
    if [ $RECURSIVE -eq 1 ]; then
        find "$1" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
            -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.mov" \
            -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.webm" \) | \
            while read f; do process_file "$f"; done
    else
        for f in "$1"/*.{jpg,jpeg,png,webp,gif,mp4,mov,avi,mkv,webm} 2>/dev/null; do
            [ -f "$f" ] && process_file "$f"
        done
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quality) IMAGE_QUALITY="$2"; shift 2 ;;
        -c|--crf) VIDEO_CRF="$2"; shift 2 ;;
        -w|--max-width) MAX_WIDTH="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -r|--recursive) RECURSIVE=1; shift ;;
        --webp) CONVERT_TO_WEBP=1; shift ;;
        --preset) VIDEO_PRESET="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) INPUT_PATH="$1"; shift ;;
    esac
done

echo ""
echo "===== Web Media Optimizer ====="
echo ""

[ -z "$INPUT_PATH" ] && { echo "ERROR: No input specified"; usage; }

check_dependencies

echo "Settings: Quality=$IMAGE_QUALITY, CRF=$VIDEO_CRF, MaxWidth=${MAX_WIDTH}px, Output=$OUTPUT_DIR"
echo ""

if [ -f "$INPUT_PATH" ]; then
    process_file "$INPUT_PATH"
elif [ -d "$INPUT_PATH" ]; then
    process_directory "$INPUT_PATH"
else
    echo "ERROR: Path not found: $INPUT_PATH"
    exit 1
fi

echo ""
echo "✓ Complete! Files in: $OUTPUT_DIR/"
echo ""
