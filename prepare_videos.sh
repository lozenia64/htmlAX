#!/usr/bin/env bash
# prepare_videos.sh — moov atom을 파일 앞으로 이동 (faststart). **재인코딩 없음** (-c copy)
#
# 하는 일:
#   1. moov atom(재생 정보)을 파일 맨 앞으로 이동 (faststart)
#      → 브라우저가 처음 몇 KB만 받고 길이·시크 정보를 파악
#   2. .mov → .mp4 로 리먹스 (코덱·화질 변경 없이 컨테이너만 변환)
#   3. 결과물을 mp4/ 폴더에 저장
#
# 화질: -c copy 는 비트스트림을 그대로 복사합니다. 화질 저하가 발생하지 않습니다.
# 서버에 ffmpeg 없어도 됨. 로컬에서 1회 실행 후 mp4/ 를 업로드하세요.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
MP4_DIR="$SCRIPT_DIR/mp4"
VIDEOS_CSV="$SCRIPT_DIR/videos.csv"

if ! command -v ffmpeg >/dev/null 2>&1; then
  printf 'ffmpeg가 필요합니다. macOS: brew install ffmpeg\n' >&2
  exit 1
fi

mkdir -p "$MP4_DIR"
shopt -s nullglob
count=0

process_file() {
  local f=$1
  [[ -f "$f" ]] || return 0
  local ext base out tmp
  ext="${f##*.}"
  base="$(basename "${f%.*}")"
  out="$MP4_DIR/${base}.mp4"
  tmp=$(mktemp "${MP4_DIR}/${base}.faststart.XXXXXX.mp4")

  printf 'Processing: %s → %s\n' "$f" "$out"
  if ! ffmpeg -y -i "$f" -c copy -movflags +faststart "$tmp"; then
    rm -f "$tmp"
    printf '실패: %s\n' "$f" >&2
    exit 1
  fi
  mv "$tmp" "$out"

  if [[ "$f" != "$out" && -f "$f" ]]; then
    rm -f "$f"
    printf '  원본 삭제: %s\n' "$f"
  fi

  if [[ -f "$VIDEOS_CSV" ]] && grep -qF "${base}.${ext}" "$VIDEOS_CSV"; then
    sed -i '' "s|${base}\.${ext}|${base}.mp4|g" "$VIDEOS_CSV"
    printf '  videos.csv 갱신: %s → %s\n' "${base}.${ext}" "${base}.mp4"
  fi

  count=$((count + 1))
  printf '완료: %s\n' "$out"
}

for f in "$MP4_DIR"/*.{mov,mp4,webm,ogg}; do
  process_file "$f"
done

for f in "$SCRIPT_DIR"/*.{mov,mp4,webm,ogg}; do
  process_file "$f"
done

if ((count == 0)); then
  printf '처리할 영상 파일이 없습니다. mp4/ 또는 프로젝트 루트에 영상을 넣으세요.\n' >&2
  exit 1
fi

printf '\nDone. %d file(s) optimized in mp4/.\n' "$count"
printf '이후 ./scan_videos.sh 를 실행하세요.\n'
