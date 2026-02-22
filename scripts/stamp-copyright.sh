#!/bin/bash
# =============================================================================
# 저작권 증명 스크립트
# =============================================================================
# 사용법:
#   ./scripts/stamp-copyright.sh [version]
#
# 예시:
#   ./scripts/stamp-copyright.sh           # Git 태그/커밋 기반 버전
#   ./scripts/stamp-copyright.sh v1.0.0    # 수동 버전 지정
#
# 결과:
#   - copyright-proofs/copyright-proof-{version}.json 생성
#   - (선택) OpenTimestamps로 블록체인 기록
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 프로젝트 루트로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 버전 결정
if [ -n "$1" ]; then
  VERSION="$1"
else
  VERSION=$(git describe --tags --always 2>/dev/null || echo "dev-$(date +%Y%m%d)")
fi

# 타임스탬프 (UTC)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 출력 디렉토리
PROOF_DIR="$PROJECT_ROOT/copyright-proofs"
mkdir -p "$PROOF_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  저작권 증명 생성${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. framework 패키지 해시 생성
echo -e "${YELLOW}[1/4] 소스코드 해시 생성 중...${NC}"

FRAMEWORK_HASH=$(find packages -type f \( -name "*.ts" -o -name "*.tsx" \) | \
  sort | xargs cat 2>/dev/null | sha256sum | cut -d' ' -f1)

echo -e "  Framework 해시: ${GREEN}${FRAMEWORK_HASH:0:16}...${NC}"

# 2. 전체 소스 해시 (선택적)
FULL_HASH=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
  -not -path "./node_modules/*" \
  -not -path "./.next/*" \
  -not -path "./dist/*" | \
  sort | xargs cat 2>/dev/null | sha256sum | cut -d' ' -f1)

echo -e "  전체 소스 해시: ${GREEN}${FULL_HASH:0:16}...${NC}"

# 3. Git 정보
echo ""
echo -e "${YELLOW}[2/4] Git 정보 수집 중...${NC}"

GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_AUTHOR=$(git config user.name 2>/dev/null || echo "unknown")
GIT_EMAIL=$(git config user.email 2>/dev/null || echo "unknown")

echo -e "  커밋: ${GREEN}${GIT_COMMIT:0:8}${NC}"
echo -e "  브랜치: ${GREEN}${GIT_BRANCH}${NC}"

# 4. 파일 통계
echo ""
echo -e "${YELLOW}[3/4] 파일 통계 수집 중...${NC}"

TOTAL_FILES=$(find packages -type f \( -name "*.ts" -o -name "*.tsx" \) | wc -l | tr -d ' ')
TOTAL_LINES=$(find packages -type f \( -name "*.ts" -o -name "*.tsx" \) -exec cat {} \; 2>/dev/null | wc -l | tr -d ' ')

echo -e "  총 파일 수: ${GREEN}${TOTAL_FILES}${NC}"
echo -e "  총 라인 수: ${GREEN}${TOTAL_LINES}${NC}"

# 5. 증명 파일 생성
echo ""
echo -e "${YELLOW}[4/4] 증명 파일 생성 중...${NC}"

PROOF_FILE="$PROOF_DIR/copyright-proof-${VERSION}.json"

cat > "$PROOF_FILE" << EOF
{
  "copyright": {
    "holder": "JWSL Framework Authors",
    "year": "$(date +%Y)",
    "license": "UNLICENSED - Proprietary",
    "allRightsReserved": true
  },
  "proof": {
    "version": "${VERSION}",
    "timestamp": "${TIMESTAMP}",
    "frameworkHash": "${FRAMEWORK_HASH}",
    "fullSourceHash": "${FULL_HASH}",
    "algorithm": "SHA-256"
  },
  "git": {
    "commit": "${GIT_COMMIT}",
    "branch": "${GIT_BRANCH}",
    "author": "${GIT_AUTHOR}",
    "email": "${GIT_EMAIL}"
  },
  "statistics": {
    "totalFiles": ${TOTAL_FILES},
    "totalLines": ${TOTAL_LINES}
  },
  "packages": [
    "@jwsl/core",
    "@jwsl/framework",
    "@jwsl/gateway",
    "@jwsl/lib",
    "@jwsl/provider"
  ],
  "verification": {
    "instructions": "To verify: find packages -type f \\( -name '*.ts' -o -name '*.tsx' \\) | sort | xargs cat | sha256sum",
    "expectedHash": "${FRAMEWORK_HASH}"
  }
}
EOF

echo -e "  생성됨: ${GREEN}${PROOF_FILE}${NC}"

# 6. OpenTimestamps 지원 (설치된 경우)
if command -v ots &> /dev/null; then
  echo ""
  echo -e "${YELLOW}[선택] OpenTimestamps 블록체인 기록 중...${NC}"
  ots stamp "$PROOF_FILE" 2>/dev/null && \
    echo -e "  ${GREEN}✓ 블록체인 타임스탬프 생성됨: ${PROOF_FILE}.ots${NC}" || \
    echo -e "  ${RED}✗ OpenTimestamps 기록 실패${NC}"
else
  echo ""
  echo -e "${BLUE}[정보] OpenTimestamps 미설치${NC}"
  echo -e "  블록체인 기록을 원하시면: pip install opentimestamps-client"
fi

# 7. 요약
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  저작권 증명 생성 완료${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "버전:        ${VERSION}"
echo -e "타임스탬프:  ${TIMESTAMP}"
echo -e "해시:        ${FRAMEWORK_HASH:0:32}..."
echo -e "파일 위치:   ${PROOF_FILE}"
echo ""
echo -e "${BLUE}[다음 단계]${NC}"
echo -e "1. 증명 파일을 Git에 커밋하세요"
echo -e "2. 릴리스 시 태그와 함께 보관하세요"
echo -e "3. (선택) OpenTimestamps로 블록체인 기록"
echo ""
