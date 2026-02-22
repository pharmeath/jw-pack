#!/bin/bash

# Created: 2020-06-10
# Author: seuyung
# description:
# Framework 패키지를 빌드하고 GitHub Release로 배포하는 스크립트
# Framework 팀 전용 - Framework 저장소에서 실행
# 
# 사용법: ./scripts/publish-framework-release.sh [버전] [옵션]
# 예시: ./scripts/publish-framework-release.sh v1.0.0
# 예시: ./scripts/publish-framework-release.sh v1.0.0 --prerelease
# 
# 릴리즈 노트 자동 생성 기능 추가                      2026-01-02 gpt-5
# @jwsl/react, @jwsl/next 패키지 추가             2026-01-02 seuyung

set -e

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정
VERSION=""
RELEASE_NOTES_ARG=""
PRERELEASE=false
DRAFT=false
NO_RELEASE=false
TARGET_ROOT=""
SHOW_HELP=false
DELETE_ALL_TAGS=false

# Pack repo(아티팩트 저장소) 설정
# - 목적: 빌드 산출물(.tgz)을 별도 저장소에 커밋하여 "git pull" 기반 배포를 지원
# - 기본값: https://github.com/pharmeath/jw-pack.git
PACK_REPO_URL="${PACK_REPO_URL:-https://github.com/pharmeath/jw-pack.git}"
PACK_REPO_BRANCH="${PACK_REPO_BRANCH:-main}"

# 인자가 없으면 도움말 표시 (--delete-all-tags는 인자 없이 실행 가능하므로 파싱 후 판단)
if [ $# -eq 0 ]; then
  SHOW_HELP=true
fi

# 옵션 파싱
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    --prerelease)
      PRERELEASE=true
      shift
      ;;
    --draft)
      DRAFT=true
      shift
      ;;
    --no-release)
      NO_RELEASE=true
      shift
      ;;
    --delete-all-tags)
      DELETE_ALL_TAGS=true
      shift
      ;;
    --path|--root)
      TARGET_ROOT="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [ -z "$VERSION" ]; then
        VERSION="$1"
      elif [ -z "$RELEASE_NOTES_ARG" ]; then
        RELEASE_NOTES_ARG="$1"
      fi
      shift
      ;;
  esac
done

RELEASE_NOTES="${RELEASE_NOTES_ARG:-RELEASE_NOTES.md}"

if [ "$SHOW_HELP" = true ]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  JW Framework Release Publisher${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${YELLOW}Usage: $0 <version> [options]${NC}"
  echo -e "${YELLOW}Example: $0 v1.0.0${NC}"
  echo -e "${YELLOW}Example: $0 v1.0.0 --root ../${NC}"
  echo -e "${YELLOW}Example: $0 --delete-all-tags${NC}"
  echo ""
  echo -e "${YELLOW}Options:${NC}"
  echo -e "${YELLOW}  --path, --root <dir>  Specify repository root directory${NC}"
  echo -e "${YELLOW}  --prerelease          Mark as pre-release${NC}"
  echo -e "${YELLOW}  --draft               Create as draft${NC}"
  echo -e "${YELLOW}  --no-release          Skip GitHub Release creation${NC}"
  echo -e "${YELLOW}  --delete-all-tags     Delete all pushed tags (local + remote)${NC}"
  echo -e "${YELLOW}  -h, --help            Show this help message${NC}"
  exit 0
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  JW Framework Release Publisher${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# --delete-all-tags 옵션 처리 (버전 인자 불필요)
if [ "$DELETE_ALL_TAGS" = true ]; then
  echo -e "${YELLOW}  Fetching all tags from remote...${NC}"
  git fetch --tags >/dev/null 2>&1

  ALL_TAGS=$(git tag -l)
  if [ -z "$ALL_TAGS" ]; then
    echo -e "${GREEN} No tags found.${NC}"
    exit 0
  fi

  TAG_COUNT=$(echo "$ALL_TAGS" | wc -l | tr -d ' ')
  echo -e "${YELLOW}  Found ${TAG_COUNT} tag(s):${NC}"
  echo "$ALL_TAGS" | while read -r t; do echo -e "${BLUE}   $t${NC}"; done
  echo ""

  read -p "Delete ALL ${TAG_COUNT} tag(s) from local and remote? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW} Cancelled.${NC}"
    exit 0
  fi

  echo "$ALL_TAGS" | while read -r t; do
    echo -e "${RED}  Deleting tag: $t${NC}"
    git tag -d "$t" >/dev/null 2>&1 || true
    git push origin --delete "$t" >/dev/null 2>&1 || true
  done

  echo -e "${GREEN} All tags deleted.${NC}"
  exit 0
fi

# 버전 검증
if [ -z "$VERSION" ]; then
  echo -e "${RED} Error: Version is required${NC}"
  exit 1
fi

# 버전 형식 검증
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
  echo -e "${RED} Invalid version format: $VERSION${NC}"
  echo -e "${YELLOW}Expected format: v1.0.0 or v1.0.0-beta${NC}"
  exit 1
fi

echo -e "${GREEN} Version: ${VERSION}${NC}"
echo -e "${GREEN} Release Notes: ${RELEASE_NOTES}${NC}"
[ "$PRERELEASE" = true ] && echo -e "${YELLOW}  Pre-release: Yes${NC}"
[ "$DRAFT" = true ] && echo -e "${YELLOW} Draft: Yes${NC}"
[ "$NO_RELEASE" = true ] && echo -e "${YELLOW} GitHub Release: Skipped (--no-release)${NC}"
echo ""

# GitHub CLI 확인
if ! command -v gh &> /dev/null; then
  echo -e "${RED} GitHub CLI (gh) is not installed${NC}"
  echo -e "${YELLOW} Install: https://cli.github.com/${NC}"
  echo -e "${YELLOW}   macOS: brew install gh${NC}"
  echo -e "${YELLOW}   Linux: See https://github.com/cli/cli/blob/trunk/docs/install_linux.md${NC}"
  exit 1
fi

# GitHub 인증 확인
if ! gh auth status &> /dev/null; then
  echo -e "${RED} Not authenticated with GitHub${NC}"
  echo -e "${YELLOW} Run: gh auth login${NC}"
  exit 1
fi

# 저장소 루트 경로 저장 및 자동 감지
RESOLVED_PATH=""

if [ -n "$TARGET_ROOT" ]; then
  if [ -d "$TARGET_ROOT" ]; then
    RESOLVED_PATH=$(cd "$TARGET_ROOT" && pwd)
  else
    echo -e "${RED} Invalid path: $TARGET_ROOT${NC}"
    exit 1
  fi
else
  RESOLVED_PATH=$(pwd)
fi

# 스마트 루트 감지 로직
if [ -d "$RESOLVED_PATH/framework/reactjs" ]; then
  # Case 1: 현재 경로가 모노레포 루트인 경우
  REPO_ROOT="$RESOLVED_PATH"
elif [ -f "$RESOLVED_PATH/package.json" ] && [ -d "$RESOLVED_PATH/packages" ]; then
  # Case 2: 현재 경로가 'framework/reactjs' 디렉토리인 경우
  echo -e "${YELLOW} Detected framework/reactjs directory. Switching to repository root.${NC}"
  REPO_ROOT=$(dirname "$(dirname "$RESOLVED_PATH")")
elif [ -f "$RESOLVED_PATH/publish-framework-release.sh" ] && [ "$(basename "$RESOLVED_PATH")" = "scripts" ]; then
  # Case 3: 현재 경로가 'framework/reactjs/scripts' 디렉토리인 경우
  PARENT_DIR=$(dirname "$RESOLVED_PATH")
  if [ -d "$PARENT_DIR/packages" ]; then
     echo -e "${YELLOW} Detected scripts directory. Switching to repository root.${NC}"
     REPO_ROOT=$(dirname "$(dirname "$PARENT_DIR")")
  else
     REPO_ROOT="$RESOLVED_PATH"
  fi
else
  # Fallback
  REPO_ROOT="$RESOLVED_PATH"
fi

# 루트로 이동
cd "$REPO_ROOT"

# Framework 디렉토리 확인
if [ ! -d "framework/reactjs" ]; then
  echo -e "${RED} framework/reactjs/ directory not found in ${REPO_ROOT}${NC}"
  echo -e "${YELLOW} This script should be run from the repository root (containing 'framework/reactjs/' folder).${NC}"
  echo -e "${YELLOW} Current resolved root: $REPO_ROOT${NC}"
  echo -e "${YELLOW} Please check your position or use --path to specify the repository root.${NC}"
  exit 1
fi

# Git 상태 확인
if [ -n "$(git status --porcelain)" ]; then
  echo -e "${YELLOW}  Warning: Working directory has uncommitted changes${NC}"
  read -p "Continue anyway? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# 기존 태그 확인
if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo -e "${YELLOW}  Tag ${VERSION} already exists${NC}"
  read -p "Delete and recreate? (y/N): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git tag -d "$VERSION"
    git push origin --delete "$VERSION" 2>/dev/null || true
  else
    exit 1
  fi
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 1/6: Installing dependencies${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd framework/reactjs/
if [ ! -d "node_modules" ]; then
  echo -e "${BLUE}Installing pnpm packages...${NC}"
  pnpm install
else
  echo -e "${GREEN} Dependencies already installed${NC}"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 2/6: Building packages${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

pnpm build:packages

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 3/6: Creating tgz packages${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 출력 디렉토리 생성 (절대 경로 사용)
RELEASE_DIR="${REPO_ROOT}/.release-artifacts"
mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR"/*.tgz

# 각 패키지에서 tgz 생성
# @jwsl/react, @jwsl/next는 다른 패키지의 의존성이므로 먼저 빌드
# 형식: "dir:name" (dir=패키지 경로, name=매핑 이름)
PACKAGES=(
  "packages/react"
  "packages/next"
  "packages/_configs"
  "packages/router"
  "packages/router-next-app"
  "packages/router-next-pages"
  "packages/router-browser"
  "packages/core"
  "packages/ui"
  "packages/lib"
  "packages/provider"
  "packages/css"
  "packages/icons"
  "packages/chat"
  "packages/eslint-config"
  "packages/gateway"
  "packages/framework"
  "config/typescript"
  "templates"
)
TGZ_FILES=()

for pkg_path in "${PACKAGES[@]}"; do
  if [ -d "$pkg_path" ]; then
    pkg_name=$(basename "$pkg_path")
    echo -e "${BLUE} Packing ${pkg_path}...${NC}"
    cd "$pkg_path"
    
    # package.json 백업
    cp package.json package.json.bak
    
    # private 플래그 제거 및 @jwsl/* dependencies를 peerDependencies로 이동
    node - <<'PKGMOD'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

// private 플래그 제거 (npm pack이 거부하지 않도록)
delete pkg.private;

// @jwsl/* dependencies를 peerDependencies로 이동
if (pkg.dependencies) {
  const jwslDeps = {};
  const otherDeps = {};
  
  for (const [name, version] of Object.entries(pkg.dependencies)) {
    if (name.startsWith('@jwsl/')) {
      jwslDeps[name] = version;
    } else {
      otherDeps[name] = version;
    }
  }
  
  if (Object.keys(jwslDeps).length > 0) {
    pkg.peerDependencies = pkg.peerDependencies || {};
    Object.assign(pkg.peerDependencies, jwslDeps);
    pkg.dependencies = otherDeps;
  }
}

// devDependencies에서도 @jwsl/* 제거
if (pkg.devDependencies) {
  const cleaned = {};
  for (const [name, version] of Object.entries(pkg.devDependencies)) {
    if (!name.startsWith('@jwsl/')) {
      cleaned[name] = version;
    }
  }
  pkg.devDependencies = cleaned;
}

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
PKGMOD
    
    # tgz 생성 (npm pack to avoid workspace pack issues)
    TGZ_FILE=$(npm pack --silent --pack-destination "$RELEASE_DIR" | grep -o '[^/]*\.tgz$')
    
    # package.json 복원
    mv package.json.bak package.json
    
    if [ -n "$TGZ_FILE" ]; then
      echo -e "${GREEN}   Created: ${TGZ_FILE}${NC}"
      TGZ_FILES+=("${RELEASE_DIR}/${TGZ_FILE}")
    else
      echo -e "${RED}   Failed to create tgz for ${pkg_path}${NC}"
    fi
    
    cd "$REPO_ROOT/framework/reactjs"
  fi
done

# framework 디렉토리에서 나가서 저장소 루트로 이동
cd "$REPO_ROOT"

if [ ${#TGZ_FILES[@]} -eq 0 ]; then
  echo -e "${RED} No tgz files created${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN} Created ${#TGZ_FILES[@]} package(s)${NC}"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 3.5/6: Pushing tgz to pack repo${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${BLUE} Pack repo: ${PACK_REPO_URL} (${PACK_REPO_BRANCH})${NC}"

TMP_PACK_DIR="$(mktemp -d)"
PACK_REPO_DIR="${TMP_PACK_DIR}/react_jw_pack"

cleanup_pack_tmp() {
  rm -rf "$TMP_PACK_DIR" >/dev/null 2>&1 || true
}
trap cleanup_pack_tmp EXIT

git clone "$PACK_REPO_URL" "$PACK_REPO_DIR" >/dev/null 2>&1

cd "$PACK_REPO_DIR"
git checkout "$PACK_REPO_BRANCH" >/dev/null 2>&1 || git checkout -b "$PACK_REPO_BRANCH"

# 커밋 author 기본값 세팅(환경에 없을 수 있음)
if ! git config user.name >/dev/null 2>&1; then
  git config user.name "jw-framework-bot"
fi
if ! git config user.email >/dev/null 2>&1; then
  git config user.email "jw-framework-bot@users.noreply.github.com"
fi

mkdir -p .jw-packs
rm -f .jw-packs/*.tgz

for file in "${TGZ_FILES[@]}"; do
  cp "$file" .jw-packs/
done

echo "$VERSION" > .jw-packs/.version

# Create manifest.json for package resolution
# This maps @jwsl/* package names to their tgz filenames
node - "$VERSION" "${TGZ_FILES[@]}" <<'MANIFEST_SCRIPT'
const fs = require('fs');
const path = require('path');
const version = process.argv[2];
const tgzFiles = process.argv.slice(3);

const manifest = {
  version: version,
  created: new Date().toISOString(),
  packages: {}
};

// Map package names to tgz filenames
const pkgNameMap = {
  'react': '@jwsl/react',
  'next': '@jwsl/next',
  '_configs': '@jwsl/_configs',
  'router': '@jwsl/router',
  'router-next-app': '@jwsl/router-next-app',
  'router-next-pages': '@jwsl/router-next-pages',
  'router-browser': '@jwsl/router-browser',
  'core': '@jwsl/core',
  'provider': '@jwsl/provider',
  'lib': '@jwsl/lib',
  'css': '@jwsl/css',
  'icons': '@jwsl/icons',
  'ui': '@jwsl/ui',
  'chat': '@jwsl/chat',
  'eslint-config': '@jwsl/eslint-config',
  'gateway': '@jwsl/gateway',
  'framework': '@jwsl/framework',
  'typescript-config': '@jwsl/typescript-config',
  'templates': '@jwsl/templates'
};

for (const file of tgzFiles) {
  const basename = path.basename(file);
  // Extract package name from filename: jwsl-core-0.1.6.tgz -> core
  const match = basename.match(/^jwsl-([a-z_-]+)-[\d.]+\.tgz$/);
  if (match) {
    const shortName = match[1];
    const fullName = pkgNameMap[shortName];
    if (fullName) {
      manifest.packages[fullName] = basename;
    }
  }
}

fs.writeFileSync('.jw-packs/manifest.json', JSON.stringify(manifest, null, 2) + '\n');
console.log('Created manifest.json with', Object.keys(manifest.packages).length, 'packages');
MANIFEST_SCRIPT

git add .jw-packs/*.tgz .jw-packs/.version .jw-packs/manifest.json

if git diff --cached --quiet; then
  echo -e "${YELLOW} No changes to commit in pack repo (already up to date)${NC}"
else
  git commit -m "Update jw packs for ${VERSION}" >/dev/null 2>&1
  git push origin "$PACK_REPO_BRANCH" >/dev/null 2>&1
  echo -e "${GREEN} Pack repo updated and pushed${NC}"
fi

# pack repo에도 태그를 만들어 ref 기반 다운로드를 쉽게 함
if git rev-parse "$VERSION" >/dev/null 2>&1; then
  git tag -d "$VERSION" >/dev/null 2>&1 || true
fi
git tag -a "$VERSION" -m "JW packs ${VERSION}" >/dev/null 2>&1
git push origin "$VERSION" --force >/dev/null 2>&1
echo -e "${GREEN} Pack repo tag pushed: ${VERSION}${NC}"

cd "$REPO_ROOT"

# 생성된 파일 목록 확인 (디버깅용)
echo -e "${BLUE} Package files:${NC}"
for file in "${TGZ_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo -e "${GREEN}   $(basename $file)${NC}"
  else
    echo -e "${RED}   $(basename $file) - FILE NOT FOUND${NC}"
  fi
done

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 4/6: Creating Git tag${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"
echo -e "${GREEN} Tag ${VERSION} created and pushed${NC}"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 5/6: Creating GitHub Release${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$NO_RELEASE" = true ]; then
  echo -e "${YELLOW} Skipping GitHub Release creation (--no-release)${NC}"
else

# Release Notes 파일 확인
NOTES_CONTENT=""
if [ -f "$RELEASE_NOTES" ]; then
  NOTES_CONTENT=$(cat "$RELEASE_NOTES")
else
  NOTES_CONTENT="Release $VERSION

## Packages
$(for file in "${TGZ_FILES[@]}"; do echo "- $(basename $file)"; done)

## Installation
\`\`\`bash
./scripts/download-framework.sh $VERSION
\`\`\`
"
fi

# GitHub Release 생성
GH_ARGS=()
[ "$PRERELEASE" = true ] && GH_ARGS+=("--prerelease")
[ "$DRAFT" = true ] && GH_ARGS+=("--draft")

echo "$NOTES_CONTENT" | gh release create "$VERSION" \
  "${TGZ_FILES[@]}" \
  --title "JW Framework $VERSION" \
  --notes-file - \
  "${GH_ARGS[@]}"

fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 6/6: Syncing docs & scripts to pack repo${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

FW_ROOT="${REPO_ROOT}/framework/reactjs"
DOCS_SRC="${FW_ROOT}/docs"
SCRIPTS_SRC="${FW_ROOT}/scripts"
ENV_EXAMPLE_SRC="${FW_ROOT}/.env.example"

if [ -d "$PACK_REPO_DIR" ]; then
  cd "$PACK_REPO_DIR"

  # docs 동기화
  if [ -d "$DOCS_SRC" ]; then
    rm -rf docs
    cp -r "$DOCS_SRC" docs
    echo -e "${GREEN}   Synced docs/ (policy, guide, architecture, planning)${NC}"
  else
    echo -e "${YELLOW}   docs/ not found, skipping${NC}"
  fi

  # scripts 동기화
  if [ -d "$SCRIPTS_SRC" ]; then
    rm -rf scripts
    cp -r "$SCRIPTS_SRC" scripts
    echo -e "${GREEN}   Synced scripts/${NC}"
  else
    echo -e "${YELLOW}   scripts/ not found, skipping${NC}"
  fi

  # .env.example 동기화
  if [ -f "$ENV_EXAMPLE_SRC" ]; then
    cp "$ENV_EXAMPLE_SRC" .env.example
    echo -e "${GREEN}   Synced .env.example${NC}"
  else
    echo -e "${YELLOW}   .env.example not found, skipping${NC}"
  fi

  git add docs/ scripts/ .env.example

  if git diff --cached --quiet; then
    echo -e "${YELLOW} No doc/script/env changes to commit${NC}"
  else
    git commit -m "Sync docs, scripts & .env.example for ${VERSION}" >/dev/null 2>&1
    git push origin "$PACK_REPO_BRANCH" >/dev/null 2>&1
    echo -e "${GREEN} Docs, scripts & .env.example pushed to pack repo${NC}"
  fi

  cd "$REPO_ROOT"
else
  echo -e "${YELLOW} Pack repo dir not available, skipping docs/scripts sync${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Release published successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE} Version: ${VERSION}${NC}"
echo -e "${BLUE} Packages: ${#TGZ_FILES[@]}${NC}"
if [ "$NO_RELEASE" = false ]; then
  echo -e "${BLUE} Release URL:${NC}"
  gh release view "$VERSION" --web
fi

# 정리
echo ""
read -p "Clean up release artifacts? (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  rm -rf "$RELEASE_DIR"
  echo -e "${GREEN} Cleaned up${NC}"
fi

echo ""
echo -e "${YELLOW} Next steps for users:${NC}"
echo -e "${YELLOW}   ./scripts/download-framework.sh --from-git ${VERSION}${NC}"
echo -e "${YELLOW}   (or Releases mode) ./scripts/download-framework.sh ${VERSION}${NC}"
echo ""
