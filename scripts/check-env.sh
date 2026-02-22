#!/usr/bin/env bash
#############################################
# check-env.sh
# 개발환경 검증 스크립트 (Linux/macOS)
#
# Usage:
#   ./scripts/check-env.sh
#   ./scripts/check-env.sh --fix    # 누락된 도구 설치 안내
#
# 검증 항목:
#   - Bash 4.0+
#   - Git 2.0+
#   - Node.js 18.0+
#   - pnpm 9.0+
#   - realpath 또는 python3 (경로 해석용)
#############################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 카운터
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 옵션 파싱
SHOW_FIX=false
if [ "$1" = "--fix" ] || [ "$1" = "-f" ]; then
  SHOW_FIX=true
fi

print_header() {
  echo ""
  echo -e "${BLUE}============================================${NC}"
  echo -e "${BLUE}  개발환경 검증 스크립트 (create-app.sh용)${NC}"
  echo -e "${BLUE}============================================${NC}"
  echo ""
}

print_result() {
  local status="$1"
  local name="$2"
  local version="$3"
  local required="$4"

  case "$status" in
    pass)
      echo -e "[${GREEN}PASS${NC}] $name: $version"
      PASS_COUNT=$((PASS_COUNT + 1))
      ;;
    fail)
      echo -e "[${RED}FAIL${NC}] $name: $version (필요: $required)"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
    warn)
      echo -e "[${YELLOW}WARN${NC}] $name: $version"
      WARN_COUNT=$((WARN_COUNT + 1))
      ;;
  esac
}

print_fix_guide() {
  local tool="$1"

  if [ "$SHOW_FIX" != true ]; then
    return
  fi

  echo ""
  echo -e "${YELLOW}설치 방법:${NC}"

  case "$tool" in
    bash)
      echo "  # Ubuntu/Debian"
      echo "  sudo apt update && sudo apt install -y bash"
      echo ""
      echo "  # RHEL/CentOS/Fedora"
      echo "  sudo dnf install -y bash"
      ;;
    git)
      echo "  # Ubuntu/Debian"
      echo "  sudo apt update && sudo apt install -y git"
      echo ""
      echo "  # RHEL/CentOS/Fedora"
      echo "  sudo dnf install -y git"
      ;;
    node)
      echo "  # nvm 사용 (권장)"
      echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
      echo "  source ~/.bashrc"
      echo "  nvm install 22"
      echo "  nvm use 22"
      echo ""
      echo "  # 또는 NodeSource 사용"
      echo "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
      echo "  sudo apt install -y nodejs"
      ;;
    pnpm)
      echo "  # corepack 사용 (Node.js 16.13+ 내장)"
      echo "  corepack enable"
      echo "  corepack prepare pnpm@9.15.4 --activate"
      echo ""
      echo "  # 또는 npm 사용"
      echo "  npm install -g pnpm@9.15.4"
      ;;
    realpath)
      echo "  # Ubuntu/Debian"
      echo "  sudo apt install -y coreutils"
      echo ""
      echo "  # 또는 python3 설치 (fallback)"
      echo "  sudo apt install -y python3"
      ;;
  esac
  echo ""
}

check_bash() {
  echo -e "\n${BLUE}[1/5] Bash 검증${NC}"

  if ! command -v bash &> /dev/null; then
    print_result "fail" "Bash" "설치되지 않음" "4.0+"
    print_fix_guide "bash"
    return
  fi

  local version
  version=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  local major
  major=$(echo "$version" | cut -d. -f1)

  if [ "$major" -ge 4 ]; then
    print_result "pass" "Bash" "$version"
  else
    print_result "fail" "Bash" "$version" "4.0+"
    print_fix_guide "bash"
  fi
}

check_git() {
  echo -e "\n${BLUE}[2/5] Git 검증${NC}"

  if ! command -v git &> /dev/null; then
    print_result "fail" "Git" "설치되지 않음" "2.0+"
    print_fix_guide "git"
    return
  fi

  local version
  version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  local major
  major=$(echo "$version" | cut -d. -f1)

  if [ "$major" -ge 2 ]; then
    print_result "pass" "Git" "$version"
  else
    print_result "fail" "Git" "$version" "2.0+"
    print_fix_guide "git"
  fi
}

check_node() {
  echo -e "\n${BLUE}[3/5] Node.js 검증${NC}"

  if ! command -v node &> /dev/null; then
    print_result "fail" "Node.js" "설치되지 않음" "18.0+"
    print_fix_guide "node"
    return
  fi

  local version
  version=$(node -v | tr -d 'v')
  local major
  major=$(echo "$version" | cut -d. -f1)

  if [ "$major" -ge 18 ]; then
    print_result "pass" "Node.js" "$version"

    # npm 버전도 확인
    if command -v npm &> /dev/null; then
      local npm_version
      npm_version=$(npm -v)
      echo -e "       npm: $npm_version"
    fi

    # corepack 상태 확인
    if command -v corepack &> /dev/null; then
      echo -e "       corepack: 사용 가능"
    else
      echo -e "       ${YELLOW}corepack: 비활성화됨 (corepack enable 실행 필요)${NC}"
    fi
  else
    print_result "fail" "Node.js" "$version" "18.0+"
    print_fix_guide "node"
  fi
}

check_pnpm() {
  echo -e "\n${BLUE}[4/5] pnpm 검증${NC}"

  if ! command -v pnpm &> /dev/null; then
    print_result "fail" "pnpm" "설치되지 않음" "9.0+"
    print_fix_guide "pnpm"
    return
  fi

  local version
  version=$(pnpm -v)
  local major
  major=$(echo "$version" | cut -d. -f1)

  if [ "$major" -ge 9 ]; then
    print_result "pass" "pnpm" "$version"

    # 권장 버전 확인
    if [ "$version" = "9.15.4" ]; then
      echo -e "       권장 버전(9.15.4) 일치"
    else
      echo -e "       ${YELLOW}권장 버전: 9.15.4${NC}"
    fi
  else
    print_result "fail" "pnpm" "$version" "9.0+ (권장: 9.15.4)"
    print_fix_guide "pnpm"
  fi
}

check_path_resolver() {
  echo -e "\n${BLUE}[5/5] 경로 해석 도구 검증${NC}"

  local has_realpath=false
  local has_python3=false

  if command -v realpath &> /dev/null; then
    has_realpath=true
    print_result "pass" "realpath" "사용 가능"
  fi

  if command -v python3 &> /dev/null; then
    has_python3=true
    local py_version
    py_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ "$has_realpath" = true ]; then
      echo -e "       python3: $py_version (백업)"
    else
      print_result "pass" "python3" "$py_version (realpath 대체)"
    fi
  fi

  if [ "$has_realpath" = false ] && [ "$has_python3" = false ]; then
    print_result "warn" "경로 해석" "realpath/python3 없음 (기본 경로 사용)"
    print_fix_guide "realpath"
  fi
}

check_optional_tools() {
  echo -e "\n${BLUE}[선택] 추가 도구 검증${NC}"

  # Turborepo
  if command -v turbo &> /dev/null; then
    local turbo_version
    turbo_version=$(turbo --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo -e "[${GREEN}OK${NC}]   turbo: $turbo_version"
  else
    echo -e "[${YELLOW}--${NC}]   turbo: 미설치 (pnpm add -g turbo)"
  fi

  # curl
  if command -v curl &> /dev/null; then
    echo -e "[${GREEN}OK${NC}]   curl: 사용 가능"
  else
    echo -e "[${YELLOW}--${NC}]   curl: 미설치"
  fi

  # wget
  if command -v wget &> /dev/null; then
    echo -e "[${GREEN}OK${NC}]   wget: 사용 가능"
  else
    echo -e "[${YELLOW}--${NC}]   wget: 미설치"
  fi
}

check_directory_structure() {
  echo -e "\n${BLUE}[프로젝트] 디렉토리 구조 검증${NC}"

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local repo_root
  repo_root="$(dirname "$script_dir")"

  # pnpm-workspace.yaml 확인
  if [ -f "$repo_root/pnpm-workspace.yaml" ]; then
    echo -e "[${GREEN}OK${NC}]   pnpm-workspace.yaml: 존재"
  else
    echo -e "[${YELLOW}--${NC}]   pnpm-workspace.yaml: 없음"
  fi

  # .jw-packs 디렉토리 확인
  if [ -d "$repo_root/.jw-packs" ]; then
    local tgz_count
    tgz_count=$(ls -1 "$repo_root/.jw-packs"/*.tgz 2>/dev/null | wc -l | tr -d ' ')
    echo -e "[${GREEN}OK${NC}]   .jw-packs/: ${tgz_count}개의 tgz 파일"
  else
    echo -e "[${YELLOW}--${NC}]   .jw-packs/: 없음 (--git-install 옵션 사용 필요)"
  fi

  # scripts 디렉토리 확인
  if [ -f "$script_dir/create-app.sh" ]; then
    echo -e "[${GREEN}OK${NC}]   create-app.sh: 존재"
  else
    echo -e "[${RED}!!${NC}]   create-app.sh: 없음"
  fi
}

print_summary() {
  echo ""
  echo -e "${BLUE}============================================${NC}"
  echo -e "${BLUE}  검증 결과 요약${NC}"
  echo -e "${BLUE}============================================${NC}"
  echo ""
  echo -e "  ${GREEN}통과${NC}: $PASS_COUNT"
  echo -e "  ${RED}실패${NC}: $FAIL_COUNT"
  echo -e "  ${YELLOW}경고${NC}: $WARN_COUNT"
  echo ""

  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ 모든 필수 요구사항이 충족되었습니다.${NC}"
    echo ""
    echo "create-app.sh 실행 준비 완료:"
    echo "  ./scripts/create-app.sh <project-name> <domain1> [domain2 ...]"
    echo ""
  else
    echo -e "${RED}✗ $FAIL_COUNT개의 필수 요구사항이 충족되지 않았습니다.${NC}"
    echo ""
    if [ "$SHOW_FIX" != true ]; then
      echo "설치 방법을 보려면 --fix 옵션을 사용하세요:"
      echo "  ./scripts/check-env.sh --fix"
      echo ""
    fi
  fi
}

# 메인 실행
print_header
check_bash
check_git
check_node
check_pnpm
check_path_resolver
check_optional_tools
check_directory_structure
print_summary

# 실패 시 종료 코드 1 반환
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
