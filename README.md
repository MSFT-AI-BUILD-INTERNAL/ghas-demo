# GHAS 데모 — Flask 앱으로 보여주는 Secure SDLC

GitHub.com **퍼블릭 저장소**에서 GHAS 전 기능(Code Scanning·Secret Scanning·Push Protection·
Dependabot·Copilot Autofix·Rulesets·Security 대시보드)을 **커스터마이징 + 알림**까지 한 번에
시연하는 "가볍지만 전부 커버하는" 데모입니다. 퍼블릭 저장소는 이 기능들이 **무료**입니다.

## 이 데모가 보여주는 것

| # | 취약점 (일부러 심음) | 잡는 기능 | 커스터마이징 |
|---|---|---|---|
| 1 | SQL Injection (`app/main.py`) | **CodeQL** (Code Scanning) | `security-extended` 쿼리팩 |
| 2 | 하드코딩 시크릿 (Azure Storage/Slack 키) | **Secret Scanning + Push Protection** | Custom Pattern (`COMP-` 토큰) |
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
├── examples/
│   └── codeql-js/         # CodeQL 문법 학습용 JS 예제 (스캔 미포함)
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

# 시연 런북

매번 **클린 템플릿**에서 시작 → 각 기능을 라이브로 시연 → 정리. 소요 15~20분.
저장소 생성·GHAS 기능 활성화·스캔 트리거는 `scripts/new-demo.sh` 가 자동으로 합니다.
(손으로 켜는 방법·커스터마이징 상세는 맨 아래 [수동 설정·커스터마이징 참고](#수동-설정커스터마이징-참고).)

## 0. 사전 준비 (오늘 1회만)

- [ ] 템플릿 repo 확인: `MSFT-AI-BUILD-INTERNAL/ghas-demo` 가 **Template** 로 설정됨
      (repo Settings > General > "Template repository" 체크)
- [ ] (선택) **org 레벨 커스텀 시크릿 패턴** — 데모 F는 심어둔 Azure Storage 시크릿으로 이미 동작하며,
      이 패턴은 "커스터마이징(사내 토큰까지 탐지)"을 추가로 보여줄 때만 등록:
      Org Settings > Advanced Security > Secret scanning > **Custom patterns** > New
      - Name: `Internal API Token` / Secret format: `COMP-[A-Z0-9]{32}`
- [ ] (선택) Teams 알림 쓰려면 `TEAMS_WEBHOOK_URL` 시크릿 준비 (아래 데모 E 참고)
- [ ] `gh auth status` 로 로그인 확인

> **`new-demo.sh` 가 새 repo마다 자동으로 켜는 것들** (손으로 하려면 저장소 `Settings > Security` UI에서):
> - `Dependency graph` (보통 퍼블릭은 기본 ON)
> - `Dependabot alerts` + `Dependabot security updates`
> - `Secret scanning` + `Push protection`
> - `Code scanning` (워크플로우는 `codeql.yml`로 제공, default-setup은 해제)
> - `Copilot secret scanning` (비구조화 시크릿 AI 탐지)
>

## 1. 클린 시작 (시연 직전, 30초)

```bash
cd ghas-demo
./scripts/new-demo.sh          # 또는: ./scripts/new-demo.sh ghas-fsi-demo
```

**체크포인트**
- [ ] 스크립트가 `✅ 준비 완료` 와 새 repo URL 출력
- [ ] `Actions` 탭에 **CodeQL**, **Dependabot** 실행이 뜸
- [ ] 2~3분 뒤 `Security` 탭에 alert 등장 → 아래 순서 진행

> 왜 매번 새 repo? 템플릿 "Generate" 는 **파일만** 복제하고 alert/캠페인은 안 딸려와서,
> 항상 깨끗한 상태에서 GHAS가 "실시간으로 켜지는" 걸 보여줄 수 있음.

## 2. 데모 A — Push Protection (임팩트 가장 큼, 2분)

로컬에 방금 만든 repo를 클론한 뒤:
```bash
gh repo clone MSFT-AI-BUILD-INTERNAL/<새repo> && cd <새repo>
git checkout -b leak-test                            # main은 ruleset이 막으므로 새 브랜치
# Azure Storage 연결 문자열의 AccountKey를 실행 시점에 임의 생성해 문서엔 안 남긴다.
KEY=$(openssl rand -base64 64 | tr -d '\n')
cat >> app/main.py <<EOF
azure_storage_connection = "DefaultEndpointsProtocol=https;AccountName=demostorage;AccountKey=$KEY;EndpointSuffix=core.windows.net"
EOF
git commit -am "add key" && git push -u origin leak-test
```
**체크포인트**
- [ ] push 가 **거부**되고("push declined due to repository rule violations")
      **"Azure Storage Account Access Key"** 가 탐지되며 bypass URL 안내
- [ ] 메시지: "원격에 **도달하기 전에** 막음 → 히스토리에 안 남음"
- [ ] 되돌리기: `git reset --hard HEAD~1`

> **왜 실행 시점 생성:** 문서에 실제 형태의 키를 적어두면 그 자체가 secret scanning에 잡히므로
> AccountKey는 즉석에서 임의 생성한다. Push Protection은 **모든 브랜치**에 적용되며,
> main으로 직접 push하면 ruleset("PR 필요")이 먼저 걸려 메시지가 헷갈리므로,
> 위처럼 **새 브랜치**로 시연할 것.

> **(AI 탐지 대비)** `main.py`의 `db_connection_string`(고정 패턴 없는 DB 접속 문자열)은
> **정규식으론 못 잡고**, Copilot 기반 AI 탐지가 잡습니다.
> "**패턴은 우리가, 형태 없는 비밀은 AI가**" 대비. (요약문서 §5)

## 3. 데모 B — Code Scanning + 커스텀 쿼리 + Autofix (4분)

`Security > Code scanning` 열기.
**체크포인트 (alert 4건)**
- [ ] `py/sql-injection` (High) — 기본 쿼리
- [ ] `py/code-injection` (Critical) — eval 관련
- [ ] `py/flask-debug` (High)
- [ ] **`py/company/no-eval` (High)** — **우리가 만든 커스텀 쿼리** ← 강조 포인트
- [ ] alert 열면 **CWE 분류** 표시 (예: SQLi = CWE-89) → "취약점을 표준 분류체계로 기록/집계"
- [ ] SQL Injection alert 에서 **Copilot Autofix** 가 수정 코드 제안 → "Commit to new branch"로 PR 반영
- [ ] 메시지: "업계 표준 규칙 + **우리 사내 규칙**을 같이 돌렸다. 탐지에서 끝나지 않고 **AI가 고치는 것까지**."

> 커스텀 쿼리가 안 보이면: `Security > Code scanning > Tools > CodeQL > 상태` 에서
> 고급 워크플로우가 성공했는지 확인. default-setup 이 켜졌으면 꺼야 함(스크립트가 처리하지만 재확인).

## 4. 데모 C — Dependabot (2분)

`Security > Dependabot` 열기.
**체크포인트**
- [ ] flask/requests 취약점 alert 여러 건 (High 포함)
- [ ] `Pull requests` 탭에 **자동 생성된 보안 업데이트 PR** 존재
- [ ] PR 하나 열어 `dependency-review` 체크가 도는지 (PR 게이트) → High 이상에서 **CI 실패 → 병합 차단**
- [ ] (Ruleset 등록했다면) main 규칙 때문에 실패한 체크로 **병합 버튼 자체가 잠김**

## 5. 데모 D — Campaign + Security Overview 대시보드 (org 레벨, 3분)

**대시보드:** `github.com/orgs/MSFT-AI-BUILD-INTERNAL/security`
- [ ] Overview 에 방금 만든 repo 의 alert 가 집계로 뜸 (code scanning / dependabot / secret)

**Campaign 생성** (새 repo alert 로 라이브 생성 시연):
```bash
# repo id, alert 번호 확인
gh api repos/MSFT-AI-BUILD-INTERNAL/<새repo> --jq .id
gh api repos/MSFT-AI-BUILD-INTERNAL/<새repo>/code-scanning/alerts --jq '[.[].number]'
```
```bash
cat > /tmp/c.json <<'JSON'
{ "name": "취약점 리메디에이션 캠페인",
  "description": "Code Scanning 취약점 기한 내 해소",
  "ends_at": "2026-09-01T00:00:00Z",
  "managers": ["hy2219"],
  "code_scanning_alerts": [ { "repository_id": <REPO_ID>, "alert_numbers": [1,2,3,4] } ] }
JSON
gh api -X POST orgs/MSFT-AI-BUILD-INTERNAL/campaigns --input /tmp/c.json
```

**UI로 직접 만드는 방법** (CLI 대신):
1. `github.com/orgs/MSFT-AI-BUILD-INTERNAL/security` → 좌측 **Campaigns** → **Create campaign** ▾
2. 드롭다운에서 **From code scanning filters** 선택.
   (다른 옵션: `From template`=CWE 등 미리 정의된 템플릿, `From secret scanning filters`=시크릿용)
3. 필터로 대상 좁히기 — 예) `repository:<새repo>` + `tool:CodeQL` → 뜬 alert 확인(4건).
   - 필터가 넓으면 org 전체 alert가 잡히니 **repository 필터를 꼭** 걸 것.
4. **Create campaign** 진행 → 폼 입력:
   - **Name**: `취약점 리메디에이션 캠페인`
   - **Description**: `Code Scanning 취약점 기한 내 해소` (Markdown 가능)
   - **Due date**: 예) 2026-09-01
   - **Campaign manager**: `hy2219` (필수 — 없으면 생성 불가)
5. 생성 → 담당자에게 알림, 각 alert에 캠페인 배지가 붙음.

> UI ↔ CLI 차이: UI는 **필터로 alert를 시각적으로 골라 담고**, alert 번호를 몰라도 됨(CLI는
> repository_id + alert_numbers를 직접 넣어야 함). 결과물(캠페인)은 동일. 라이브에선 UI가 보기 좋고,
> 미리 준비/재현엔 CLI가 빠름.

**체크포인트**
- [ ] `Security > Campaigns` 에 캠페인 등장, alert 4건 / 담당자 지정 / 마감일
- [ ] 메시지: "탐지→분류→**기한 내 조직 차원 리메디에이션 추적**까지"

> Campaign / 대시보드는 **조직(Org) + GHAS 전용**. 개인 계정에선 안 됨(그래서 팀 repo 사용).

## 6. 데모 E — 알림이 온다 (Teams, 선택)

**사전 준비** (알림 쓸 때만):
1. 대상 Teams 채널 > **···** > **Workflows** > "Post to a channel when a webhook request is received"
   템플릿 생성 → 웹훅 URL 발급 (신규 Teams 권장 방식)
2. 저장소 Settings > Secrets and variables > Actions > New secret
   - Name: `TEAMS_WEBHOOK_URL`, Value: (발급받은 URL)

**시연**:
1. Actions 탭에서 `Security Alert Notify (Teams)` 수동 실행 (`workflow_dispatch`)
2. → Teams 채널에 "보안 취약점 alert N건" Adaptive Card 도착 (Security 탭 바로가기 버튼 포함)

> `notify.yml`은 Adaptive Card 형식으로 전송합니다. 기존 O365 Incoming Webhook도 동작하지만
> Microsoft가 지원 종료 예정이라 Workflows 방식을 권장합니다.

## 7. 데모 F — 유출 사고 대응 (git rm으로는 부족)

이미 push되어 히스토리에 남은 시크릿을 어떻게 처리하는지 보여줍니다. (요약문서 §5)
`app/main.py`에 심어둔 **Azure Storage 연결 문자열**이 새 repo 생성 즉시 secret scanning에 잡혀 있습니다.
1. Security 탭 > Secret scanning alert(**"Azure Storage Account Access Key"**)를 열어 **노출된 시크릿**을 확인
2. 핵심 메시지: **`git rm`이나 커밋 삭제로는 부족** — 이미 노출된 값은 **무효화(revoke)+재발급(rotate)**이 정답
   - Azure/DB 자격증명은 **포털에서 즉시 폐기 → 새 키 발급 → Secrets에만 저장**
   - 히스토리 제거가 꼭 필요하면 `git filter-repo`로 정리하되, "삭제보다 로테이션이 먼저"
3. alert를 **"Revoked"**로 상태 변경해 대응 이력을 대시보드에 남김

## 마무리 정리 (선택)

취약점을 실제로 고쳐서 alert가 닫히는 것까지 보여주면 "탐지 → 수정 → 검증" 루프가 완성됩니다:
- SQL Injection → 파라미터 바인딩(`cur.execute("... id = ?", (user_id,))`)
- 시크릿 → 제거 후 `${{ secrets.XXX }}` 참조 + 키 로테이션
- 의존성 → `flask`, `requests` 최신 버전으로 상향

## 8. 정리 (데모 후)

```bash
gh repo delete MSFT-AI-BUILD-INTERNAL/<새repo> --yes   # delete_repo 권한 필요
```
- [ ] 생성했던 임시 repo 삭제 (다음 시연은 다시 1번부터)

---

## 빠른 참고 — 기능 ↔ 파일

| 기능 | 어디서 | 파일 |
|---|---|---|
| Code Scanning | Actions/Security | `.github/workflows/codeql.yml` |
| 커스텀 쿼리 | 위 alert `py/company/no-eval` | `.github/codeql/custom-queries/no-eval.ql` |
| Dependabot | Security/PR | `.github/dependabot.yml`, `dependency-review.yml` |
| Secret/Push Protection | push 시 | 저장소 Security 설정(스크립트가 켬) |
| Ruleset | Settings > Rules | `.github/rulesets/main-protection.json` |
| 알림 | Actions | `.github/workflows/notify.yml` (webhook 시크릿 필요) |
| 보안정책/CODEOWNERS | repo 루트 | `SECURITY.md`, `.github/CODEOWNERS` |

---

## CodeQL 문법 배우기

커스텀 쿼리(`no-eval.ql`) 문법이 궁금하면 `examples/codeql-js/` 에 **학습용 JS 예제 4종**이 있습니다
(쉬운 것부터 taint tracking까지, 라인별 한국어 주석). 이 폴더는 실제 스캔엔 미포함 — 보여주기·학습 전용.

문법·사용법은 **공식 문서가 정답**입니다. 순서대로 보세요.

1. **문서 허브** — 모든 게 여기서 갈라짐
   <https://codeql.github.com/docs/>
2. **JS 언어 가이드** — `from/where/select`, 클래스, predicate, 데이터플로우, taint tracking을 예제와 함께
   <https://codeql.github.com/docs/codeql-language-guides/codeql-for-javascript/>
3. **JS 표준 라이브러리 레퍼런스** — `CallExpr`, `getCalleeName()`, `DataFlow`, `TaintTracking` 등 원출처 검색
   <https://codeql.github.com/codeql-standard-libraries/javascript/>
4. **VS Code CodeQL 확장** — 로컬에서 쿼리 실행·자동완성 (읽기만 말고 직접 돌려봐야 늚)
   <https://docs.github.com/en/code-security/codeql-for-vs-code>
5. **학습 코스 / variant analysis** — 문제 풀며 익히기
   <https://codeql.github.com/docs/writing-codeql-queries/codeql-training-and-variant-analysis/>

**추천 경로:** 2번으로 개념 잡고 → 4번(VS Code)에서 `examples/codeql-js/` 의 `.ql` 4개를 직접 실행 → 막히는 클래스는 3번에서 검색.

---

## 수동 설정·커스터마이징 참고

`new-demo.sh` 없이 손으로 준비하는 경우의 참고 명령입니다.

### 저장소 만들고 코드 올리기 (스크립트 대신 손으로)
```bash
# ghas-demo 폴더 안에서
git init && git add . && git commit -m "GHAS demo app"
gh repo create ghas-demo --public --source=. --push
```

### 커스텀 룰(Ruleset) 등록 — 파일로 관리
UI 대신 제공된 JSON을 API로 그대로 등록할 수 있습니다:
```bash
gh api repos/{owner}/ghas-demo/rulesets \
  --method POST --input .github/rulesets/main-protection.json
```
- main 브랜치에 **PR 리뷰 1건 + CodeQL/dependency-review 통과**를 필수로 강제합니다.
- UI로 확인/수정: Settings > Rules > Rulesets.

---

## 주의
- `main.py`의 키·토큰은 **데모용 가짜 값**입니다. 실제 키를 넣지 마세요.
- 퍼블릭 저장소이므로 민감정보를 올리지 마세요.
- CodeQL 커스텀 쿼리 문법은 언어 버전에 따라 조정이 필요할 수 있습니다 (`github/codeql` 저장소의 표준 쿼리 참고).
