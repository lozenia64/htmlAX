# 구현 노트 — bcde60c7

## 변경 요약

### 원인 분석
1. **`video.load()`** — loadMetadata()에서 호출되어 브라우저가 영상 전체를 다시 받음 → **제거**
2. **`.mov` 포맷** — 서버 Range 스트리밍 호환성이 `.mp4`보다 낮음 → prepare 시 mp4 변환
3. **시크 실패** — 메타데이터 전 currentTime 설정 무시 → ensureReady 후 performSeek + seeked 이벤트

### ax.html 플레이어
- `ensureReady()`: `load()` 대신 **muted play()** 로 메타데이터만 Range 요청
- `performSeek()`: fastSeek / currentTime + seeked 후 재생
- `waiting` 이벤트: 버퍼링 중 로딩 표시

### prepare_videos.sh
- faststart + **.mp4 변환**, videos.csv 파일명 자동 갱신

### .htaccess
- Apache 서버용 Accept-Ranges 헤더

## prepare_videos.sh 역할 (사용자 FAQ)

영상 파일 내부의 **moov atom**(재생·시크에 필요한 인덱스)을 파일 **맨 앞**으로 옮깁니다.
moov가 끝에 있으면 브라우저가 시크·재생을 위해 **600MB 전체**를 받아야 합니다.
faststart 적용 후에는 **수 KB~수 MB**만으로 재생 시작 가능합니다.

## 수용 기준 매핑

- [x] load() 제거
- [x] 시크 시 seeked 기반 UI 동기화
- [ ] 서버 Accept-Ranges — .htaccess 배포 필요
