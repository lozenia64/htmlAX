# 구현 노트 — f66a6994

## 변경 요약

### index.html 플레이어
- **지연 로딩**: 카드 클릭 시 `src` 미설정 → 재생/시크 시에만 `pendingSrc` 연결
- **`seekToTime()`**: 메타데이터 로드 후 `currentTime` 설정, `seeked` 이벤트로 UI 동기화
- **시크 바**: `change` 시점에만 실제 seek (드래그 중 UI만 갱신)
- **챕터 클릭**: `seekToTime(time, true)` 통합 경로

### prepare_videos.sh (신규)
- 로컬 PC에서 `ffmpeg -movflags +faststart` 로 moov atom을 파일 앞으로 이동
- .mov 파일이 시크 시 전체 다운로드되는 근본 원인 해소

## 수용 기준 매핑

- [x] 플레이어 진입 시 영상 다운로드 없음
- [x] 재생 클릭 시 점진적 로드 (faststart 영상 기준)
- [x] 1:00 시크 시 0:00 리셋 없이 해당 위치로 이동

## 미해결 / 리스크

- faststart 미적용 .mov는 브라우저가 메타데이터 위해 대용량 다운로드할 수 있음 → `prepare_videos.sh` 필수
