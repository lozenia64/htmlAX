## 변경 요약
- `scan_videos.sh`: `thumbs/` 디렉터리 생성, ffmpeg로 각 영상 1초 지점 JPEG 썸네일 생성, `THUMBNAILS` JSON을 `index.html`에 주입. ffmpeg 미설치 시 빈 객체 주입. `normalize_for_match`의 python3 의존성 제거(파일명 그대로 비교).
- `index.html`: canvas/video 기반 `thumbs.capture()` 모듈 전체 삭제. 카드는 `THUMBNAILS` 맵의 정적 `<img loading="lazy">` 사용, 없으면 SVG 플레이스홀더.
- `index.html` 플레이어: `preload="none"`, `showPlayer`에서 `src`만 설정(`load()` 호출 없음), 첫 재생 클릭 시에만 스트리밍 시작·`loadedmetadata`까지 로딩 표시. `showDashboard`에서 `src` 제거로 버퍼 해제.
- PC 전용: safe-area CSS 제거, 1024px 미만 화면에 안내 배너 추가.
- 로컬 실행: ffmpeg 설치 후 `./scan_videos.sh` — 1개 `.mov`에 대해 `thumbs/*.jpg` 1장 생성 및 `THUMBNAILS` 주입 확인.

## 수용 기준 매핑
- [x] 페이지 로드 시 영상 전체 다운로드 없음 → 정적 JPEG 썸네일만 로드, 숨김 `<video>` 제거
- [x] 카드 클릭 시 즉시 재생/버퍼링 없음 → 플레이어 화면만 전환, 재생 버튼 클릭 시 스트리밍
- [x] `scan_videos.sh`가 썸네일 생성·`THUMBNAILS` 주입
- [x] python3 의존성 제거
- [x] PC 전용 UI 힌트

## 미해결 / 리스크
- 서버에 **ffmpeg 1회 설치** 후 `./scan_videos.sh` 실행 필요(신규 영상 추가·갱신 시마다).
- 현재 워크스페이스에는 `.mov` 1개만 존재(요청의 6개 중). 서버에 6개가 있으면 스캔 시 6장 생성됨.
- 폴더 선택(로컬 picker) 모드는 정적 썸네일 없이 플레이스홀더만 표시(의도된 동작).
