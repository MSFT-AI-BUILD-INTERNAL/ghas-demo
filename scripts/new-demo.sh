#!/usr/bin/env bash
# 매번 "클린 상태"로 데모를 시작하기 위한 부트스트랩.
# 템플릿 repo에서 새 repo를 생성하고 GHAS 전 기능을 켠 뒤 스캔을 시작한다.
#
# 사용법:  ./scripts/new-demo.sh [새repo이름]
#   예)   ./scripts/new-demo.sh                # 자동 이름(ghas-live-MMDD-HHMM)
#         ./scripts/new-demo.sh ghas-fsi-demo  # 이름 지정
#
# 사전조건: gh 로그인, org 멤버(admin). 리포지토리 루트에서 실행.
set -euo pipefail

# 스크립트 위치 기준으로 리포 루트를 잡는다(어디서 실행하든 JSON 경로가 맞도록).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ORG="MSFT-AI-BUILD-INTERNAL"
TEMPLATE="$ORG/ghas-demo"
NEW="${1:-ghas-live-$(date +%m%d-%H%M)}"
REPO="$ORG/$NEW"

echo "▶ 템플릿에서 새 repo 생성: $REPO"
gh repo create "$REPO" --template "$TEMPLATE" --public >/dev/null
sleep 6

echo "▶ CodeQL default-setup 해제(고급 워크플로우와 충돌 방지)"
gh api -X PATCH "repos/$REPO/code-scanning/default-setup" -f state=not-configured >/dev/null 2>&1 || true

echo "▶ Secret Scanning / Push Protection / AI 탐지 / validity 켜기"
gh api -X PATCH "repos/$REPO" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_non_provider_patterns][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_validity_checks][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_ai_detection][status]=enabled' >/dev/null

echo "▶ Dependabot alerts + security updates 켜기"
gh api -X PUT "repos/$REPO/vulnerability-alerts" >/dev/null
gh api -X PUT "repos/$REPO/automated-security-fixes" >/dev/null

echo "▶ Ruleset(main 보호) 적용"
# 템플릿 생성 직후엔 rulesets 엔드포인트가 잠깐 준비 안 될 수 있어 재시도한다.
# ponytail: 5회 고정 재시도, 그래도 실패하면 에러 노출하고 중단(조용히 건너뛰지 않음)
for i in 1 2 3 4 5; do
  if gh api "repos/$REPO/rulesets" --method POST \
       --input "$ROOT/.github/rulesets/main-protection.json" >/dev/null; then
    echo "  ruleset OK"; break
  fi
  [ "$i" = 5 ] && { echo "  ✗ ruleset 적용 실패(위 에러 확인)"; exit 1; }
  echo "  …repo 준비 대기, 재시도 $i"; sleep 4
done

echo "▶ CodeQL 스캔 트리거"
sleep 3
gh workflow run codeql.yml --repo "$REPO" >/dev/null 2>&1 || true

cat <<EOF

✅ 준비 완료
   Repo:      https://github.com/$REPO
   Security:  https://github.com/$REPO/security
   Actions:   https://github.com/$REPO/actions

다음: 2~3분 뒤 Security 탭에 alert가 뜨면 DEMO.md 순서대로 진행.
데모 후 정리:  gh repo delete $REPO --yes   (delete_repo 권한 필요)
EOF
