#!/bin/bash

# Framework 패키지 다운로드 스크립트
#
# 기본 동작: GitHub Releases의 assets(.tgz) 다운로드
#   사용법: ./scripts/download-framework.sh [버전]
#   예시:  ./scripts/download-framework.sh v1.0.0
#
# Git(리포지토리)에서 직접 다운로드: 리포지토리의 `.jw-packs/*.tgz`를 내려받음
#   사용법: ./scripts/download-framework.sh --from-git [ref]
#   예시:  ./scripts/download-framework.sh --from-git main
#   예시:  ./scripts/download-framework.sh --from-git v0.1.6

set -e

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정
GITHUB_REPO="${GITHUB_REPO:-jwsoftlab/react-project}"  # 환경변수로 오버라이드 가능
PACK_GITHUB_REPO="${PACK_GITHUB_REPO:-pharmeath/jw-pack}"  # git 모드 기본 pack repo
MODE="release"  # release | git
VERSION="latest"  # release tagName 또는 latest
GIT_REF="main"     # git mode용 ref(브랜치/태그/커밋)
DOWNLOAD_DIR=".jw-packs"
USE_GH_CLI=true  # GitHub CLI 사용 (권장)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Private repo용 토큰 (GitHub CLI 미사용 시)

# 패키지 목록 (Releases fallback용)
# macOS 기본 /bin/bash(3.2) 호환을 위해 associative array(declare -A) 사용 금지
RELEASE_PACKAGES=(
  "@jwsl/react|jwsl-react"
  "@jwsl/next|jwsl-next"
  "@jwsl/core|jwsl-core"
  "@jwsl/ui|jwsl-ui"
  "@jwsl/lib|jwsl-lib"
  "@jwsl/provider|jwsl-provider"
  "@jwsl/icons|jwsl-icons"
  "@jwsl/chat|jwsl-chat"
  "@jwsl/eslint-config|jwsl-eslint-config"
  "@jwsl/gateway|jwsl-gateway"
  "@jwsl/framework|jwsl-framework"
)

# 버전 정보 파일
VERSION_FILE="${DOWNLOAD_DIR}/.version"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  JW Framework Package Downloader${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 인자 파싱
if [ "${1:-}" = "--from-git" ] || [ "${1:-}" = "--git" ]; then
  MODE="git"
  GIT_REF="${2:-main}"
  VERSION="git:${GIT_REF}"
elif [ "${1:-}" = "--from-release" ] || [ "${1:-}" = "--release" ]; then
  MODE="release"
  VERSION="${2:-latest}"
else
  VERSION="${1:-latest}"  # 기존 호환: 인자로 버전 지정, 기본값 latest
fi

# GitHub CLI 확인
if ! command -v gh &> /dev/null && [ "$USE_GH_CLI" = true ]; then
  echo -e "${YELLOW}GitHub CLI not found, falling back to curl${NC}"
  USE_GH_CLI=false
fi

# GitHub CLI 인증 확인
if [ "$USE_GH_CLI" = true ] && ! gh auth status &> /dev/null; then
  echo -e "${YELLOW}Not authenticated with GitHub CLI${NC}"
  echo -e "${YELLOW} Run: gh auth login${NC}"
  echo -e "${YELLOW}   Falling back to curl...${NC}"
  USE_GH_CLI=false
fi

# 다운로드 디렉토리 생성
mkdir -p "$DOWNLOAD_DIR"

download_from_git() {
  local ref="$1"
  local repo="$2"

  echo -e "${YELLOW} Downloading packages from git ref: ${ref}${NC}"
  echo -e "${BLUE}   Source: repo ${repo} (.jw-packs/*.tgz)${NC}"
  echo ""

  local assets_lines=""

  if [ "$USE_GH_CLI" = true ]; then
    if assets_lines=$(gh api "repos/${repo}/contents/.jw-packs?ref=${ref}" \
      --jq '.[] | select(.type=="file") | select(.name|endswith(".tgz")) | .name' 2>/dev/null); then
      :
    else
      assets_lines=""
    fi
  else
    local api_url="https://api.github.com/repos/${repo}/contents/.jw-packs?ref=${ref}"
    local json=""

    if [ -n "$GITHUB_TOKEN" ]; then
      json=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$api_url")
    else
      json=$(curl -s "$api_url")
    fi

    if command -v jq >/dev/null 2>&1; then
      assets_lines=$(echo "$json" | jq -r '.[] | select(.type=="file") | select(.name|endswith(".tgz")) | .name' 2>/dev/null || true)
    else
      assets_lines=$(echo "$json" | grep -E '"name"\s*:\s*"[^"]+\.tgz"' | sed -E 's/.*"name"\s*:\s*"([^"]+)".*/\1/' || true)
    fi
  fi

  if [ -z "$assets_lines" ]; then
    echo -e "${RED}No .tgz files found at .jw-packs for ref: ${ref}${NC}"
    echo -e "${YELLOW} Troubleshooting:${NC}"
    echo -e "${YELLOW}   - Check that the repo has committed .jw-packs/*.tgz at that ref${NC}"
    echo -e "${YELLOW}   - For private repos, authenticate: gh auth login OR export GITHUB_TOKEN${NC}"
    exit 1
  fi

  local downloaded=0
  local failed=0

  while IFS= read -r filename; do
    if [ -z "$filename" ]; then
      continue
    fi

    echo -e "${YELLOW} Downloading ${filename}...${NC}"
    local output_file="${DOWNLOAD_DIR}/${filename}"
    local content_api="https://api.github.com/repos/${repo}/contents/.jw-packs/${filename}?ref=${ref}"

    if [ "$USE_GH_CLI" = true ]; then
      if gh api "$content_api" -H "Accept: application/vnd.github.raw" > "$output_file" 2>/dev/null; then
        echo -e "${GREEN}   Downloaded: ${filename}${NC}"
        downloaded=$((downloaded + 1))
      else
        echo -e "${RED}  Failed: ${filename}${NC}"
        failed=$((failed + 1))
        rm -f "$output_file" || true
      fi
    else
      local http_code=""
      if [ -n "$GITHUB_TOKEN" ]; then
        http_code=$(curl -L -H "Authorization: token $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github.raw" \
          -w "%{http_code}" -o "$output_file" "$content_api" 2>/dev/null)
      else
        http_code=$(curl -L -H "Accept: application/vnd.github.raw" \
          -w "%{http_code}" -o "$output_file" "$content_api" 2>/dev/null)
      fi

      if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}   Downloaded: ${filename}${NC}"
        downloaded=$((downloaded + 1))
      else
        echo -e "${RED}  Failed (HTTP ${http_code})${NC}"
        failed=$((failed + 1))
        rm -f "$output_file" || true
      fi
    fi
  done <<< "$assets_lines"

  DOWNLOADED="$downloaded"
  FAILED="$failed"
}

# 최신 버전 가져오기 (latest 지정 시)
if [ "$MODE" = "release" ] && [ "$VERSION" = "latest" ]; then
  echo -e "${YELLOW} Fetching latest release version...${NC}"
  
  if [ "$USE_GH_CLI" = true ]; then
    # GitHub CLI 사용
    VERSION=$(gh release list --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null)
  else
    # curl 사용
    if [ -n "$GITHUB_TOKEN" ]; then
      VERSION=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
      VERSION=$(curl -s \
        "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi
  fi
  
  if [ -z "$VERSION" ]; then
    echo -e "${RED}Failed to fetch latest version${NC}"
    echo -e "${YELLOW} Tip: Specify version explicitly, e.g., ./scripts/download-framework.sh v1.0.0${NC}"
    exit 1
  fi
  
  echo -e "${GREEN} Latest version: ${VERSION}${NC}"
  echo ""
fi

# 이미 다운로드된 버전 확인
if [ -f "$VERSION_FILE" ]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
  if [ "$CURRENT_VERSION" = "$VERSION" ]; then
    echo -e "${YELLOW}Version ${VERSION} is already downloaded${NC}"
    read -p "Re-download? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${GREEN} Using existing packages${NC}"
      exit 0
    fi
    # 기존 파일 삭제
    rm -f "${DOWNLOAD_DIR}"/*.tgz
  fi
fi

echo -e "${YELLOW} Downloading packages for version: ${VERSION}${NC}"
echo ""

# 다운로드 카운터
DOWNLOADED=0
FAILED=0

# Git mode: repo의 .jw-packs에서 직접 다운로드
if [ "$MODE" = "git" ]; then
  download_from_git "$GIT_REF" "$PACK_GITHUB_REPO"

# Release mode: GitHub Releases 사용 (권장)
elif [ "$USE_GH_CLI" = true ]; then
  echo -e "${BLUE}Using GitHub CLI for download...${NC}"
  
  # Release의 모든 assets 가져오기
  ASSETS=$(gh release view "$VERSION" --json assets --jq '.assets[] | "\(.name)|\(.url)"')
  
  if [ -z "$ASSETS" ]; then
    echo -e "${RED}No assets found for release ${VERSION}${NC}"
    echo -e "${YELLOW} Check: https://github.com/${GITHUB_REPO}/releases/tag/${VERSION}${NC}"
    exit 1
  fi
  
  # 각 asset 다운로드
  while IFS='|' read -r filename url; do
    # .tgz 파일만 다운로드
    if [[ "$filename" == *.tgz ]]; then
      echo -e "${YELLOW} Downloading ${filename}...${NC}"
      
      OUTPUT_FILE="${DOWNLOAD_DIR}/${filename}"
      
      # gh release download 명령 사용
      if gh release download "$VERSION" \
           --pattern "$filename" \
           --dir "$DOWNLOAD_DIR" \
           --clobber 2>/dev/null; then
        echo -e "${GREEN}   Downloaded: ${filename}${NC}"
        DOWNLOADED=$((DOWNLOADED + 1))
      else
        echo -e "${RED}  Failed: ${filename}${NC}"
        FAILED=$((FAILED + 1))
      fi
    fi
  done <<< "$ASSETS"
  
else
  # curl 사용 (fallback)
  echo -e "${BLUE}Using curl for download...${NC}"

  TOTAL=${#RELEASE_PACKAGES[@]}
  CURRENT=0

  for entry in "${RELEASE_PACKAGES[@]}"; do
    CURRENT=$((CURRENT + 1))
    IFS='|' read -r package_name filename <<< "$entry"
    
    echo -e "${YELLOW}[${CURRENT}/${TOTAL}] Downloading ${package_name}...${NC}"
    
    # GitHub API로 Release Assets 목록 가져오기
    if [ -n "$GITHUB_TOKEN" ]; then
      ASSET_INFO=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${VERSION}" | \
        grep -B 3 "\"name\": \"${filename}-[0-9.]*.tgz\"" | \
        grep "browser_download_url" | \
        sed -E 's/.*"([^"]+)".*/\1/')
    else
      ASSET_INFO=$(curl -s \
        "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${VERSION}" | \
        grep -B 3 "\"name\": \"${filename}-[0-9.]*.tgz\"" | \
        grep "browser_download_url" | \
        sed -E 's/.*"([^"]+)".*/\1/')
    fi
    
    if [ -z "$ASSET_INFO" ]; then
      echo -e "${RED}  Could not find asset for ${package_name}${NC}"
      FAILED=$((FAILED + 1))
      continue
    fi
    
    OUTPUT_FILE="${DOWNLOAD_DIR}/$(basename $ASSET_INFO)"
    
    # 다운로드
    if [ -n "$GITHUB_TOKEN" ]; then
      HTTP_CODE=$(curl -L -H "Authorization: token $GITHUB_TOKEN" \
        -w "%{http_code}" \
        -o "$OUTPUT_FILE" \
        "$ASSET_INFO" 2>/dev/null)
    else
      HTTP_CODE=$(curl -L \
        -w "%{http_code}" \
        -o "$OUTPUT_FILE" \
        "$ASSET_INFO" 2>/dev/null)
    fi
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
      echo -e "${GREEN}   Downloaded: $(basename $OUTPUT_FILE)${NC}"
      DOWNLOADED=$((DOWNLOADED + 1))
    else
      echo -e "${RED}  Failed (HTTP ${HTTP_CODE})${NC}"
      FAILED=$((FAILED + 1))
    fi
  done
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $FAILED -eq 0 ] && [ $DOWNLOADED -gt 0 ]; then
  # 버전 정보 저장
  echo "$VERSION" > "$VERSION_FILE"
  
  echo -e "${GREEN} All packages downloaded successfully!${NC}"
  echo -e "${GREEN}   Version: ${VERSION}${NC}"
  echo -e "${GREEN}   Downloaded: ${DOWNLOADED} package(s)${NC}"
  echo -e "${GREEN}   Location: ${DOWNLOAD_DIR}/${NC}"
  echo ""
  echo -e "${YELLOW} Next steps:${NC}"
  echo -e "${YELLOW}   ./scripts/create-jw-app.sh [프로젝트명] [도메인1] [도메인2] ...${NC}"
elif [ $DOWNLOADED -eq 0 ]; then
  echo -e "${RED}No packages downloaded${NC}"
  echo ""
  echo -e "${YELLOW} Troubleshooting:${NC}"
  if [ "$MODE" = "git" ]; then
    echo -e "${YELLOW}   1. Check .jw-packs/*.tgz exists in repo at ref: ${GIT_REF}${NC}"
    echo -e "${YELLOW}   2. Check repo access: ${GITHUB_REPO}${NC}"
    echo -e "${YELLOW}   3. For private repos: gh auth login OR export GITHUB_TOKEN${NC}"
  else
    echo -e "${YELLOW}   1. Check if release ${VERSION} exists: https://github.com/${GITHUB_REPO}/releases${NC}"
    if [ "$USE_GH_CLI" = false ]; then
      echo -e "${YELLOW}   2. Install GitHub CLI: brew install gh${NC}"
      echo -e "${YELLOW}   3. Authenticate: gh auth login${NC}"
    fi
    echo -e "${YELLOW}   4. For private repos with curl, set GITHUB_TOKEN environment variable${NC}"
  fi
  exit 1
else
  echo -e "${YELLOW}${FAILED} package(s) failed to download${NC}"
  echo -e "${GREEN}  ${DOWNLOADED} package(s) downloaded successfully${NC}"
  echo ""
  echo -e "${YELLOW} You can continue, but some packages are missing${NC}"
  exit 1
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
