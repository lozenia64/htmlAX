# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

"IT채널 AX과제 시연 영상" 대시보드 — 빌드 시스템·프레임워크·서버 코드가 없는 **순수 정적 사이트**입니다. 애플리케이션 전체(CSS + HTML + JavaScript)가 `ax.html` 단일 파일에 들어 있으며, ES5 스타일의 바닐라 JS(IIFE)로 작성되어 있습니다. 유일한 외부 라이브러리는 로컬에 번들된 `vendor/pdfjs/`(pdf.js)입니다. `index.html`과 `.htaccess`는 모두 `ax.html`로 리다이렉트하는 역할만 합니다.

## 자주 쓰는 명령어

빌드/린트/테스트는 없습니다. 정적 파일이므로 로컬 확인은 아무 정적 서버로 충분합니다:

```bash
python3 -m http.server 8000   # http://localhost:8000/ax.html
```

### 영상 추가·갱신 워크플로 (핵심 파이프라인)

```bash
# 1. 영상 파일을 mp4/ (또는 프로젝트 루트)에 넣는다 — mp4/는 gitignore 대상
./prepare_videos.sh   # ffmpeg 필요. moov atom faststart 이동 + .mov→.mp4 리먹스(-c copy, 재인코딩 없음)

# 2. videos.csv 에 행 추가: 한글명,영문명
#    - 한글명: 화면에 표시되는 과제 제목
#    - 영문명: mp4/·pdf/·thumbs/·posters/ 에서 파일을 찾는 공통 베이스명
#      (예: mcp-e2e-platform → mp4/mcp-e2e-platform.mp4, pdf/mcp-e2e-platform.pdf 자동 매칭)

# 3. (선택) pdf/<영문명>.pdf 배치, chapters.csv 에 챕터 행 추가 (video,time,label — video는 한글명, time은 m:ss)

# 4. ax.html 에 데이터 주입
./scan_videos.sh      # ffmpeg 있으면 thumbs/·posters/ 썸네일도 자동 생성, pdfinfo 있으면 pdfPages 계산
```

`scan_videos.sh`는 `ax.html` 안의 마커 주석(`// __VIDEOS_JSON__`, `// __CHAPTERS_JSON__`, `// __THUMBNAILS_JSON__`, `// __POSTERS_JSON__`) 사이에 `const VIDEOS / CHAPTERS / THUMBNAILS / POSTERS` 상수를 **직접 덮어써서 주입**합니다. 따라서:

- 이 상수들을 손으로 편집하지 말 것 — 다음 `scan_videos.sh` 실행 시 사라집니다. 데이터 수정은 `videos.csv` / `chapters.csv` / `pdf/` 파일로 하세요.
- 마커 주석 자체를 삭제하면 스크립트가 실패하므로 유지해야 합니다.
- `videos.csv`가 있으면 CSV 기준으로 목록을 만들고, 없으면 `mp4/` 폴더를 스캔해 영문 파일명 기준으로 목록을 만듭니다.

## 화면 구성 (2개 화면)

UI는 `ax.html` 안의 두 `<div class="view">`로만 구성되며, `is-active` 클래스 토글(+ View Transitions API)로 전환됩니다. PC 전용 화면입니다(1024px 미만이면 상단에 안내 배너 표시).

### 1. 대시보드 화면 (`#view-dashboard`)

시연 영상 카탈로그. 구성 요소:

- **스포트라이트 히어로** (`#spotlight`): 대표 영상 1개를 크게 노출. `featured: true` 영상 우선, 없으면 첫 번째 영상. 영상이 1개뿐이면 스포트라이트만 표시하고 카드 목록·툴바는 숨김.
- **카탈로그 툴바** (`#catalog-toolbar`): 검색 입력, 카테고리 칩 필터(카테고리 2개 이상일 때만), 정렬(기본순/제목순).
- **카드 목록**: 필터 없이 카테고리가 2개 이상이면 넷플릭스식 가로 레일(`#card-rails`), 검색/필터 중이거나 카테고리가 적으면 평면 그리드(`#card-grid`). 카드에는 썸네일, 시연/PDF 배지, 챕터 수·PDF 페이지 수 메타 표시.
- **빈 상태** (`#empty-state`): 임베드된 영상이 없을 때 폴더 선택 버튼(`webkitdirectory`)으로 로컬 영상을 불러오는 폴백.

담당 JS 객체: `dashboard`(렌더·필터), `catalog`(임베드/폴더선택 데이터 → 항목 변환).

### 2. 영상재생 화면 (`#view-player`)

선택한 영상의 재생 + 과제 설명 PDF 열람. 구성 요소:

- **비디오 영역** (`#video-wrap`): 포스터 이미지 → 재생 시 비디오로 전환. 원본 해상도 비율을 `--media-aspect`로 반영.
- **커스텀 컨트롤** (`.controls-dock`): 재생/일시정지, 시크바(챕터 위치 마커 오버레이 포함), 시간 표시, 챕터 칩 타임라인(클릭 시 해당 시점으로 이동, 재생 위치 따라 활성 챕터 하이라이트), 재생 속도 1×/2×/3×.
- **PDF 패널** (`#pdf-section`): pdf.js로 캔버스에 슬라이드 렌더. 데스크톱(≥1024px)에서는 접힘 시 영상 우측의 원형 FAB(영상 세로 중앙에 JS로 위치 동기화), 펼침 시 영상 옆 읽기 컬럼으로 확장. 이전/다음 슬라이드 내비게이션.
- **키보드**: `Space` 재생 토글, `Escape` 목록 복귀, PDF 표시 중 `←`/`→` 슬라이드 이동.

담당 JS 객체: `player`(재생·시크·소스 준비), `chapters`, `speed`, `pdfViewer`.

## 아키텍처 (ax.html 내부 JS 구조)

하나의 IIFE 안에 역할별 객체로 분리되어 있습니다:

- **`state`**: 전역 상태(영상 목록, 현재 인덱스, 버퍼링/시킹 플래그 등).
- **`routing` + `router`**: 해시 기반 딥링크. 형식 `#video=<slug>&t=<초>&pdf`. 카드 클릭 → `location.hash` 변경(히스토리 push) → `hashchange` → `routing.apply()` → `router.showPlayer()`. 재생 위치·PDF 펼침 상태는 `history.replaceState`로 URL에 계속 반영(히스토리 증가 없음, 북마크 재개용). slug는 파일명에서 경로·확장자를 뗀 값.
- **영상 로딩 전략** (`player.prepareVideoSource`): 재생 시 영상 전체를 `fetch`로 다운로드(진행률 표시) → Blob URL로 재생하며, 동시에 **IndexedDB**(`mov-demo-videos`)에 영구 캐시. 재방문 시 IndexedDB → 세션 Blob URL 순으로 재사용하고, 다운로드 실패 시 원본 URL 직접 스트리밍으로 폴백. `file:` 프로토콜에서는 다운로드 없이 직접 재생.
- **`videoStore`**: IndexedDB 래퍼. 저장 시 기대 크기를 함께 기록하고, 읽을 때 크기가 다르면 손상으로 보고 삭제.
- **데이터 소스**: 주입된 `VIDEOS` 상수(embedded) + 폴더 선택으로 추가한 로컬 파일(picker, Blob URL). picker 영상은 slug가 없어 딥링크 대상이 아님.

## 배포 관련

- Apache 배포 기준: `.htaccess`가 `/`·`index.html` → `ax.html` 302 리다이렉트, `Accept-Ranges: bytes` 헤더 설정.
- 업로드 대상: `ax.html`, `index.html`, `.htaccess`, `vendor/`, `mp4/`, `pdf/`, `thumbs/`, `posters/`. 서버에는 ffmpeg가 필요 없음(전처리는 로컬에서 1회).
