## 변경 요약

- **`videos.csv` 추가** — 영문 디스크 파일명(`file`)과 한글 표시명(`title`)을 매핑하는 매니페스트. `scan_videos.sh`가 있으면 폴더 스캔 대신 이 파일을 우선 사용하고, 각 `file`이 실제로 존재하는지 검증합니다.
- **`chapters.csv` 수정** — `video` 열을 한글 과제명(확장자 없음)으로 변경. 스크립트가 `videos.csv`의 `title`→`file` 매핑으로 영문 파일 키를 해석합니다.
- **`scan_videos.sh` 개선**
  - `VIDEOS`를 `{file, title}` 객체 배열로 주입
  - `videos.csv` 없을 때는 `^[A-Za-z0-9._-]+\.(mp4|webm|ogg|mov)$` 패턴만 포함
  - `THUMBNAILS`·`CHAPTERS` 키를 영문 `file` 기준으로 통일
  - ffmpeg 썸네일도 영문 `.jpg` 경로 생성
- **`index.html` JS** — `catalog.fromEmbedded`가 레거시 문자열 배열과 새 `{file, title}` 객체 배열 모두 지원. `video.name`은 영문 파일( src·썸네일·챕터 키 ), `video.title`은 한글 표시명( 카드·플레이어 헤더 ).
- **로컬 파일 rename**
  - `MCP기반지능형웹E2E자동화플랫폼.mov` → `mcp-e2e-platform.mov`
  - `thumbs/MCP기반지능형웹E2E자동화플랫폼.jpg` → `thumbs/mcp-e2e-platform.jpg`

### 주입 결과 (검증됨)

```javascript
const VIDEOS = [{"file":"mcp-e2e-platform.mov","title":"MCP기반지능형웹E2E자동화플랫폼"}];
const CHAPTERS = {"mcp-e2e-platform.mov":[...]};
const THUMBNAILS = {"mcp-e2e-platform.mov":"thumbs/mcp-e2e-platform.jpg"};
```

---

## 사용자 문서: `videos.csv`

영상 파일(디스크)과 대시보드 표시명(한글 과제명)을 연결합니다. **서버에 올릴 때 필수**입니다.

| 열 | 설명 |
|---|---|
| `file` | 디스크 상의 영문 파일명. `a-z`, `A-Z`, `0-9`, `-`, `_`, `.` 만 허용 (예: `mcp-e2e-platform.mov`) |
| `title` | 대시보드 카드·플레이어 헤더에 표시할 한글 과제명 |

```csv
file,title
mcp-e2e-platform.mov,MCP기반지능형웹E2E자동화플랫폼
another-demo.mp4,다른솔루션시연
```

**규칙**

1. `file`에 해당하는 파일이 `index.html`과 같은 폴더에 있어야 합니다. 없으면 `scan_videos.sh`가 오류로 종료합니다.
2. `videos.csv`가 없으면 폴더를 스캔하지만, **영문 파일명 패턴**에 맞는 파일만 포함하고 `title`은 확장자를 뺀 파일명이 됩니다.
3. `./scan_videos.sh` 실행 후 `index.html`에 `VIDEOS` 배열이 자동 주입됩니다.

---

## 사용자 문서: `chapters.csv`

영상별 구간(챕터) 정의. `video` 열에는 **한글 과제명**을 씁니다 (`videos.csv`의 `title`과 일치).

| 열 | 설명 |
|---|---|
| `video` | 한글 과제명 (확장자 불필요). `videos.csv`의 `title`과 동일하게 작성 |
| `time` | 구간 시작 시각 (`0:10`, `5:30`, `330` 등) |
| `label` | 구간 버튼에 표시할 설명 |

```csv
video,time,label
MCP기반지능형웹E2E자동화플랫폼,0:10,로그인(권한관리)
MCP기반지능형웹E2E자동화플랫폼,0:37,단일시스템점검(모바일홈페이지 8개 메뉴)
```

**규칙**

1. `scan_videos.sh`가 `video` 값을 `videos.csv`의 `title`로 조회해 영문 `file` 키로 변환합니다.
2. 주입된 `CHAPTERS` 객체는 영문 파일명을 키로 사용합니다 (예: `"mcp-e2e-platform.mov"`).
3. 레거시 호환: `video`에 `.mov` 등 확장자가 붙어 있거나 영문 파일명을 직접 써도 해석을 시도합니다.

---

## 워크플로 (배포)

1. 영상 파일을 **영문 파일명**으로 같은 폴더에 배치
2. `videos.csv`에 `file` / `title` 매핑 작성
3. `chapters.csv`의 `video` 열에 한글 `title` 작성
4. `./scan_videos.sh` 실행 → `index.html`에 `VIDEOS`, `CHAPTERS`, `THUMBNAILS` 주입
5. `index.html`, `videos.csv`, `chapters.csv`, `thumbs/`, 영상 파일을 서버에 업로드

---

## 수용 기준 매핑

- [x] 대시보드·플레이어에 한글 과제명 표시 → `videos.csv` `title` + `catalog.fromEmbedded` 객체 지원
- [x] 디스크·서버 파일은 영문만 → `mcp-e2e-platform.mov`, `thumbs/mcp-e2e-platform.jpg`로 rename 및 스캔 필터
- [x] `chapters.csv`는 한글 `video` 참조 유지 → `title`→`file` 해석 후 `CHAPTERS`는 영문 키로 주입
- [x] NFC/NFD 불일치 해소 → VIDEOS/THUMBNAILS/CHAPTERS 모두 동일한 영문 `file` 키 사용
- [x] `./scan_videos.sh` 실행 및 JSON 검증 완료

## 미해결 / 리스크

- macOS 기본 bash 3.x 호환을 위해 연관 배열 대신 병렬 배열로 title 조회 (동작 동일).
- `videos.csv`에 동일 `title`이 중복되면 첫 번째 매칭만 사용됩니다.
- 폴더 피커로 추가한 영상은 기존과 같이 파일명 기반 `title`을 사용합니다 (`videos.csv` 미적용).
