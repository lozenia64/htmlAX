#!/usr/bin/env bash
# scan_videos.sh — index.html에 VIDEOS·CHAPTERS·THUMBNAILS 배열 주입
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML="$SCRIPT_DIR/ax.html"
VIDEOS_MARKER='// __VIDEOS_JSON__'
CHAPTERS_MARKER='// __CHAPTERS_JSON__'
THUMBNAILS_MARKER='// __THUMBNAILS_JSON__'
POSTERS_MARKER='// __POSTERS_JSON__'
THUMBS_DIR="$SCRIPT_DIR/thumbs"
POSTERS_DIR="$SCRIPT_DIR/posters"
MP4_DIR="$SCRIPT_DIR/mp4"
PDF_DIR="$SCRIPT_DIR/pdf"
VIDEOS_CSV="$SCRIPT_DIR/videos.csv"
ENGLISH_VIDEO_RE='^[A-Za-z0-9._-]+\.(mp4|webm|ogg|mov)$'

json_escape() {
  local s=$1 out='' i c
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      \\) out+='\\' ;;
      \") out+='\"' ;;
      *) out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

script_safe_json() {
  printf '%s' "$1" | sed 's|</|<\\/|g' | sed 's|<!--|<\\!--|g'
}

inject_between_markers() {
  local marker=$1
  local payload=$2
  local payload_file html_tmp

  if ! grep -qF "$marker" "$HTML"; then
    printf 'HTML에 마커 %s 가 없습니다.\n' "$marker" >&2
    exit 1
  fi

  payload_file=$(mktemp)
  html_tmp=$(mktemp)
  printf '%s\n' "$payload" >"$payload_file"

  awk -v marker="$marker" -v pfile="$payload_file" '
BEGIN {
  while ((getline payload < pfile) > 0) {
  }
  close(pfile)
  in_block = 0
}
index($0, marker) > 0 {
  if (!in_block) {
    print
    print payload
    in_block = 1
    next
  }
  print
  in_block = 0
  next
}
!in_block {
  print
}
' "$HTML" >"$html_tmp"

  mv "$html_tmp" "$HTML"
  rm -f "$payload_file"
}

parse_time_to_seconds() {
  local t=${1// /}
  if [[ "$t" =~ ^[0-9]+$ ]]; then
    printf '%s' "$t"
    return 0
  fi
  local IFS=':'
  local -a parts=()
  read -ra parts <<<"$t"
  local n=${#parts[@]}
  if ((n == 2)); then
    printf '%s' $((10#${parts[0]} * 60 + 10#${parts[1]}))
  elif ((n == 3)); then
    printf '%s' $((10#${parts[0]} * 3600 + 10#${parts[1]} * 60 + 10#${parts[2]}))
  else
    printf '0'
  fi
}

strip_extension() {
  local name=$1
  printf '%s' "${name%.*}"
}

# video_files[i] = mp4/… path; video_titles[i] = Korean title; video_pdfs[i] = pdf/… or empty
video_files=()
video_titles=()
video_pdfs=()
video_pdf_pages=()

pdf_pages_for() {
  local f=$1
  if command -v pdfinfo >/dev/null 2>&1 && [[ -f "$f" ]]; then
    pdfinfo "$f" 2>/dev/null | awk '/^Pages:/ {print $2; exit}'
  fi
}

resolve_pdf_for_video() {
  local file=$1 pdf_name=$2
  local base pdf_path pages
  base=$(strip_extension "$(basename "$file")")
  if [[ -n "$pdf_name" ]]; then
    pdf_path="$PDF_DIR/$pdf_name"
  elif [[ -f "$PDF_DIR/${base}.pdf" ]]; then
    pdf_path="$PDF_DIR/${base}.pdf"
  else
    video_pdfs+=("")
    video_pdf_pages+=("")
    return 0
  fi
  if [[ ! -f "$pdf_path" ]]; then
    printf 'videos.csv: PDF가 없습니다 — %s\n' "$pdf_name" >&2
    exit 1
  fi
  pages=$(pdf_pages_for "$pdf_path")
  video_pdfs+=("pdf/$(basename "$pdf_path")")
  video_pdf_pages+=("${pages:-}")
}

load_videos_from_csv() {
  local csv=$1 line file title pdf_name
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line//$'\r'/}
    [[ -z "$line" ]] && continue
    [[ "$line" == file,* ]] && continue
    IFS=',' read -r file title pdf_name <<<"$line"
    file=${file#"${file%%[![:space:]]*}"}
    file=${file%"${file##*[![:space:]]}"}
    title=${title#"${title%%[![:space:]]*}"}
    title=${title%"${title##*[![:space:]]}"}
    pdf_name=${pdf_name#"${pdf_name%%[![:space:]]*}"}
    pdf_name=${pdf_name%"${pdf_name##*[![:space:]]}"}
    [[ -z "$file" || -z "$title" ]] && continue
    file=$(basename "$file")
    local rel="mp4/$file"
    if [[ ! -f "$MP4_DIR/$file" ]]; then
      printf 'videos.csv: mp4/ 에 파일이 없습니다 — %s\n' "$file" >&2
      exit 1
    fi
    video_files+=("$rel")
    video_titles+=("$title")
    resolve_pdf_for_video "$file" "$pdf_name"
  done <"$csv"
}

load_videos_from_scan() {
  local f base ext ext_lower
  mkdir -p "$MP4_DIR"
  for f in "$MP4_DIR"/*; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f")
    ext=${base##*.}
    ext_lower=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    case "$ext_lower" in
      mp4|webm|ogg|mov)
        if [[ "$base" =~ $ENGLISH_VIDEO_RE ]]; then
          video_files+=("mp4/$base")
          video_titles+=("$(strip_extension "$base")")
          resolve_pdf_for_video "$base" ""
        fi
        ;;
    esac
  done
  if ((${#video_files[@]} > 1)); then
  local i j tmp_file tmp_title
  for ((i = 0; i < ${#video_files[@]} - 1; i++)); do
    for ((j = i + 1; j < ${#video_files[@]}; j++)); do
      if [[ "${video_files[$i]}" > "${video_files[$j]}" ]]; then
        tmp_file=${video_files[$i]}
        video_files[$i]=${video_files[$j]}
        video_files[$j]=$tmp_file
        tmp_title=${video_titles[$i]}
        video_titles[$i]=${video_titles[$j]}
        video_titles[$j]=$tmp_title
      fi
    done
  done
  fi
}

resolve_video_name() {
  local csv_name=$1
  local i base

  for i in "${!video_titles[@]}"; do
    if [[ "${video_titles[$i]}" == "$csv_name" ]]; then
      printf '%s' "${video_files[$i]}"
      return 0
    fi
  done

  for i in "${!video_files[@]}"; do
    if [[ "${video_files[$i]}" == "$csv_name" ]]; then
      printf '%s' "${video_files[$i]}"
      return 0
    fi
    base=$(strip_extension "$(basename "${video_files[$i]}")")
    if [[ "$base" == "$csv_name" || "mp4/$base" == "$csv_name" ]]; then
      printf '%s' "${video_files[$i]}"
      return 0
    fi
  done

  printf '%s' "$csv_name"
}

build_chapters_json() {
  local csv=$1
  local entries_file current_video json='{' first_video=true

  entries_file=$(mktemp)
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line//$'\r'/}
    [[ -z "$line" ]] && continue
    [[ "$line" == video,* ]] && continue
    local video time label
    IFS=',' read -r video time label <<<"$line"
    video=${video#"${video%%[![:space:]]*}"}
    video=${video%"${video##*[![:space:]]}"}
    time=${time#"${time%%[![:space:]]*}"}
    time=${time%"${time##*[![:space:]]}"}
    label=${label#"${label%%[![:space:]]*}"}
    label=${label%"${label##*[![:space:]]}"}
    [[ -z "$video" || -z "$time" || -z "$label" ]] && continue
    video=$(resolve_video_name "$video")
    local secs
    secs=$(parse_time_to_seconds "$time")
    printf '%s\t%s\t%s\n' "$video" "$secs" "$label"
  done <"$csv" | sort -t$'\t' -k1,1 -k2,2n >"$entries_file"

  current_video=''
  while IFS=$'\t' read -r video secs label || [[ -n "${video:-}" ]]; do
    [[ -z "${video:-}" ]] && continue
    if [[ "$video" != "$current_video" ]]; then
      if [[ -n "$current_video" ]]; then
        json+=']'
        first_video=false
      fi
      if $first_video; then first_video=false; else json+=','; fi
      local esc_video
      esc_video=$(json_escape "$video")
      json+="\"$esc_video\":["
      current_video=$video
      local first_chapter=true
    fi
    local esc_label
    esc_label=$(json_escape "$label")
    if [[ "${first_chapter:-true}" == true ]]; then
      first_chapter=false
    else
      json+=','
    fi
    json+="{\"time\":${secs},\"label\":\"$esc_label\"}"
  done <"$entries_file"

  if [[ -n "$current_video" ]]; then
    json+=']'
  fi
  json+='}'

  rm -f "$entries_file"
  printf '%s' "$json"
}

if [[ -f "$VIDEOS_CSV" ]]; then
  load_videos_from_csv "$VIDEOS_CSV"
else
  load_videos_from_scan
fi

# Build VIDEOS JSON array of {file, title, pdf?, pdfPages?} objects
videos_json='['
first=true
for i in "${!video_files[@]}"; do
  local_file=${video_files[$i]}
  local_title=${video_titles[$i]}
  esc_file=$(json_escape "$local_file")
  esc_title=$(json_escape "$local_title")
  if $first; then first=false; else videos_json+=','; fi
  videos_json+="{\"file\":\"$esc_file\",\"title\":\"$esc_title\""
  if [[ -n "${video_pdfs[$i]:-}" ]]; then
    esc_pdf=$(json_escape "${video_pdfs[$i]}")
    videos_json+=",\"pdf\":\"$esc_pdf\""
    if [[ -n "${video_pdf_pages[$i]:-}" ]]; then
      videos_json+=",\"pdfPages\":${video_pdf_pages[$i]}"
    fi
  fi
  videos_json+='}'
done
videos_json+=']'

safe_videos_json=$(script_safe_json "$videos_json")
videos_payload="const VIDEOS = ${safe_videos_json};"
inject_between_markers "$VIDEOS_MARKER" "$videos_payload"

# Build CHAPTERS JSON object (optional chapters.csv), keyed by English file name
CHAPTERS_CSV="$SCRIPT_DIR/chapters.csv"
if [[ -f "$CHAPTERS_CSV" ]]; then
  chapters_json=$(build_chapters_json "$CHAPTERS_CSV")
else
  chapters_json='{}'
fi

safe_chapters_json=$(script_safe_json "$chapters_json")
chapters_payload="const CHAPTERS = ${safe_chapters_json};"
inject_between_markers "$CHAPTERS_MARKER" "$chapters_payload"

# Build THUMBNAILS (dashboard, max 640px) and POSTERS (native resolution for player)
mkdir -p "$THUMBS_DIR" "$POSTERS_DIR"
has_ffmpeg=false
if command -v ffmpeg >/dev/null 2>&1; then
  has_ffmpeg=true
fi

thumbnails_json='{'
posters_json='{'
first_thumb=true
first_poster=true
for v in "${video_files[@]}"; do
  thumb_rel=''
  poster_rel=''
  base_name="$(strip_extension "$(basename "$v")")"
  thumb_name="${base_name}.jpg"
  if $has_ffmpeg; then
    thumb_path="$THUMBS_DIR/$thumb_name"
    poster_path="$POSTERS_DIR/$thumb_name"
    video_path="$SCRIPT_DIR/$v"
    if [[ -f "$video_path" ]]; then
      ffmpeg -y -ss 1 -i "$video_path" -vf "scale='min(640,iw)':-2" -frames:v 1 -q:v 6 \
        "$thumb_path" 2>/dev/null || true
      ffmpeg -y -ss 1 -i "$video_path" -frames:v 1 -q:v 2 \
        "$poster_path" 2>/dev/null || true
      if [[ -f "$thumb_path" ]]; then
        thumb_rel="thumbs/$thumb_name"
      fi
      if [[ -f "$poster_path" ]]; then
        poster_rel="posters/$thumb_name"
      fi
    fi
  else
    if [[ -f "$THUMBS_DIR/$thumb_name" ]]; then
      thumb_rel="thumbs/$thumb_name"
    fi
    if [[ -f "$POSTERS_DIR/$thumb_name" ]]; then
      poster_rel="posters/$thumb_name"
    fi
  fi
  if [[ -n "$thumb_rel" || -n "$poster_rel" ]]; then
    esc_v=$(json_escape "$v")
    if [[ -n "$thumb_rel" ]]; then
      esc_thumb=$(json_escape "$thumb_rel")
      if $first_thumb; then first_thumb=false; else thumbnails_json+=','; fi
      thumbnails_json+="\"$esc_v\":\"$esc_thumb\""
    fi
    if [[ -n "$poster_rel" ]]; then
      esc_poster=$(json_escape "$poster_rel")
      if $first_poster; then first_poster=false; else posters_json+=','; fi
      posters_json+="\"$esc_v\":\"$esc_poster\""
    fi
  fi
done
thumbnails_json+='}'
posters_json+='}'

safe_thumbnails_json=$(script_safe_json "$thumbnails_json")
thumbnails_payload="const THUMBNAILS = ${safe_thumbnails_json};"
inject_between_markers "$THUMBNAILS_MARKER" "$thumbnails_payload"

safe_posters_json=$(script_safe_json "$posters_json")
posters_payload="const POSTERS = ${safe_posters_json};"
inject_between_markers "$POSTERS_MARKER" "$posters_payload"

thumb_count=0
if [[ "$thumbnails_json" != '{}' ]]; then
  thumb_count=$(printf '%s' "$thumbnails_json" | grep -o '"thumbs/' | wc -l | tr -d ' ')
fi

poster_count=0
if [[ "$posters_json" != '{}' ]]; then
  poster_count=$(printf '%s' "$posters_json" | grep -o '"posters/' | wc -l | tr -d ' ')
fi

chapter_count=0
if [[ -f "$CHAPTERS_CSV" ]]; then
  chapter_count=$(tail -n +2 "$CHAPTERS_CSV" | grep -c . || true)
fi

printf 'Updated %s with %d video(s), %d thumbnail(s), %d poster(s), and %d chapter row(s)\n' \
  "$HTML" "${#video_files[@]}" "$thumb_count" "$poster_count" "$chapter_count"
