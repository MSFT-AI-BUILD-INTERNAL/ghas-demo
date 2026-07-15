# 내일 시연 런북 (GHAS 데모)

매번 **클린 템플릿**에서 시작 → 각 기능을 라이브로 시연 → 정리. 소요 15~20분.

---

## 0. 사전 준비 (오늘 1회만)

- [ ] 템플릿 repo 확인: `MSFT-AI-BUILD-INTERNAL/ghas-demo` 가 **Template** 로 설정됨
      (repo Settings > General > "Template repository" 체크)
- [ ] **org 레벨 커스텀 시크릿 패턴** 등록 (한 번 등록하면 생성되는 모든 repo에 자동 적용):
      Org Settings > Advanced Security > Secret scanning > **Custom patterns** > New
      - Name: `Internal API Token` / Secret format: `COMP-[A-Z0-9]{32}`
- [ ] (선택) Teams 알림 쓰려면 `TEAMS_WEBHOOK_URL` 시크릿 준비 (README 4번)
- [ ] `gh auth status` 로 로그인 확인

---

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

---

## 2. 데모 A — Push Protection (임팩트 가장 큼, 2분)

로컬에 방금 만든 repo를 클론한 뒤:
```bash
gh repo clone MSFT-AI-BUILD-INTERNAL/<새repo> && cd <새repo>
git checkout -b leak-test                            # main은 ruleset이 막으므로 새 브랜치
# ★ AWS 키는 access key ID + secret access key 를 "쌍"으로 넣어야 막힌다.
#   (ID 단독은 접근 불가라 차단 안 됨) → secret은 실행 시점에 임의 생성해 문서엔 안 남긴다.
SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 40)
cat >> app/main.py <<EOF
aws_access_key_id = "AKIA5FQ2WKZ7NPL4RT6C"
aws_secret_access_key = "$SECRET"
EOF
git commit -am "add key" && git push -u origin leak-test
```
**체크포인트**
- [ ] push 가 **거부**되고("push declined due to repository rule violations")
      "Amazon AWS Access Key ID" + "Amazon AWS Secret Access Key" 두 건이 뜨며 bypass URL 안내
- [ ] 메시지: "원격에 **도달하기 전에** 막음 → 히스토리에 안 남음"
- [ ] 되돌리기: `git reset --hard HEAD~1`

> **왜 쌍이어야 하나:** GitHub은 access key ID 단독은 막지 않고(접근에 secret이 필요),
> ID+secret 이 근접해 있을 때 고신뢰로 차단한다. 그래서 이 문서엔 ID만 적고 secret은 즉석 생성한다.
> Push Protection은 **모든 브랜치**에 적용됨. main으로 직접 push하면 ruleset("PR 필요")이 먼저
> 걸려 메시지가 헷갈리므로, 위처럼 **새 브랜치**로 시연할 것.

---

## 3. 데모 B — Code Scanning + 커스텀 쿼리 + Autofix (4분)

`Security > Code scanning` 열기.
**체크포인트 (alert 4건)**
- [ ] `py/sql-injection` (High) — 기본 쿼리
- [ ] `py/code-injection` (Critical) — eval 관련
- [ ] `py/flask-debug` (High)
- [ ] **`py/company/no-eval` (High)** — **우리가 만든 커스텀 쿼리** ← 강조 포인트
- [ ] alert 열면 **CWE 분류** 표시 (예: SQLi = CWE-89)
- [ ] SQL Injection alert 에서 **Copilot Autofix** 가 수정 코드 제안 → "Commit to new branch"

> 커스텀 쿼리가 안 보이면: `Security > Code scanning > Tools > CodeQL > 상태` 에서
> 고급 워크플로우가 성공했는지 확인. default-setup 이 켜졌으면 꺼야 함(스크립트가 처리하지만 재확인).

---

## 4. 데모 C — Dependabot (2분)

`Security > Dependabot` 열기.
**체크포인트**
- [ ] flask/requests 취약점 alert 여러 건 (High 포함)
- [ ] `Pull requests` 탭에 **자동 생성된 보안 업데이트 PR** 존재
- [ ] PR 하나 열어 `dependency-review` 체크가 도는지 (PR 게이트)

---

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

---

## 6. 정리 (데모 후)

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
