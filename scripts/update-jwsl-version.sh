#!/bin/bash

# ============================================================================
# Git 기반 @jwsl 패키지 버전 업데이트 스크립트
# ============================================================================
# 사용법:
#   ./scripts/update-jwsl-version.sh <version> [app-dir]
#
# 예시:
#   ./scripts/update-jwsl-version.sh v1.0.0
#   ./scripts/update-jwsl-version.sh v1.0.0 app/demo
#
# 설명:
#   - package.json의 pnpm.overrides에서 @jwsl 패키지 Git URL 버전 태그 업데이트
#   - workspace:* 는 건드리지 않고, Git URL만 업데이트
# ============================================================================

set -e

VERSION="$1"
APP_DIR="${2:-.}"

if [ -z "$VERSION" ]; then
  echo "Error: Version is required"
  echo "Usage: $0 <version> [app-dir]"
  echo "Example: $0 v1.0.0"
  exit 1
fi

# 버전 형식 검증
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
  echo "Error: Invalid version format: $VERSION"
  echo "Expected format: v1.0.0 or v1.0.0-beta"
  exit 1
fi

PACKAGE_JSON="$APP_DIR/package.json"

if [ ! -f "$PACKAGE_JSON" ]; then
  echo "Error: $PACKAGE_JSON not found"
  exit 1
fi

echo "Updating @jwsl packages to $VERSION in $PACKAGE_JSON..."

# macOS sed 사용 (GNU sed와 문법이 다름)
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  sed -i '' -E "s|(https://github.com/pharmeath/jw-pack.git#)[^:]+:|\1${VERSION}:|g" "$PACKAGE_JSON"
else
  # Linux
  sed -i -E "s|(https://github.com/pharmeath/jw-pack.git#)[^:]+:|\1${VERSION}:|g" "$PACKAGE_JSON"
fi

echo "✓ Updated all @jwsl packages to $VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff $PACKAGE_JSON"
echo "  2. Install: pnpm install"
echo "  3. Commit: git add $PACKAGE_JSON && git commit -m \"chore: update @jwsl to $VERSION\""
