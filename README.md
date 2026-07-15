# GHAS 데모 — Flask 앱으로 보여주는 Secure SDLC

GitHub.com **퍼블릭 저장소**에서 GHAS 전 기능(Code Scanning·Secret Scanning·Push Protection·
Dependabot·Copilot Autofix·Rulesets·Security 대시보드)을 **커스터마이징 + 알림**까지 한 번에
시연하는 "가볍지만 전부 커버하는" 데모입니다. 퍼블릭 저장소는 이 기능들이 **무료**입니다.

## 이 데모가 보여주는 것

| # | 취약점 (일부러 심음) | 잡는 기능 | 커스터마이징 |
|---|---|---|---|
| 1 | SQL Injection (`app/main.py`) | **CodeQL** (Code Scanning) | `security-extended` 쿼리팩 |
| 2 | 하드코딩 시크릿 (AWS/Slack 키) | **Secret Scanning + Push Protection** | Custom Pattern (`COMP-` 토큰) |
| 3 | 취약한 라이브러리 (`requirements.txt`) | **Dependabot + Dependency Review** | `fail-on-severity: high` |
| 4 | `eval()` 사용 | **커스텀 CodeQL 쿼리** | `no-eval.ql` 직접 작성 |
| 5 | 비구조화 시크릿 (DB 접속 문자열) | **Copilot 기반(AI) 시크릿 탐지** | 정규식 아닌 AI generic 탐지 |

그리고 위 취약점들을 소재로 아래를 함께 시연합니다:

| 기능 | 무엇을 보여주나 | 이 데모에서의 위치 |
|---|---|---|
| **Copilot Autofix** | CodeQL alert에서 AI가 수정 코드를 자동 제안 → PR 반영 | Security 탭 alert 화면 (UI) |
| **커스텀 룰 등록 (Ruleset)** | main 브랜치에 스캔 통과·리뷰 필수 규칙을 코드로 등록 | `.github/rulesets/main-protection.json` |
| **보안 기록 대시보드** | 탐지된 모든 alert를 한 화면에서 추적 | Security 탭 / Security Overview |
| **Teams 알림** | 신규 alert 발생 시 채널로 카드 전송 | `notify.yml` 워크플로우 |

## 파일 구조
```
ghas-demo/
├── app/
│   ├── main.py            # 취약점 4종이 심어진 Flask 앱
│   └── requirements.txt   # 취약한 의존성 (Dependabot 데모)
└── .github/
    ├── dependabot.yml
    ├── rulesets/
    │   └── main-protection.json       # 커스텀 룰 (Ruleset) 등록용
    ├── codeql/
    │   ├── codeql-config.yml          # 기본 + 커스텀 쿼리 함께 실행
    │   └── custom-queries/
    │       ├── no-eval.ql             # 사내 금지 함수 탐지 (커스터마이징)
    │       └── qlpack.yml
    └── workflows/
        ├── codeql.yml                 # Code Scanning
        ├── dependency-review.yml      # 공급망 PR 게이트
        └── notify.yml                 # Teams 알림
```

---

## 준비 (10분)

### 1. 저장소 만들고 코드 올리기
```bash
# ghas-demo 폴더 안에서
git init && git add . && git commit -m "GHAS demo app"
gh repo create ghas-demo --public --source=. --push
```

### 2. GHAS 기능 켜기 — 저장소 Settings > Security
UI에서만 켤 수 있는 항목입니다 (스크립트 불가):
- **Code security**에서 활성화:
  - `Dependency graph` (보통 퍼블릭은 기본 ON)
  - `Dependabot alerts` + `Dependabot security updates`
  - `Secret scanning` + `Push protection`
  - `Code scanning` → 워크플로우는 이미 `codeql.yml`로 제공됨
  - **Copilot secret scanning**(비구조화 시크릿 AI 탐지) → 있으면 함께 ON (아래 3-2)

### 3. 커스텀 Secret 패턴 등록 (커스터마이징 데모)
Settings > Advanced Security > **Secret scanning** > Custom patterns > New pattern
- Pattern name: `Internal API Token`
- Secret format: `COMP-[A-Z0-9]{32}`
- 저장하면 `main.py`의 `COMP-...` 토큰을 탐지합니다.

### 3-2. AI 기반 시크릿 탐지 (패턴 vs AI 대비 데모)
같은 Secret scanning 화면에서 **"Generic secrets / Copilot 기반 탐지"** 옵션을 켭니다.
- `main.py`의 `db_connection_string`(고정 패턴 없는 DB 접속 문자열)은 **정규식으론 못 잡고**,
  Copilot 기반 AI 탐지가 잡습니다.
- 메시지: "우리가 정의한 패턴 + **AI가 형태 없는 비밀번호까지** 잡는다." (요약문서 §5 '패턴 vs AI')

### 4. Teams 알림 준비
1. 대상 Teams 채널 > **···** > **Workflows** > "Post to a channel when a webhook request is received"
   템플릿 생성 → 웹훅 URL 발급 (신규 Teams 권장 방식)
2. 저장소 Settings > Secrets and variables > Actions > New secret
   - Name: `TEAMS_WEBHOOK_URL`, Value: (발급받은 URL)
> `notify.yml`은 Adaptive Card 형식으로 전송합니다. 기존 O365 Incoming Webhook도 동작하지만
> Microsoft가 지원 종료 예정이라 Workflows 방식을 권장합니다.

### 5. Copilot Autofix 켜기 (커스터마이징·AI 데모)
Settings > Code security > **Copilot Autofix** (또는 Code scanning 섹션) 활성화.
퍼블릭 저장소는 기본 사용 가능하며, CodeQL alert 상세 화면에서 AI 수정 제안이 자동 생성됩니다.

### 6. 커스텀 룰(Ruleset) 등록 — 파일로 관리
UI 대신 제공된 JSON을 API로 그대로 등록할 수 있습니다:
```bash
gh api repos/{owner}/ghas-demo/rulesets \
  --method POST --input .github/rulesets/main-protection.json
```
- main 브랜치에 **PR 리뷰 1건 + CodeQL/dependency-review 통과**를 필수로 강제합니다.
- UI로 확인/수정: Settings > Rules > Rulesets.

---

## 시연 시나리오 (라이브 5~7분)

### 데모 A — Push Protection이 시크릿을 막는다 (가장 임팩트 큼)
1. `main.py`에 **새 가짜 AWS 키**를 한 줄 추가하고 커밋 후 `git push`
2. → **push가 거부됨**. 터미널에 "secret detected" 메시지 + bypass 방법 안내가 뜸
3. 메시지: "코드가 원격에 **도달하기 전에** 막았다. 히스토리에 남지 않는다."
4. (AI 탐지 대비) `db_connection_string`은 정규식 패턴이 없는데도 잡히는 걸 보여주며
   "**패턴은 우리가, 형태 없는 비밀은 AI가**" 대비. (요약문서 §5)

### 데모 B — CodeQL이 SQL Injection + eval을 잡는다 (+ CWE + Copilot Autofix)
1. PR을 하나 열면 `codeql.yml`이 실행됨 (2~3분)
2. → Security 탭 > Code scanning 에 **SQL Injection**(기본 쿼리) + **eval 사용 금지**(커스텀 쿼리) alert 표시
3. alert를 열면 **CWE 분류**(예: SQL Injection = `CWE-89`)가 붙어 있음 → "취약점을 표준 분류체계로
   기록/집계한다"는 점 강조. (요약문서 §3 'CVE vs CWE')
4. 메시지: "업계 표준 규칙 + **우리 사내 규칙**을 같이 돌렸다."
5. SQL Injection alert에서 **Copilot Autofix**가 AI 수정 코드를 제안 → "Commit to a new branch"로
   바로 PR 반영. 메시지: "탐지에서 끝나지 않고 **AI가 고치는 것까지**."

### 데모 C — Dependabot이 취약한 라이브러리를 잡는다
1. Security 탭 > Dependabot alerts 에 `flask 2.0.1`, `requests 2.19.1` 취약점 표시
2. Dependabot이 **업데이트 PR을 자동 생성**한 것도 함께 보여줌
3. PR을 열면 `dependency-review`가 High 이상 취약점에서 **CI 실패 → 병합 차단**
4. (Ruleset 등록했다면) main 규칙 때문에 실패한 체크로 **병합 버튼 자체가 잠김**

### 데모 D — 보안 기록 대시보드로 전체 추적
1. Security 탭 개요에서 Code scanning / Secret scanning / Dependabot alerts **건수와 목록**을 한눈에
2. 각 alert의 상태(Open/Fixed/Dismissed), 심각도, 도입 시점을 추적
3. (조직 저장소라면) **Security Overview**에서 여러 저장소를 가로질러 위험을 집계
4. 메시지: "탐지·수정·잔여 위험이 **한 대시보드에 기록**된다 — 감사·규제 대응의 근거."

### 데모 E — 알림이 온다
1. Actions 탭에서 `Security Alert Notify (Teams)` 수동 실행 (`workflow_dispatch`)
2. → Teams 채널에 "보안 취약점 alert N건" Adaptive Card 도착 (Security 탭 바로가기 버튼 포함)

### 데모 F — 유출 사고 대응 (git rm으로는 부족)
이미 push되어 히스토리에 남은 시크릿을 어떻게 처리하는지 보여줍니다. (요약문서 §5)
1. Security 탭 > Secret scanning alert를 열어 **노출된 시크릿**을 확인
2. 핵심 메시지: **`git rm`이나 커밋 삭제로는 부족** — 이미 노출된 값은 **무효화(revoke)+재발급(rotate)**이 정답
   - AWS/DB 자격증명은 **콘솔에서 즉시 폐기 → 새 키 발급 → Secrets에만 저장**
   - 히스토리 제거가 꼭 필요하면 `git filter-repo`로 정리하되, "삭제보다 로테이션이 먼저"
3. alert를 **"Revoked"**로 상태 변경해 대응 이력을 대시보드에 남김

### 마무리 정리 (선택)
취약점을 실제로 고쳐서 alert가 닫히는 것까지 보여주면 "탐지 → 수정 → 검증" 루프가 완성됩니다:
- SQL Injection → 파라미터 바인딩(`cur.execute("... id = ?", (user_id,))`)
- 시크릿 → 제거 후 `${{ secrets.XXX }}` 참조 + 키 로테이션
- 의존성 → `flask`, `requests` 최신 버전으로 상향

---

## 이 데모 범위 밖 (org / GHES 환경 필요 — 장표로 설명)
아래는 단일 퍼블릭 저장소로는 시연이 불가해 **발표(장표)로 설명**하는 항목입니다. 빠뜨린 게
아니라 환경 자체가 다릅니다:

| 항목 | 왜 데모 불가 | 어떻게 보완 |
|---|---|---|
| **오프라인/폐쇄망(GHES)** | GitHub.com 퍼블릭 데모라 온프레 미러링을 못 보여줌 | 요약문서 §7 '고객망 형태별 적용 모델' + GHES 아키텍처 슬라이드로 설명 |
| **Security Campaigns** | 조직(org) 소유·다수 저장소가 있어야 캠페인 생성 가능 | 조직 데모 계정이 있으면 별도 시연, 없으면 개념 슬라이드 |
| **조직 전체 Security Overview** | 여러 저장소 집계는 org 대시보드 기능 | 데모 D의 저장소 단위 대시보드로 대체, org 화면은 스크린샷 |
| **FSI Secure SDLC 전략·로드맵** | 기술 데모가 아니라 도입 전략 | 장표 §7 그대로 발표 |

> 요약: **개발자가 코드/설정으로 만지는 GHAS 기능은 이 데모가 전부 커버**하고,
> 위 4개는 성격상 조직·GHES·발표 영역입니다.

## 주의
- `main.py`의 키·토큰은 **데모용 가짜 값**입니다. 실제 키를 넣지 마세요.
- 퍼블릭 저장소이므로 민감정보를 올리지 마세요.
- CodeQL 커스텀 쿼리 문법은 언어 버전에 따라 조정이 필요할 수 있습니다 (`github/codeql` 저장소의 표준 쿼리 참고).
