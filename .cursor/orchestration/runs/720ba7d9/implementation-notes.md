## 변경 요약

B2B 고객사 솔루션 시연 영상 포털에 맞게 **대시보드 뷰**를 전면 리디자인했습니다. 플레이어·챕터·배속·폴더 선택 등 기존 JS 로직과 `VIDEOS` / `CHAPTERS` / `THUMBNAILS` 마커는 그대로 유지했습니다.

### 디자인 토큰
- 캔버스: `#FAFAFA` achromatic 배경
- 액센트: indigo `#4F46E5` (hover `#4338CA`, soft `#EEF2FF`)
- 배경: mesh radial gradient + 24px dot grid (CSS only)
- max-width: 1280px → **1400px** (hero + main 공통)

### 대시보드 구조
- **Hero 헤더** 추가: `솔루션 시연 영상` 제목, `제품 데모 영상을 선택하여 시청하세요` 부제
- **Stats strip**: 영상이 있을 때 `총 N개 솔루션` pill 배지 표시 (`dashboard.render()`에서 갱신)
- 페이지 `<title>` 동일 카피로 통일

### 카드 그리드
- `repeat(auto-fill, minmax(320px, 1fr))` — 뷰포트 너비를 채우는 반응형 그리드
- 카드: subtle border, hover 시 indigo tint shadow
- 썸네일: 하단 gradient scrim (`::after`), **시연** pill badge, hover 시 play overlay
- 제목: font-weight 700, tight letter-spacing

### 유지 항목
- empty state + 폴더 선택 fallback
- `loading="lazy"` 썸네일 img
- `scan_videos.sh` 호환 마커 (`// __VIDEOS_JSON__` 등)
- 플레이어 뷰 기능 (챕터, 배속, seek, 키보드 단축키)

### 플레이어 (경미)
- 동일 indigo 토큰·mesh 배경으로 시각 일관성만 맞춤

### 변경 파일
- `index.html` — CSS, 대시보드 HTML, stats strip JS (최소 추가)
