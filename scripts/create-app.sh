#!/usr/bin/env bash
set -e

#############################################
# create-app.sh (v4 - Template-based)
# MFE Gateway + Domain Apps generator
#
# Usage:
#   ./scripts/create-app.sh <project-name> <domain1> [domain2 ...] [OPTIONS]
#   ./scripts/create-app.sh myproject order:app:order-list,order-detail
#   ./scripts/create-app.sh myproject order:app:list,detail --git-install
#   ./scripts/create-app.sh myproject order:app:list --output-dir ~/workspace --git-install
#   ./scripts/create-app.sh myproject order:app:list,detail --single-source
#
# Options:
#   --git-install [version]    Install from Git pack repo
#   --output-dir <path>        Create project in specified directory
#   --skip-env-check           Skip environment validation
#   --auto-install             Auto-install missing dependencies
#   --download-version <ver>   Auto-download framework packages
#   --single-source            Generate screens following single-source guide
#
# This version uses @jwsl/templates package for project scaffolding.
#############################################

resolve_script_path() {
  local source_path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$source_path"
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$source_path" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
    return
  fi
  printf '%s\n' "$source_path"
}

find_repo_root() {
  local start_dir="$1"
  local dir="$start_dir"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/pnpm-workspace.yaml" ] || [ -f "$dir/package.json" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

to_pascal_case() {
  # macOS 호환: \U가 BSD sed에서 미지원이므로 awk 사용
  echo "$1" | awk -F'[-_]' '{
    for(i=1;i<=NF;i++) {
      $i = toupper(substr($i,1,1)) substr($i,2)
    }
    printf "%s", $1
    for(i=2;i<=NF;i++) printf "%s", $i
    printf "\n"
  }'
}

#############################################
# 환경 검증
#############################################
detect_os() {
  case "$(uname -s)" in
    Linux*)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu|debian|linuxmint|pop) echo "debian" ;;
          rhel|centos|fedora|rocky|almalinux) echo "rhel" ;;
          arch|manjaro) echo "arch" ;;
          *) echo "linux" ;;
        esac
      else
        echo "linux"
      fi
      ;;
    Darwin*) echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

install_missing_deps() {
  local os_type="$1" missing_git="$2" missing_node="$3" missing_pnpm="$4"
  echo ""
  echo "[AUTO-INSTALL] 누락된 의존성을 설치합니다..."
  case "$os_type" in
    debian)
      [ "$missing_git" = true ] && { echo "[INSTALL] Git..."; sudo apt-get update -qq && sudo apt-get install -y -qq git; }
      [ "$missing_node" = true ] && { echo "[INSTALL] Node.js..."; curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y -qq nodejs; }
      ;;
    rhel)
      [ "$missing_git" = true ] && { echo "[INSTALL] Git..."; sudo dnf install -y -q git || sudo yum install -y -q git; }
      [ "$missing_node" = true ] && { echo "[INSTALL] Node.js..."; curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - && sudo dnf install -y -q nodejs || sudo yum install -y -q nodejs; }
      ;;
    macos)
      if ! command -v brew &>/dev/null; then /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; fi
      [ "$missing_git" = true ] && brew install git
      [ "$missing_node" = true ] && brew install node@22
      ;;
    *) echo "[ERROR] 자동 설치 미지원 OS: $os_type"; return 1 ;;
  esac
  [ "$missing_pnpm" = true ] && {
    echo "[INSTALL] pnpm..."
    if command -v corepack &>/dev/null; then
      sudo corepack enable 2>/dev/null || corepack enable
      corepack prepare pnpm@9.15.4 --activate
    else
      npm install -g pnpm@9.15.4
    fi
  }
  echo "[AUTO-INSTALL] 완료"
}

check_environment() {
  local skip_check="$1" auto_install="$2" script_dir="$3"
  [ "$skip_check" = true ] && { echo "[INFO] 환경 검증 건너뜀"; return 0; }

  echo "[ENV-CHECK] 개발환경 검증 중..."
  local missing_git=false missing_node=false missing_pnpm=false has_errors=false

  if command -v git &>/dev/null; then
    echo "[OK] Git: $(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  else
    echo "[FAIL] Git 미설치"; missing_git=true; has_errors=true
  fi

  if command -v node &>/dev/null; then
    local nv; nv=$(node -v | tr -d 'v')
    local nm; nm=$(echo "$nv" | cut -d. -f1)
    [ "$nm" -ge 18 ] && echo "[OK] Node.js: $nv" || { echo "[FAIL] Node.js: $nv (18+ 필요)"; missing_node=true; has_errors=true; }
  else
    echo "[FAIL] Node.js 미설치"; missing_node=true; has_errors=true
  fi

  if command -v pnpm &>/dev/null; then
    local pv; pv=$(pnpm -v 2>/dev/null)
    local pm; pm=$(echo "$pv" | cut -d. -f1)
    [ "$pm" -ge 8 ] && echo "[OK] pnpm: $pv" || { echo "[FAIL] pnpm: $pv (8+ 필요)"; missing_pnpm=true; has_errors=true; }
  else
    echo "[FAIL] pnpm 미설치"; missing_pnpm=true; has_errors=true
  fi

  if [ "$has_errors" = true ]; then
    if [ "$auto_install" = true ]; then
      install_missing_deps "$(detect_os)" "$missing_git" "$missing_node" "$missing_pnpm"
      check_environment true false "$script_dir"
      return $?
    else
      echo "[ERROR] 필수 의존성 누락. --auto-install 사용 또는 수동 설치 필요."
      exit 1
    fi
  fi
  echo "[ENV-CHECK] OK"
}

#############################################
# 스크립트 경로 및 인자 파싱
#############################################
SCRIPT_PATH_RAW="${BASH_SOURCE[0]}"
SCRIPT_PATH="$(resolve_script_path "$SCRIPT_PATH_RAW")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
WORK_DIR="$(pwd)"

GIT_INSTALL_MODE=false
GIT_INSTALL_VERSION=""
OUTPUT_DIR=""
SKIP_ENV_CHECK=false
AUTO_INSTALL=false
DOWNLOAD_VERSION=""
SINGLE_SOURCE=false
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --git-install)
      GIT_INSTALL_MODE=true
      if [ -n "$2" ] && [[ ! "$2" =~ ^- ]]; then GIT_INSTALL_VERSION="$2"; shift; fi
      shift ;;
    --output-dir)
      [ -z "$2" ] || [[ "$2" =~ ^- ]] && { echo "[ERROR] --output-dir requires path"; exit 1; }
      OUTPUT_DIR="$2"; shift 2 ;;
    --skip-env-check) SKIP_ENV_CHECK=true; shift ;;
    --auto-install) AUTO_INSTALL=true; shift ;;
    --single-source) SINGLE_SOURCE=true; shift ;;
    --download-version)
      [ -z "$2" ] || [[ "$2" =~ ^- ]] && { echo "[ERROR] --download-version requires version"; exit 1; }
      DOWNLOAD_VERSION="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

check_environment "$SKIP_ENV_CHECK" "$AUTO_INSTALL" "$SCRIPT_DIR"

# Find REPO_ROOT
  if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(find_repo_root "$SCRIPT_DIR" || true)"
  [ -z "$REPO_ROOT" ] && REPO_ROOT="$(find_repo_root "$WORK_DIR" || true)"
fi

if [ -z "$OUTPUT_DIR" ] && [ -z "$REPO_ROOT" ]; then
  echo "[ERROR] Cannot find repository root. Use --output-dir or run from repo."
  exit 1
fi

[ -n "$OUTPUT_DIR" ] && echo "[INFO] Standalone mode: OUTPUT_DIR=$OUTPUT_DIR"
[ -z "$OUTPUT_DIR" ] && echo "[INFO] Repository mode: REPO_ROOT=$REPO_ROOT"
[ "$SINGLE_SOURCE" = true ] && echo "[INFO] Single-source mode: screens follow single-source guide"

STANDALONE_NO_REPO=false
[ -n "$OUTPUT_DIR" ] && [ -z "$REPO_ROOT" ] && STANDALONE_NO_REPO=true

set -- "${ARGS[@]}"

if [ ${#ARGS[@]} -lt 2 ]; then
  echo "Usage: $0 <project-name> <domain1[:mode[:screens]]> [domain2 ...] [OPTIONS]"
  echo ""
  echo "Examples:"
  echo "  $0 myproject order:app:order-list,order-detail"
  echo "  $0 myproject order:app:list,detail cart:app:cart-view"
  echo "  $0 myproject order:app:list --output-dir ~/workspace --git-install"
  echo ""
  echo "Options:"
  echo "  --git-install [version]    Install from Git pack repo"
  echo "  --output-dir <path>        Output directory"
  echo "  --skip-env-check           Skip env validation"
  echo "  --auto-install             Auto-install missing deps"
  echo "  --single-source            Generate screens following single-source guide"
  exit 1
fi

PROJECT_NAME="${ARGS[0]}"
RAW_DOMAIN_ARGS=("${ARGS[@]:1}")

RESERVED_DOMAINS=("maintenance" "login" "403" "gateway")
DOMAIN_NAMES=()
DOMAIN_ROUTER_MODES=()
DOMAIN_SCREENS=()
PROXY_DOMAIN_NAMES=()

for arg in "${RAW_DOMAIN_ARGS[@]}"; do
  IFS=':' read -r -a parts <<< "$arg"
  name="${parts[0]}"
  mode="${parts[1]:-app}"
  screens="${parts[2]:-}"

  [[ ! "$name" =~ ^[a-z0-9_-]+$ ]] && { echo "[ERROR] Invalid domain name: $name"; exit 1; }
  for reserved in "${RESERVED_DOMAINS[@]}"; do
    [ "$name" = "$reserved" ] && { echo "[ERROR] Reserved domain name: $name"; exit 1; }
  done

  DOMAIN_NAMES+=("$name")
  DOMAIN_ROUTER_MODES+=("$mode")
  DOMAIN_SCREENS+=("$screens")

  [ "$mode" != "screen" ] && PROXY_DOMAIN_NAMES+=("$name")
done

[[ ! "$PROJECT_NAME" =~ ^[a-z0-9_-]+$ ]] && { echo "[ERROR] Invalid project name: $PROJECT_NAME"; exit 1; }

# Determine project root
if [ -n "$OUTPUT_DIR" ]; then
  [[ "$OUTPUT_DIR" = /* ]] && PROJECT_ROOT="$OUTPUT_DIR/$PROJECT_NAME" || PROJECT_ROOT="$WORK_DIR/$OUTPUT_DIR/$PROJECT_NAME"
  mkdir -p "$(dirname "$PROJECT_ROOT")"
else
  PROJECT_ROOT="$REPO_ROOT/app/$PROJECT_NAME"
fi

if [ -d "$PROJECT_ROOT" ]; then
      if [ -t 0 ]; then
    read -p "[WARNING] $PROJECT_ROOT exists. Delete and recreate? (y/N) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Aborted."; exit 1; }
      rm -rf "$PROJECT_ROOT"
    else
    echo "[ERROR] Directory exists: $PROJECT_ROOT"; exit 1
  fi
fi

mkdir -p "$PROJECT_ROOT"
echo ""
echo "=========================================="
echo " Creating project: $PROJECT_NAME"
echo " Location: $PROJECT_ROOT"
echo "=========================================="
echo ""

#############################################
# Step 1: Download packages (tgz)
#############################################
PACK_DIR="$PROJECT_ROOT/.jw-packs"
mkdir -p "$PACK_DIR"

PACK_REPO_URL="${PACK_REPO_URL:-https://github.com/pharmeath/jw-pack.git}"

download_from_git() {
  local version="$1"
  local target_dir="$2"

  if [ -z "$version" ]; then
    echo "[INFO] 최신 태그 조회 중..."
    version=$(git ls-remote --tags "$PACK_REPO_URL" 2>/dev/null \
      | sed -n 's|.*refs/tags/||p' | grep -v '\^{}' | sort -V | tail -1)
    if [ -z "$version" ]; then
      version=$(git ls-remote --symref "$PACK_REPO_URL" HEAD 2>/dev/null \
        | sed -n 's|.*ref: refs/heads/\(.*\)\tHEAD|\1|p')
      version="${version:-main}"
      echo "[WARN] 태그 없음 → 기본 브랜치: $version"
    else
      echo "[INFO] 최신 태그: $version"
    fi
  fi

  echo "[DOWNLOAD] $PACK_REPO_URL ($version)"
  local tmp_dir; tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" EXIT

  if ! git clone --depth 1 --branch "$version" --progress "$PACK_REPO_URL" "$tmp_dir" 2>&1; then
    echo "[WARN] '$version' 실패 → main으로 fallback..."
    rm -rf "$tmp_dir"; tmp_dir="$(mktemp -d)"
    git clone --depth 1 --branch main --progress "$PACK_REPO_URL" "$tmp_dir" 2>&1 || {
      echo "[ERROR] Git clone 실패: $PACK_REPO_URL"; exit 1
    }
  fi

  [ ! -d "$tmp_dir/.jw-packs" ] && { echo "[ERROR] .jw-packs not found in repo"; exit 1; }

  local count=0
  for f in "$tmp_dir/.jw-packs"/*.tgz; do
    [ -f "$f" ] && { cp "$f" "$target_dir/"; count=$((count + 1)); echo "  ✓ $(basename "$f")"; }
  done
  [ -f "$tmp_dir/.jw-packs/manifest.json" ] && cp "$tmp_dir/.jw-packs/manifest.json" "$target_dir/"

  echo "[DONE] ${count}개 패키지 다운로드 완료"
  rm -rf "$tmp_dir"
  trap - EXIT
}

if [ "$GIT_INSTALL_MODE" = true ]; then
  download_from_git "$GIT_INSTALL_VERSION" "$PACK_DIR"
else
  # Local tgz or auto-download
  LOCAL_PACK="${REPO_ROOT:-.}/.jw-packs"
  if [ -d "$LOCAL_PACK" ] && ls "$LOCAL_PACK"/*.tgz 1>/dev/null 2>&1; then
    echo "[INFO] 로컬 패키지 복사: $LOCAL_PACK → $PACK_DIR"
    cp "$LOCAL_PACK"/*.tgz "$PACK_DIR/"
    [ -f "$LOCAL_PACK/manifest.json" ] && cp "$LOCAL_PACK/manifest.json" "$PACK_DIR/"
  else
    echo "[INFO] 로컬 패키지 없음 → Git에서 다운로드합니다..."
    download_from_git "$DOWNLOAD_VERSION" "$PACK_DIR"
  fi
fi

# Verify packages
TEMPLATES_TGZ=$(ls -1 "$PACK_DIR"/jwsl-templates-*.tgz 2>/dev/null | tail -1)
FRAMEWORK_TGZ=$(ls -1 "$PACK_DIR"/jwsl-framework-*.tgz 2>/dev/null | tail -1)
CORE_TGZ=$(ls -1 "$PACK_DIR"/jwsl-core-*.tgz 2>/dev/null | tail -1)
REACT_TGZ=$(ls -1 "$PACK_DIR"/jwsl-react-*.tgz 2>/dev/null | tail -1)
NEXT_TGZ=$(ls -1 "$PACK_DIR"/jwsl-next-*.tgz 2>/dev/null | tail -1)

if [ -z "$FRAMEWORK_TGZ" ] || [ -z "$CORE_TGZ" ] || [ -z "$REACT_TGZ" ] || [ -z "$NEXT_TGZ" ]; then
  echo "[ERROR] 필수 패키지 누락. 다운로드 상태를 확인하세요."
  ls -la "$PACK_DIR/"
      exit 1
  fi

echo ""
echo "[Step 1] 패키지 준비 완료 ✓"
echo ""

#############################################
# Step 2: Extract templates
#############################################
echo "[Step 2] 템플릿 추출 중..."

TEMPLATES_DIR="$(mktemp -d)"

if [ -n "$TEMPLATES_TGZ" ]; then
  # tgz에서 추출
  tar xzf "$TEMPLATES_TGZ" -C "$TEMPLATES_DIR"
  # npm pack은 package/ 디렉토리 안에 넣음
  if [ -d "$TEMPLATES_DIR/package" ]; then
    TEMPLATES_DIR="$TEMPLATES_DIR/package"
  fi
elif [ -d "$SCRIPT_DIR/../templates" ]; then
  # 프레임워크 디렉토리에서 직접 사용
  TEMPLATES_DIR="$SCRIPT_DIR/../templates"
  echo "[INFO] 로컬 templates 디렉토리 사용: $TEMPLATES_DIR"
else
  echo "[ERROR] @jwsl/templates 패키지를 찾을 수 없습니다."
  echo "publish-framework-release.sh를 실행하여 templates 패키지를 빌드하세요."
  exit 1
fi

[ ! -d "$TEMPLATES_DIR/gateway" ] && { echo "[ERROR] templates/gateway not found"; exit 1; }
[ ! -d "$TEMPLATES_DIR/domain" ] && { echo "[ERROR] templates/domain not found"; exit 1; }

echo "[Step 2] 템플릿 추출 완료 ✓"
echo ""

#############################################
# Step 3: Setup Gateway
#############################################
echo "[Step 3] Gateway 설정 중..."

cp -r "$TEMPLATES_DIR/gateway" "$PROJECT_ROOT/gateway"

# 플레이스홀더 치환 (gateway)
find "$PROJECT_ROOT/gateway" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' -o -name '*.json' -o -name '*.env*' -o -name '*.css' \) | while read -r file; do
  if grep -q '__PROJECT_NAME__' "$file" 2>/dev/null; then
    sed -i '' "s/__PROJECT_NAME__/$PROJECT_NAME/g" "$file"
  fi
done

# .env 파일도 치환 (숨김파일이라 find에서 누락될 수 있음)
for env_file in "$PROJECT_ROOT/gateway"/.env.*; do
  [ -f "$env_file" ] && sed -i '' "s/__PROJECT_NAME__/$PROJECT_NAME/g" "$env_file"
done

echo "  ✓ gateway/ 복사 및 플레이스홀더 치환 완료"
echo ""

#############################################
# Step 4: Setup Domain Apps
#############################################
echo "[Step 4] 업무도메인 앱 설정 중..."

port_idx=0
for idx in "${!DOMAIN_NAMES[@]}"; do
  d="${DOMAIN_NAMES[$idx]}"
  mode="${DOMAIN_ROUTER_MODES[$idx]}"
  screens="${DOMAIN_SCREENS[$idx]}"
  port=$((3101 + port_idx))
  label="$(to_pascal_case "$d")"

  echo "  [$d] mode=$mode, port=$port, screens=$screens"

  # Copy domain template
  cp -r "$TEMPLATES_DIR/domain" "$PROJECT_ROOT/$d"

  # Replace placeholders
  find "$PROJECT_ROOT/$d" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' -o -name '*.json' -o -name '*.env*' -o -name '*.css' -o -name '*.template' \) | while read -r file; do
    sed -i '' \
      -e "s/__PROJECT_NAME__/$PROJECT_NAME/g" \
      -e "s/__DOMAIN_NAME__/$d/g" \
      -e "s/__DOMAIN_LABEL__/$label/g" \
      -e "s/__DOMAIN_PORT__/$port/g" \
      "$file"
  done

  # .env 파일 치환
  for env_file in "$PROJECT_ROOT/$d"/.env.*; do
    [ -f "$env_file" ] && sed -i '' \
      -e "s/__PROJECT_NAME__/$PROJECT_NAME/g" \
      -e "s/__DOMAIN_NAME__/$d/g" \
      -e "s/__DOMAIN_LABEL__/$label/g" \
      -e "s/__DOMAIN_PORT__/$port/g" \
      "$env_file"
  done

  # Rename .env.local.template → .env.local
  [ -f "$PROJECT_ROOT/$d/.env.local.template" ] && mv "$PROJECT_ROOT/$d/.env.local.template" "$PROJECT_ROOT/$d/.env.local"

  # Generate screen files
  if [ -n "$screens" ]; then
    IFS=',' read -r -a screen_arr <<< "$screens"
    first_screen="${screen_arr[0]}"

    # Replace __FIRST_SCREEN__ in page.tsx
    sed -i '' "s/__FIRST_SCREEN__/$first_screen/g" "$PROJECT_ROOT/$d/app/page.tsx"

    # Generate top menus and sidebar menus JSON
    top_menus=""
    sidebar_children=""
    for s in "${screen_arr[@]}"; do
      s_label="$(to_pascal_case "$s")"
      [ -n "$top_menus" ] && top_menus="$top_menus,"
      top_menus="$top_menus
      {
        \"id\": \"$s\",
        \"label\": \"$s_label\",
        \"icon\": \"IconApps\",
        \"path\": \"/$s\",
        \"public\": true
      }"

      [ -n "$sidebar_children" ] && sidebar_children="$sidebar_children,"
      sidebar_children="$sidebar_children
          {
            \"id\": \"$s\",
            \"label\": \"$s_label\",
            \"icon\": \"IconFileText\",
            \"path\": \"/$s\"
          }"
    done

    sidebar_menus="{
        \"id\": \"$d\",
        \"label\": \"$label\",
        \"icon\": \"IconApps\",
        \"path\": \"/$first_screen\",
        \"public\": true,
        \"isParent\": true,
        \"showInDrawer\": true,
        \"children\": [$sidebar_children
        ]
      }"

    # Replace __TOP_MENUS__ and __SIDEBAR_MENUS__ in init.json
    # Use node for reliable JSON replacement
    node -e "
const fs = require('fs');
const p = '$PROJECT_ROOT/$d/public/data/framework/init.json';
let c = fs.readFileSync(p, 'utf8');
c = c.replace('__TOP_MENUS__', \`$top_menus\`);
c = c.replace('__SIDEBAR_MENUS__', \`$sidebar_menus\`);
// Validate JSON
JSON.parse(c);
fs.writeFileSync(p, c);
"

    # Create screen component files + app router pages + mock data
    for s in "${screen_arr[@]}"; do
      s_comp="$(to_pascal_case "$s")"

      mkdir -p "$PROJECT_ROOT/$d/screens/$s"
      mkdir -p "$PROJECT_ROOT/$d/app/$s"
      mkdir -p "$PROJECT_ROOT/$d/public/data/$d/$s"

      if [ "$SINGLE_SOURCE" = true ]; then
        #################################################################
        # Single-Source Guide Mode
        # Follows jw-ui-framework_mfe_single-source-guide.md
        # - 14-section comment structure
        # - @jwsl/framework/hooks, @jwsl/framework/api, @jwsl/framework/icons
        # - @jwsl/ui/mantine for UI components
        # - @jwsl/core for router
        # - Button buttonDiv pattern
        # - Content-area only (Stack root, no Container)
        #################################################################
        s_lower="$(echo "$s_comp" | awk '{print tolower(substr($0,1,1)) substr($0,2)}')"
        create_date="$(date +%Y-%m-%d)"

        # Screen component: Single-source CRUD List Page
        cat > "$PROJECT_ROOT/$d/screens/$s/${s_comp}Page.tsx" <<SCREEN_EOF
/********************************************************
 * 1. 화면프로그램 jsDoc
 * 화면명 : ${s_comp}
 * 화면ID : SCR-${s_comp}-001
 * 프로그램ID : ${s_comp}Page
 * 작성일자 : ${create_date}
 * 작성자 :
 * 화면 설명 : ${s_comp} CRUD 목록 화면
 * 유의사항 : 삭제 시 확인 모달 필수
 ********************************************************/

/********************************************************
 * 2. 이력 영역
 * ${create_date} v1.0 최초 작성
 ********************************************************/

/********************************************************
 * 3. import 영역
 ********************************************************/
'use client';

import {
  useFormState, useListState, useToggle,
  useApiRequest, useMount, useUpdateEffect,
  useNotification, useCommonCode,
} from '@jwsl/framework/hooks';
import { useRouter } from '@jwsl/core';
import { api } from '@jwsl/framework/api';
import { Alert, Paper, Title, Group, Stack, Badge, Modal, Text } from '@jwsl/ui/mantine';
import { Button, Table, TextInput, Select, Pagination } from '@jwsl/ui/mantine';
import { IconSearch } from '@jwsl/framework/icons';

/********************************************************
 * 4. 글로벌 선언 영역
 ********************************************************/

/********************************************************
 * 5. TYPE 정의 영역
 ********************************************************/

/** ${s_comp} 엔티티 */
interface ${s_comp}Item {
  id: string;
  title: string;
  status: string;
  createdAt: string;
}

/** 목록 조회 응답 */
interface ${s_comp}ListResponse {
  items: ${s_comp}Item[];
  totalCount: number;
  page: number;
  size: number;
}

/********************************************************
 * 6. API 정의 영역
 ********************************************************/

const ${s_lower}Api = {
  basePath: '/${d}/${s}',

  getList: (params: { page: number; size: number; keyword?: string; status?: string }) =>
    api.get<${s_comp}ListResponse>('/${d}/${s}/list', { params }),

  delete: (id: string) =>
    api.delete('/${d}/${s}/' + id),
};

/********************************************************
 * 7. SERVICE 영역 (순수 함수)
 ********************************************************/

const ${s_lower}Service = {
  getStatusLabel: (status: string): string => {
    const labels: Record<string, string> = {
      ACTIVE: '활성',
      INACTIVE: '비활성',
      DRAFT: '임시저장',
    };
    return labels[status] ?? status;
  },

  getStatusColor: (status: string): string => {
    const colors: Record<string, string> = {
      ACTIVE: 'green',
      INACTIVE: 'gray',
      DRAFT: 'yellow',
    };
    return colors[status] ?? 'gray';
  },

  formatDate: (dateString: string): string => {
    return new Date(dateString).toLocaleDateString('ko-KR');
  },
};

/********************************************************
 * 8. HOOK 영역 (커스텀 훅)
 ********************************************************/

/********************************************************
 * 9. 컴포넌트 시작
 ********************************************************/

export default function ${s_comp}Page() {
  const { navigate } = useRouter();
  const notify = useNotification();
  const statuses = useCommonCode('STATUS', { includeAll: true });

  /********************************************************
   * 10. STATE 선언 영역
   ********************************************************/

  const filter = useFormState({
    initialValues: {
      page: 1,
      size: 10,
      keyword: '',
      status: '',
    },
  });

  const selectedIds = useListState<string>([]);
  const [isDeleteOpen, deleteModal] = useToggle(false);

  /********************************************************
   * 11. 화면초기화 영역 (API 자동 조회)
   ********************************************************/

  /** 목록 조회 */
  const listQuery = useApiRequest<${s_comp}ListResponse>({
    requestFn: () => ${s_lower}Api.getList(filter.values),
  });

  useMount(() => {
    listQuery.execute();
  });

  useUpdateEffect(() => {
    listQuery.execute();
  }, [filter.values.page, filter.values.status]);

  /** 삭제 API */
  const deleteMutation = useApiRequest({
    requestFn: () => Promise.all(selectedIds.state.map((id) => ${s_lower}Api.delete(id))),
    onSuccess: () => {
      notify.success('삭제되었습니다.');
      selectedIds.setState([]);
      listQuery.execute();
      deleteModal.setFalse();
    },
    onError: (error) => {
      notify.error(error.message);
    },
  });

  /********************************************************
   * 12. 필수 FUNCTION 영역 (CRUD)
   ********************************************************/

  /** handleSearch - 조회 */
  const handleSearch = () => {
    filter.setValue('page', 1);
    listQuery.execute();
  };

  /** handleCreate - 등록 화면 이동 */
  const handleCreate = () => {
    navigate('/${s}/create');
  };

  /** handleDelete - 삭제 */
  const handleDelete = () => {
    if (selectedIds.state.length === 0) {
      notify.warning('삭제할 항목을 선택해주세요.');
      return;
    }
    deleteModal.setTrue();
  };

  /** handleReset - 초기화 */
  const handleReset = () => {
    filter.reset();
    selectedIds.setState([]);
    listQuery.execute();
  };

  /********************************************************
   * 13. 사용자 FUNCTION 영역
   ********************************************************/

  const handleRowClick = (id: string) => {
    navigate('/${s}/' + id);
  };

  const handleRowSelect = (id: string, checked: boolean) => {
    if (checked) {
      selectedIds.append(id);
    } else {
      selectedIds.filter((item) => item !== id);
    }
  };

  /********************************************************
   * 14. RENDER
   ********************************************************/

  return (
    <Stack gap="md">
      {/* 버튼 영역 */}
      <Paper p="md" withBorder>
        <Group justify="flex-end">
          <Button buttonDiv="refresh" onClick={handleReset} />
          <Button buttonDiv="search" onClick={handleSearch} loading={listQuery.isLoading} />
          <Button buttonDiv="create" onClick={handleCreate} />
          <Button buttonDiv="delete" onClick={handleDelete} disabled={selectedIds.state.length === 0} />
        </Group>
      </Paper>

      {/* 조회 조건 영역 */}
      <Paper p="md" withBorder>
        <Title order={4} mb="md">조회 조건</Title>
        <Group align="flex-end">
          <TextInput
            label="검색"
            placeholder="검색어를 입력하세요"
            value={filter.values.keyword}
            onChange={(e) => filter.setValue('keyword', e.target.value)}
            leftSection={<IconSearch size={16} />}
            style={{ flex: 1 }}
          />
          <Select
            label="상태"
            data={statuses}
            value={filter.values.status}
            onChange={(value) => filter.setValue('status', value || '')}
            style={{ width: 150 }}
          />
        </Group>
      </Paper>

      {/* 목록 영역 */}
      <Paper p="md" withBorder>
        <Group justify="space-between" mb="md">
          <Title order={4}>${s_comp} 목록</Title>
          <Group gap="xs">
            <Badge color="blue">총 {listQuery.data?.totalCount ?? 0}건</Badge>
            <Badge color="green">선택 {selectedIds.state.length}건</Badge>
          </Group>
        </Group>

        {listQuery.error ? (
          <Alert color="red" variant="light" title="조회 실패">
            {listQuery.error.message}
            <Button variant="light" size="xs" mt="sm" onClick={() => listQuery.execute()}>
              재시도
            </Button>
          </Alert>
        ) : (
        <Table
          data={listQuery.data?.items ?? []}
          loading={listQuery.isLoading}
          selectable
          selectedIds={selectedIds.state}
          onSelect={handleRowSelect}
          columns={[
            { key: 'title', header: '제목' },
            {
              key: 'status',
              header: '상태',
              render: (row) => (
                <Badge color={${s_lower}Service.getStatusColor(row.status)}>
                  {${s_lower}Service.getStatusLabel(row.status)}
                </Badge>
              ),
            },
            {
              key: 'createdAt',
              header: '등록일',
              render: (row) => ${s_lower}Service.formatDate(row.createdAt),
            },
          ]}
          onRowClick={(row) => handleRowClick(row.id)}
        />
        )}

        <Pagination
          total={Math.ceil((listQuery.data?.totalCount ?? 0) / filter.values.size)}
          value={filter.values.page}
          onChange={(page) => filter.setValue('page', page)}
          mt="md"
        />
      </Paper>

      {/* 삭제 확인 모달 */}
      <Modal opened={isDeleteOpen} onClose={() => deleteModal.setFalse()} title="삭제 확인">
        <Text>{selectedIds.state.length}건을 삭제하시겠습니까?</Text>
        <Group mt="md" justify="flex-end">
          <Button variant="outline" onClick={() => deleteModal.setFalse()}>취소</Button>
          <Button color="red" loading={deleteMutation.isLoading} onClick={() => deleteMutation.execute()}>
            삭제
          </Button>
        </Group>
      </Modal>
    </Stack>
  );
}
SCREEN_EOF

        # Public API (index.ts)
        cat > "$PROJECT_ROOT/$d/screens/$s/index.ts" <<INDEX_EOF
export { default as ${s_comp}Page } from './${s_comp}Page';
INDEX_EOF

        # App router page
        cat > "$PROJECT_ROOT/$d/app/$s/page.tsx" <<PAGE_EOF
'use client';

import { ${s_comp}Page } from '@/screens/$s';

export default function Page() {
  return <${s_comp}Page />;
}
PAGE_EOF

      else
        #################################################################
        # Default Mode (existing behavior)
        #################################################################

        # Screen component
        cat > "$PROJECT_ROOT/$d/screens/$s/${s_comp}.tsx" <<SCREEN_EOF
'use client';

import { useFormState, useToggle, useMemo, useCallback, useMount, useUpdateEffect, useApiRequest } from '@jwsl/lib/hooks';
import { useRouter } from '@jwsl/core';
import { api } from '@jwsl/framework/api';
import {
  Alert, Container, Title, Group, TextInput, Button, Table, Text,
  Stack, Paper, Badge, Loader, Center
} from '@jwsl/ui/mantine';
import { IconSearch, IconPlus, IconRefresh } from '@jwsl/icons';

interface ${s_comp}Item {
  id: string;
  title: string;
  status: string;
  createdAt: string;
}

interface ${s_comp}ListResponse {
  items: ${s_comp}Item[];
  totalCount: number;
}

/**
 * ${s_comp} Screen
 */
export default function ${s_comp}() {
  const router = useRouter();

  const filter = useFormState({
    initialValues: {
      keyword: '',
      page: 1,
      size: 10,
    },
  });

  const [isSearching, searchHandlers] = useToggle(false);

  const listQuery = useApiRequest<${s_comp}ListResponse>({
    requestFn: () => api.get('/${d}/${s}/list', { params: filter.values }),
  });

  useMount(() => {
    listQuery.execute();
  });

  useUpdateEffect(() => {
    listQuery.execute();
  }, [filter.values.page]);

  const handleSearch = useCallback(() => {
    searchHandlers.setTrue();
    filter.setValue('page', 1);
    listQuery.execute().finally(() => searchHandlers.setFalse());
  }, [filter, listQuery, searchHandlers]);

  const columns = useMemo(() => [
    {
      key: 'id',
      title: 'ID',
      width: 80,
    },
    {
      key: 'title',
      title: '제목',
      render: (value: string, row: ${s_comp}Item) => (
        <Text
          size="sm"
          c="blue"
          style={{ cursor: 'pointer' }}
          onClick={() => router.push('/${s}/' + row.id)}
        >
          {value}
        </Text>
      ),
    },
    {
      key: 'status',
      title: '상태',
      width: 100,
      render: (value: string) => (
        <Badge color={value === 'ACTIVE' ? 'green' : 'gray'} variant="light">
          {value}
        </Badge>
      ),
    },
    {
      key: 'createdAt',
      title: '등록일',
      width: 120,
    },
  ], [router]);

  return (
    <Container size="xl" py="md">
      <Stack gap="md">
        <Group justify="space-between">
          <Title order={3}>${s_comp}</Title>
          <Button leftSection={<IconPlus size={16} />} onClick={() => router.push('/${s}/new')}>
            신규 등록
          </Button>
        </Group>

        <Paper p="md" withBorder>
          <Group>
            <TextInput
              placeholder="검색어 입력"
              value={filter.values.keyword}
              onChange={(e) => filter.setValue('keyword', e.target.value)}
              leftSection={<IconSearch size={16} />}
              style={{ flex: 1 }}
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
            />
            <Button onClick={handleSearch} loading={isSearching}>
              검색
            </Button>
            <Button variant="outline" leftSection={<IconRefresh size={16} />} onClick={() => { filter.reset(); listQuery.execute(); }}>
              초기화
            </Button>
          </Group>
        </Paper>

        {listQuery.isLoading ? (
          <Center py="xl"><Loader /></Center>
        ) : listQuery.error ? (
          <Alert color="red" variant="light" title="조회 실패">
            {listQuery.error.message}
            <Button variant="light" size="xs" mt="sm" onClick={() => listQuery.execute()}>
              재시도
            </Button>
          </Alert>
        ) : (
          <Table
            data={listQuery.data?.items ?? []}
            columns={columns}
          />
        )}
      </Stack>
    </Container>
  );
}
SCREEN_EOF

        # App router page
        cat > "$PROJECT_ROOT/$d/app/$s/page.tsx" <<PAGE_EOF
'use client';

import ${s_comp} from '@/screens/$s/${s_comp}';

export default function Page() {
  return <${s_comp} />;
}
PAGE_EOF

      fi

      # Mock data file (shared for both modes)
      cat > "$PROJECT_ROOT/$d/public/data/$d/$s/list.json" <<DATA_EOF
{
  "items": [
    { "id": "1", "title": "${s_comp} Item 1", "status": "ACTIVE", "createdAt": "2026-01-01" },
    { "id": "2", "title": "${s_comp} Item 2", "status": "ACTIVE", "createdAt": "2026-01-02" },
    { "id": "3", "title": "${s_comp} Item 3", "status": "INACTIVE", "createdAt": "2026-01-03" }
  ],
  "totalCount": 3,
  "page": 1,
  "size": 10
}
DATA_EOF

      if [ "$SINGLE_SOURCE" = true ]; then
        echo "    ✓ screen (single-source): $s (${s_comp}Page.tsx)"
      else
        echo "    ✓ screen: $s ($s_comp)"
      fi
    done

    #################################################################
    # Single-Source: 화장품 쇼핑몰 상품진열/상품상세 화면 자동 생성
    #################################################################
    if [ "$SINGLE_SOURCE" = true ]; then
      create_date="$(date +%Y-%m-%d)"

      echo "    [상품 화면 자동 생성 중...]"

      # ── 상품 진열 화면 (ProductListPage) ──
      mkdir -p "$PROJECT_ROOT/$d/screens/product-list"
      mkdir -p "$PROJECT_ROOT/$d/app/product-list"
      mkdir -p "$PROJECT_ROOT/$d/public/data/$d/product"

      cat > "$PROJECT_ROOT/$d/screens/product-list/ProductListPage.tsx" <<'PRODLIST_EOF'
/********************************************************
 * 1. 화면프로그램 jsDoc
 * 화면명 : 상품 진열
 * 화면ID : SCR-PRODUCT-001
 * 프로그램ID : ProductListPage
PRODLIST_EOF

      # Continue with variable-expanded portion
      cat >> "$PROJECT_ROOT/$d/screens/product-list/ProductListPage.tsx" <<PRODLIST2_EOF
 * 작성일자 : ${create_date}
 * 작성자 :
 * 화면 설명 : 화장품 쇼핑몰 상품 진열 (카드 그리드)
 * 유의사항 : 이미지 로딩 실패 시 폴백 이미지 표시
 ********************************************************/

/********************************************************
 * 2. 이력 영역
 * ${create_date} v1.0 최초 작성
 ********************************************************/

/********************************************************
 * 3. import 영역
 ********************************************************/
'use client';

import {
  useFormState, useToggle,
  useApiRequest, useMount, useUpdateEffect,
  useNotification, useCommonCode,
  useMemo, useCallback,
} from '@jwsl/framework/hooks';
import { useRouter } from '@jwsl/core';
import { api } from '@jwsl/framework/api';
import {
  Alert, Paper, Title, Group, Stack, Badge, Text, Image, Box,
  SimpleGrid, Card, Skeleton, NumberFormatter,
} from '@jwsl/ui/mantine';
import { Button, TextInput, Select, Pagination } from '@jwsl/ui/mantine';
import { IconSearch, IconShoppingCart, IconHeart, IconStar } from '@jwsl/framework/icons';

/********************************************************
 * 4. 글로벌 선언 영역
 ********************************************************/

const FALLBACK_IMAGE = 'https://picsum.photos/seed/fallback/600/600';

/********************************************************
 * 5. TYPE 정의 영역
 ********************************************************/

/** 상품 엔티티 */
interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  stock: number;
  category: string;
  brand: string;
  rating: number;
  reviewCount: number;
  imageUrl: string;
  isActive: boolean;
}

/** 상품 목록 응답 */
interface ProductListResponse {
  items: Product[];
  totalCount: number;
  page: number;
  size: number;
}

/********************************************************
 * 6. API 정의 영역
 ********************************************************/

/********************************************************
 * 7. SERVICE 영역 (순수 함수)
 ********************************************************/

const productService = {
  formatPrice: (price: number): string => {
    return new Intl.NumberFormat('ko-KR').format(price) + '원';
  },

  getCategoryLabel: (category: string): string => {
    const labels: Record<string, string> = {
      SKINCARE: '스킨케어',
      MAKEUP: '메이크업',
      SUNCARE: '선케어',
      CLEANSING: '클렌징',
      MASK: '마스크팩',
      BODYCARE: '바디케어',
      HAIRCARE: '헤어케어',
      PERFUME: '향수',
    };
    return labels[category] ?? category;
  },

  getCategoryColor: (category: string): string => {
    const colors: Record<string, string> = {
      SKINCARE: 'teal',
      MAKEUP: 'pink',
      SUNCARE: 'yellow',
      CLEANSING: 'cyan',
      MASK: 'violet',
      BODYCARE: 'orange',
      HAIRCARE: 'lime',
      PERFUME: 'grape',
    };
    return colors[category] ?? 'gray';
  },

  renderStars: (rating: number): string => {
    return '★'.repeat(Math.floor(rating)) + (rating % 1 >= 0.5 ? '½' : '');
  },
};

/********************************************************
 * 8. HOOK 영역 (커스텀 훅)
 ********************************************************/

/********************************************************
 * 9. 컴포넌트 시작
 ********************************************************/

export default function ProductListPage() {
  const { navigate } = useRouter();
  const notify = useNotification();
  const categories = useCommonCode('PRODUCT_CATEGORY', { includeAll: true });

  /********************************************************
   * 10. STATE 선언 영역
   ********************************************************/

  const filter = useFormState({
    initialValues: {
      page: 1,
      size: 12,
      keyword: '',
      category: '',
    },
  });

  /********************************************************
   * 11. 화면초기화 영역 (API 자동 조회)
   ********************************************************/

  const listQuery = useApiRequest<ProductListResponse>({
    requestFn: () => api.get('/${d}/product/list', { params: filter.values }),
  });

  useMount(() => {
    listQuery.execute();
  });

  useUpdateEffect(() => {
    listQuery.execute();
  }, [filter.values.page, filter.values.category]);

  /********************************************************
   * 12. 필수 FUNCTION 영역 (CRUD)
   ********************************************************/

  /** handleSearch - 조회 */
  const handleSearch = () => {
    filter.setValue('page', 1);
    listQuery.execute();
  };

  /** handleReset - 초기화 */
  const handleReset = () => {
    filter.reset();
    listQuery.execute();
  };

  /********************************************************
   * 13. 사용자 FUNCTION 영역
   ********************************************************/

  const handleProductClick = useCallback((id: number) => {
    navigate('/product-detail/' + id);
  }, [navigate]);

  const handleAddToCart = useCallback((product: Product) => {
    notify.success(product.name + ' 장바구니에 추가되었습니다.');
  }, [notify]);

  /********************************************************
   * 14. RENDER
   ********************************************************/

  const products = listQuery.data?.items ?? [];
  const totalCount = listQuery.data?.totalCount ?? 0;

  return (
      <Stack gap="md">
      {/* 검색 영역 */}
      <Paper p="md" withBorder>
        <Group align="flex-end">
          <TextInput
            label="상품 검색"
            placeholder="상품명, 브랜드 검색"
            value={filter.values.keyword}
            onChange={(e) => filter.setValue('keyword', e.target.value)}
            leftSection={<IconSearch size={16} />}
            style={{ flex: 1 }}
            onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
          />
          <Select
            label="카테고리"
            data={categories}
            value={filter.values.category}
            onChange={(value) => filter.setValue('category', value || '')}
            style={{ width: 160 }}
          />
          <Button buttonDiv="search" onClick={handleSearch} loading={listQuery.isLoading} />
          <Button buttonDiv="refresh" onClick={handleReset} />
        </Group>
      </Paper>

      {/* 상품 수 + 정렬 */}
      <Group justify="space-between">
        <Text size="sm" c="dimmed">
          총 <Text span fw={700} c="dark">{totalCount}</Text>개 상품
        </Text>
      </Group>

      {/* 상품 카드 그리드 */}
      {listQuery.isLoading ? (
        <SimpleGrid cols={{ base: 1, xs: 2, sm: 3, lg: 4 }} spacing="md">
          {Array.from({ length: 8 }).map((_, i) => (
            <Card key={i} padding="sm" withBorder>
              <Skeleton height={200} mb="sm" />
              <Skeleton height={12} mb={4} />
              <Skeleton height={12} width="60%" mb={8} />
              <Skeleton height={20} width="40%" />
            </Card>
          ))}
        </SimpleGrid>
      ) : listQuery.error ? (
        <Alert color="red" variant="light" title="조회 실패">
          {listQuery.error.message}
          <Button variant="light" size="xs" mt="sm" onClick={() => listQuery.execute()}>
            재시도
          </Button>
        </Alert>
      ) : (
        <SimpleGrid cols={{ base: 1, xs: 2, sm: 3, lg: 4 }} spacing="md">
          {products.map((product) => (
            <Card
              key={product.id}
              padding="sm"
              withBorder
              style={{ cursor: 'pointer', transition: 'box-shadow 0.2s' }}
              onClick={() => handleProductClick(product.id)}
            >
              <Card.Section>
                <Image
                  src={product.imageUrl}
                  height={220}
                  alt={product.name}
                  fallbackSrc={FALLBACK_IMAGE}
                />
              </Card.Section>

              <Stack gap={4} mt="sm">
                <Group justify="space-between" gap={4}>
                  <Badge
                    size="xs"
                    variant="light"
                    color={productService.getCategoryColor(product.category)}
                  >
                    {productService.getCategoryLabel(product.category)}
                  </Badge>
                  <Text size="xs" c="dimmed">{product.brand}</Text>
                </Group>

                <Text size="sm" fw={500} lineClamp={2} style={{ minHeight: 40 }}>
                  {product.name}
        </Text>

                <Group gap={4} align="center">
                  <Text size="xs" c="yellow.7">
                    <IconStar size={12} style={{ verticalAlign: 'middle' }} /> {product.rating}
                  </Text>
                  <Text size="xs" c="dimmed">({product.reviewCount})</Text>
                </Group>

                <Group justify="space-between" align="center" mt={4}>
                  <Text size="lg" fw={700} c="dark">
                    <NumberFormatter value={product.price} thousandSeparator suffix="원" />
                  </Text>
                  <Button
                    variant="light"
                    size="xs"
                    leftSection={<IconShoppingCart size={14} />}
                    onClick={(e) => { e.stopPropagation(); handleAddToCart(product); }}
                  >
                    담기
                  </Button>
                </Group>

                {product.stock <= 10 && product.stock > 0 && (
                  <Text size="xs" c="red">재고 {product.stock}개 남음</Text>
                )}
                {product.stock === 0 && (
                  <Badge color="red" variant="filled" size="sm">품절</Badge>
                )}
              </Stack>
            </Card>
          ))}
        </SimpleGrid>
      )}

      {/* 페이지네이션 */}
      {totalCount > filter.values.size && (
        <Group justify="center" mt="md">
          <Pagination
            total={Math.ceil(totalCount / filter.values.size)}
            value={filter.values.page}
            onChange={(page) => filter.setValue('page', page)}
          />
        </Group>
      )}
    </Stack>
  );
}
PRODLIST2_EOF

      # index.ts
      cat > "$PROJECT_ROOT/$d/screens/product-list/index.ts" <<'PRODLISTIDX_EOF'
export { default as ProductListPage } from './ProductListPage';
PRODLISTIDX_EOF

      # App router page
      cat > "$PROJECT_ROOT/$d/app/product-list/page.tsx" <<'PRODLISTPAGE_EOF'
'use client';

import { ProductListPage } from '@/screens/product-list';

export default function Page() {
  return <ProductListPage />;
}
PRODLISTPAGE_EOF

      echo "    ✓ screen (single-source): product-list (ProductListPage.tsx) [쇼핑몰 상품진열]"

      # ── 상품 상세 화면 (ProductDetailPage) ──
      mkdir -p "$PROJECT_ROOT/$d/screens/product-detail"
      mkdir -p "$PROJECT_ROOT/$d/app/product-detail/[id]"

      cat > "$PROJECT_ROOT/$d/screens/product-detail/ProductDetailPage.tsx" <<'PRODDETAIL_EOF'
/********************************************************
 * 1. 화면프로그램 jsDoc
 * 화면명 : 상품 상세
 * 화면ID : SCR-PRODUCT-002
 * 프로그램ID : ProductDetailPage
PRODDETAIL_EOF

      cat >> "$PROJECT_ROOT/$d/screens/product-detail/ProductDetailPage.tsx" <<PRODDETAIL2_EOF
 * 작성일자 : ${create_date}
 * 작성자 :
 * 화면 설명 : 화장품 상품 상세 정보 (이미지, 설명, 리뷰)
 * 유의사항 : 이미지 갤러리, 장바구니 추가 기능 포함
 ********************************************************/

/********************************************************
 * 2. 이력 영역
 * ${create_date} v1.0 최초 작성
 ********************************************************/

/********************************************************
 * 3. import 영역
 ********************************************************/
'use client';

import {
  useFormState, useToggle,
  useApiRequest, useMount,
  useNotification,
  useMemo,
} from '@jwsl/framework/hooks';
import { useRouter, useParams } from '@jwsl/core';
import { api } from '@jwsl/framework/api';
import {
  Paper, Title, Group, Stack, Badge, Text, Image, Box, Divider,
  SimpleGrid, Card, Skeleton, NumberFormatter, Rating, Tabs, Spoiler,
} from '@jwsl/ui/mantine';
import { Button } from '@jwsl/ui/mantine';
import {
  IconShoppingCart, IconHeart, IconTruck, IconShieldCheck,
  IconRefresh, IconStar, IconArrowLeft,
} from '@jwsl/framework/icons';

/********************************************************
 * 4. 글로벌 선언 영역
 ********************************************************/

const FALLBACK_IMAGE = 'https://picsum.photos/seed/fallback/600/600';

/********************************************************
 * 5. TYPE 정의 영역
 ********************************************************/

/** 상품 상세 엔티티 */
interface ProductDetail {
  id: number;
  name: string;
  description: string;
  price: number;
  stock: number;
  category: string;
  brand: string;
  rating: number;
  reviewCount: number;
  imageUrl: string;
  images: string[];
  isActive: boolean;
  ingredients?: string;
  howToUse?: string;
  volume?: string;
  createdAt: string;
}

/********************************************************
 * 6. API 정의 영역
 ********************************************************/

const productApi = {
  getDetail: (id: string) =>
    api.get<ProductDetail>('/${d}/product/' + id),

  addToCart: (productId: number, quantity: number) =>
    api.post('/${d}/cart/add', { productId, quantity }),
};

/********************************************************
 * 7. SERVICE 영역 (순수 함수)
 ********************************************************/

const productService = {
  formatPrice: (price: number): string => {
    return new Intl.NumberFormat('ko-KR').format(price) + '원';
  },

  getCategoryLabel: (category: string): string => {
    const labels: Record<string, string> = {
      SKINCARE: '스킨케어',
      MAKEUP: '메이크업',
      SUNCARE: '선케어',
      CLEANSING: '클렌징',
      MASK: '마스크팩',
      BODYCARE: '바디케어',
      HAIRCARE: '헤어케어',
      PERFUME: '향수',
    };
    return labels[category] ?? category;
  },

  getCategoryColor: (category: string): string => {
    const colors: Record<string, string> = {
      SKINCARE: 'teal',
      MAKEUP: 'pink',
      SUNCARE: 'yellow',
      CLEANSING: 'cyan',
      MASK: 'violet',
      BODYCARE: 'orange',
      HAIRCARE: 'lime',
      PERFUME: 'grape',
    };
    return colors[category] ?? 'gray';
  },
};

/********************************************************
 * 8. HOOK 영역 (커스텀 훅)
 ********************************************************/

/********************************************************
 * 9. 컴포넌트 시작
 ********************************************************/

export default function ProductDetailPage() {
  const { navigate, back } = useRouter();
  const { id } = useParams();
  const notify = useNotification();

  /********************************************************
   * 10. STATE 선언 영역
   ********************************************************/

  const quantity = useFormState({
    initialValues: { count: 1 },
  });

  const [selectedImageIdx, imageHandlers] = useToggle(false);
  const [isWished, wishHandlers] = useToggle(false);

  /********************************************************
   * 11. 화면초기화 영역 (API 자동 조회)
   ********************************************************/

  const detailQuery = useApiRequest<ProductDetail>({
    requestFn: () => productApi.getDetail(id as string),
  });

  useMount(() => {
    if (id) {
      detailQuery.execute();
    }
  });

  /** 장바구니 추가 API */
  const addToCartMutation = useApiRequest({
    requestFn: () => productApi.addToCart(
      detailQuery.data?.id ?? 0,
      quantity.values.count,
    ),
    onSuccess: () => {
      notify.success('장바구니에 추가되었습니다.');
    },
    onError: (error) => {
      notify.error(error.message);
    },
  });

  /********************************************************
   * 12. 필수 FUNCTION 영역 (CRUD)
   ********************************************************/

  /** handleAddToCart - 장바구니 추가 */
  const handleAddToCart = () => {
    if (!detailQuery.data) return;
    if (detailQuery.data.stock === 0) {
      notify.warning('품절된 상품입니다.');
      return;
    }
    addToCartMutation.execute();
  };

  /** handleBuyNow - 바로구매 */
  const handleBuyNow = () => {
    if (!detailQuery.data) return;
    notify.info('주문 페이지로 이동합니다.');
  };

  /********************************************************
   * 13. 사용자 FUNCTION 영역
   ********************************************************/

  const handleQuantityChange = (delta: number) => {
    const current = quantity.values.count;
    const max = detailQuery.data?.stock ?? 99;
    const next = Math.max(1, Math.min(max, current + delta));
    quantity.setValue('count', next);
  };

  const handleWishToggle = () => {
    wishHandlers.toggle();
    notify.success(isWished ? '위시리스트에서 제거되었습니다.' : '위시리스트에 추가되었습니다.');
  };

  /********************************************************
   * 14. RENDER
   ********************************************************/

  const product = detailQuery.data;

  if (detailQuery.isLoading) {
    return (
      <Stack gap="md">
        <SimpleGrid cols={{ base: 1, md: 2 }} spacing="xl">
          <Skeleton height={500} />
          <Stack gap="md">
            <Skeleton height={24} width="30%" />
            <Skeleton height={32} />
            <Skeleton height={20} width="40%" />
            <Skeleton height={100} />
            <Skeleton height={48} />
          </Stack>
        </SimpleGrid>
      </Stack>
    );
  }

  if (!product) {
    return (
      <Paper p="xl" withBorder ta="center">
        <Text size="lg" c="dimmed">상품 정보를 찾을 수 없습니다.</Text>
        <Button mt="md" variant="outline" onClick={() => navigate('/product-list')}>
          상품 목록으로
        </Button>
      </Paper>
    );
  }

  const allImages = product.images?.length > 0
    ? product.images
    : [product.imageUrl, product.imageUrl + '?v=2', product.imageUrl + '?v=3'];

  return (
    <Stack gap="lg">
      {/* 뒤로가기 */}
      <Group>
        <Button variant="subtle" leftSection={<IconArrowLeft size={16} />} onClick={() => back()}>
          상품 목록
        </Button>
      </Group>

      {/* 메인 영역: 이미지 + 정보 */}
      <SimpleGrid cols={{ base: 1, md: 2 }} spacing="xl">
        {/* 이미지 영역 */}
        <Stack gap="sm">
          <Paper withBorder radius="md" style={{ overflow: 'hidden' }}>
            <Image
              src={allImages[0]}
              height={500}
              alt={product.name}
              fallbackSrc={FALLBACK_IMAGE}
              fit="cover"
            />
          </Paper>
          {/* 서브 이미지 */}
          <Group gap="sm">
            {allImages.slice(0, 4).map((img, idx) => (
              <Paper
                key={idx}
                withBorder
                radius="sm"
                style={{
                  overflow: 'hidden',
                  cursor: 'pointer',
                  opacity: idx === 0 ? 1 : 0.7,
                  width: 80,
                  height: 80,
                }}
              >
                <Image src={img} height={80} width={80} alt="" fallbackSrc={FALLBACK_IMAGE} fit="cover" />
              </Paper>
            ))}
          </Group>
        </Stack>

        {/* 상품 정보 영역 */}
        <Stack gap="md">
          <Group gap="xs">
            <Badge
              variant="light"
              color={productService.getCategoryColor(product.category)}
            >
              {productService.getCategoryLabel(product.category)}
            </Badge>
            <Text size="sm" c="dimmed">{product.brand}</Text>
          </Group>

          <Title order={2}>{product.name}</Title>

          <Group gap="xs" align="center">
            <Rating value={product.rating} fractions={2} readOnly size="sm" />
            <Text size="sm" c="dimmed">
              {product.rating} ({product.reviewCount}개 리뷰)
            </Text>
          </Group>

          <Divider />

          <Group align="baseline" gap="xs">
            <Text size="xl" fw={800} style={{ fontSize: 28 }}>
              <NumberFormatter value={product.price} thousandSeparator />
            </Text>
            <Text size="lg" fw={500}>원</Text>
          </Group>

          <Spoiler maxHeight={80} showLabel="더보기" hideLabel="접기">
            <Text size="sm" c="dimmed" style={{ lineHeight: 1.6 }}>
              {product.description}
            </Text>
          </Spoiler>

          <Divider />

          {/* 수량 선택 */}
          <Group gap="sm" align="center">
            <Text size="sm" fw={500}>수량</Text>
            <Group gap={4}>
              <Button variant="default" size="xs" onClick={() => handleQuantityChange(-1)}>-</Button>
              <Text size="sm" fw={600} w={40} ta="center">{quantity.values.count}</Text>
              <Button variant="default" size="xs" onClick={() => handleQuantityChange(1)}>+</Button>
            </Group>
            {product.stock <= 10 && product.stock > 0 && (
              <Text size="xs" c="red">재고 {product.stock}개</Text>
            )}
          </Group>

          {/* 총 금액 */}
          <Paper p="md" bg="gray.0" radius="md">
            <Group justify="space-between">
              <Text size="sm">총 상품금액</Text>
              <Text size="xl" fw={800} c="blue">
                <NumberFormatter value={product.price * quantity.values.count} thousandSeparator suffix="원" />
              </Text>
            </Group>
          </Paper>

          {/* 액션 버튼 */}
          <Group grow>
            <Button
              variant="outline"
              size="lg"
              leftSection={<IconHeart size={20} fill={isWished ? 'currentColor' : 'none'} />}
              color={isWished ? 'red' : 'gray'}
              onClick={handleWishToggle}
            >
              위시리스트
            </Button>
            <Button
              variant="light"
              size="lg"
              leftSection={<IconShoppingCart size={20} />}
              onClick={handleAddToCart}
              loading={addToCartMutation.isLoading}
              disabled={product.stock === 0}
            >
              장바구니
            </Button>
            <Button
              size="lg"
              onClick={handleBuyNow}
              disabled={product.stock === 0}
            >
              바로구매
            </Button>
          </Group>

          {product.stock === 0 && (
            <Badge color="red" variant="filled" size="lg" fullWidth>품절</Badge>
          )}

          {/* 배송/혜택 정보 */}
          <Paper p="md" withBorder radius="md">
            <Stack gap="xs">
              <Group gap="xs">
                <IconTruck size={16} color="gray" />
                <Text size="sm">무료배송 | 오늘 주문 시 내일 도착</Text>
              </Group>
              <Group gap="xs">
                <IconShieldCheck size={16} color="gray" />
                <Text size="sm">정품 보장 | 14일 이내 무료 반품</Text>
              </Group>
              <Group gap="xs">
                <IconRefresh size={16} color="gray" />
                <Text size="sm">포인트 적립 5% | 첫 구매 10% 할인</Text>
              </Group>
            </Stack>
          </Paper>
        </Stack>
      </SimpleGrid>

      {/* 탭 영역: 상세정보, 성분, 사용법, 리뷰 */}
      <Paper withBorder radius="md" mt="md">
        <Tabs defaultValue="description">
          <Tabs.List>
            <Tabs.Tab value="description">상세정보</Tabs.Tab>
            <Tabs.Tab value="ingredients">성분</Tabs.Tab>
            <Tabs.Tab value="howToUse">사용법</Tabs.Tab>
            <Tabs.Tab value="reviews">
              리뷰 ({product.reviewCount})
            </Tabs.Tab>
          </Tabs.List>

          <Tabs.Panel value="description" p="xl">
            <Stack gap="md">
              <Text style={{ lineHeight: 1.8 }}>{product.description}</Text>
              <Image
                src={product.imageUrl + '?detail=1'}
                alt="상품 상세 이미지"
                fallbackSrc={FALLBACK_IMAGE}
                radius="md"
                mah={600}
                fit="contain"
              />
            </Stack>
          </Tabs.Panel>

          <Tabs.Panel value="ingredients" p="xl">
            <Text style={{ lineHeight: 1.8 }}>
              {product.ingredients ?? '정제수, 글리세린, 부틸렌글라이콜, 나이아신아마이드, 1,2-헥산다이올, 히알루론산, 판테놀, 알란토인, 토코페릴아세테이트, 카보머, 트로메타민, 잔탄검, 다이소듐이디티에이, 에칠헥실글리세린, 향료'}
            </Text>
          </Tabs.Panel>

          <Tabs.Panel value="howToUse" p="xl">
            <Stack gap="sm">
              <Text style={{ lineHeight: 1.8 }}>
                {product.howToUse ?? '1. 세안 후 토너로 피부결을 정돈합니다.\n2. 적당량을 손에 덜어 얼굴 전체에 부드럽게 펴 발라줍니다.\n3. 가볍게 두드리며 흡수시켜 줍니다.\n4. 아침, 저녁 스킨케어 루틴에 사용하세요.'}
              </Text>
            </Stack>
          </Tabs.Panel>

          <Tabs.Panel value="reviews" p="xl">
            <Stack gap="md">
              <Group justify="space-between">
                <Group gap="xs">
                  <Text size="xl" fw={700}>{product.rating}</Text>
                  <Rating value={product.rating} fractions={2} readOnly />
                </Group>
                <Text size="sm" c="dimmed">{product.reviewCount}개의 리뷰</Text>
              </Group>
              <Divider />
              <Text c="dimmed" ta="center" py="xl">
                리뷰 데이터를 불러오는 중입니다...
              </Text>
            </Stack>
          </Tabs.Panel>
        </Tabs>
      </Paper>
    </Stack>
  );
}
PRODDETAIL2_EOF

      # index.ts
      cat > "$PROJECT_ROOT/$d/screens/product-detail/index.ts" <<'PRODDETAILIDX_EOF'
export { default as ProductDetailPage } from './ProductDetailPage';
PRODDETAILIDX_EOF

      # App router page (dynamic route [id])
      cat > "$PROJECT_ROOT/$d/app/product-detail/[id]/page.tsx" <<'PRODDETAILPAGE_EOF'
'use client';

import { ProductDetailPage } from '@/screens/product-detail';

export default function Page() {
  return <ProductDetailPage />;
}
PRODDETAILPAGE_EOF

      echo "    ✓ screen (single-source): product-detail (ProductDetailPage.tsx) [상품상세정보]"

      # ── 상품 Mock 데이터 ──
      mkdir -p "$PROJECT_ROOT/$d/public/data/$d/product"

      # 상품 목록 mock data
      cat > "$PROJECT_ROOT/$d/public/data/$d/product/list.json" <<'PRODDATA_EOF'
{
  "items": [
    { "id": 1, "name": "윤조에센스 230ml", "description": "발효 성분이 피부 장벽을 강화하고 건강한 윤기를 부여하는 에센셜 안티에이징 에센스", "price": 68000, "stock": 200, "category": "SKINCARE", "brand": "설화수", "rating": 4.9, "reviewCount": 3842, "imageUrl": "https://picsum.photos/seed/skincare1/600/600", "isActive": true },
    { "id": 2, "name": "블랙티 유스 세럼 50ml", "description": "블랙티 발효 성분으로 피부 노화 징후를 케어하는 안티에이징 세럼", "price": 125000, "stock": 80, "category": "SKINCARE", "brand": "이니스프리", "rating": 4.7, "reviewCount": 1256, "imageUrl": "https://picsum.photos/seed/skincare2/600/600", "isActive": true },
    { "id": 3, "name": "타임 레볼루션 퍼스트 에센스 5X 150ml", "description": "발효 여과물이 각질을 정돈하고 투명한 피부결로 가꿔주는 에센스", "price": 42000, "stock": 300, "category": "SKINCARE", "brand": "미샤", "rating": 4.6, "reviewCount": 2178, "imageUrl": "https://picsum.photos/seed/skincare3/600/600", "isActive": true },
    { "id": 4, "name": "어드밴스드 나이트 리페어 세럼 50ml", "description": "밤사이 피부를 복구하고 재생하는 나이트 리페어 세럼", "price": 155000, "stock": 60, "category": "SKINCARE", "brand": "에스티 로더", "rating": 4.8, "reviewCount": 4521, "imageUrl": "https://picsum.photos/seed/skincare4/600/600", "isActive": true },
    { "id": 5, "name": "더블 웨어 파운데이션 SPF10 30ml", "description": "24시간 지속되는 풀커버 리퀴드 파운데이션", "price": 58000, "stock": 150, "category": "MAKEUP", "brand": "에스티 로더", "rating": 4.8, "reviewCount": 5634, "imageUrl": "https://picsum.photos/seed/makeup1/600/600", "isActive": true },
    { "id": 6, "name": "프로 필트 소프트 매트 파운데이션 30ml", "description": "소프트 매트 피니시의 롱웨어 파운데이션", "price": 52000, "stock": 120, "category": "MAKEUP", "brand": "펜티 뷰티", "rating": 4.7, "reviewCount": 2890, "imageUrl": "https://picsum.photos/seed/makeup2/600/600", "isActive": true },
    { "id": 7, "name": "글로우 립밤 3.2g", "description": "은은한 색감과 촉촉한 광택의 틴티드 립밤", "price": 38000, "stock": 500, "category": "MAKEUP", "brand": "디올", "rating": 4.6, "reviewCount": 1876, "imageUrl": "https://picsum.photos/seed/makeup3/600/600", "isActive": true },
    { "id": 8, "name": "래쉬 센세이셔널 마스카라", "description": "드라마틱한 볼륨과 길이의 워터프루프 마스카라", "price": 18000, "stock": 400, "category": "MAKEUP", "brand": "메이블린", "rating": 4.5, "reviewCount": 3245, "imageUrl": "https://picsum.photos/seed/makeup4/600/600", "isActive": true },
    { "id": 9, "name": "UV 디펜스 미 데일리 선크림 SPF50+ 50ml", "description": "가볍고 촉촉한 데일리 자외선 차단제", "price": 32000, "stock": 350, "category": "SUNCARE", "brand": "라로슈포제", "rating": 4.7, "reviewCount": 4123, "imageUrl": "https://picsum.photos/seed/sun1/600/600", "isActive": true },
    { "id": 10, "name": "미셀라 클렌징 워터 400ml", "description": "메이크업과 불순물을 부드럽게 녹여내는 올인원 클렌징 워터", "price": 22000, "stock": 280, "category": "CLEANSING", "brand": "비오더마", "rating": 4.8, "reviewCount": 7234, "imageUrl": "https://picsum.photos/seed/clean2/600/600", "isActive": true },
    { "id": 11, "name": "비타민C 브라이트닝 마스크팩 10매", "description": "고농도 비타민C 칙칙한 피부톤 케어 시트마스크", "price": 15000, "stock": 450, "category": "MASK", "brand": "메디힐", "rating": 4.7, "reviewCount": 6789, "imageUrl": "https://picsum.photos/seed/mask2/600/600", "isActive": true },
    { "id": 12, "name": "미스 디올 블루밍 부케 EDP 50ml", "description": "피오니와 로즈 노트의 로맨틱한 플로럴 향수", "price": 148000, "stock": 40, "category": "PERFUME", "brand": "디올", "rating": 4.9, "reviewCount": 2567, "imageUrl": "https://picsum.photos/seed/perfume1/600/600", "isActive": true }
  ],
  "totalCount": 20,
  "page": 1,
  "size": 12
}
PRODDATA_EOF

      # 상품 상세 mock data (id=1 기본)
      cat > "$PROJECT_ROOT/$d/public/data/$d/product/1.json" <<'PRODDETAILDATA_EOF'
{
  "id": 1,
  "name": "윤조에센스 230ml",
  "description": "발효 성분이 피부 장벽을 강화하고 건강한 윤기를 부여하는 에센셜 안티에이징 에센스. 피부의 5대 요소(투명도, 탄력, 보습, 매끄러움, 생기)를 케어합니다. 설화수만의 자음단™ 기술로 탄생한 발효 성분이 피부 깊숙이 스며들어 피부 본연의 건강한 아름다움을 되찾아줍니다.",
  "price": 68000,
  "stock": 200,
  "category": "SKINCARE",
  "brand": "설화수",
  "rating": 4.9,
  "reviewCount": 3842,
  "imageUrl": "https://picsum.photos/seed/skincare1/600/600",
  "images": [
    "https://picsum.photos/seed/skincare1/600/600",
    "https://picsum.photos/seed/skincare1a/600/600",
    "https://picsum.photos/seed/skincare1b/600/600",
    "https://picsum.photos/seed/skincare1c/600/600"
  ],
  "isActive": true,
  "ingredients": "정제수, 사카로마이세스발효여과물, 부틸렌글라이콜, 글리세린, 사이클로펜타실록세인, 프로판다이올, 폴리글리세릴-10스테아레이트, 나이아신아마이드, 에칠헥실글리세린, 1,2-헥산다이올, 히알루론산, 아데노신, 판테놀, 카보머, 트로메타민, 잔탄검, 향료",
  "howToUse": "1. 세안 후 토너로 피부결을 정돈합니다.\n2. 적당량(2~3 펌프)을 손에 덜어 얼굴 전체에 부드럽게 펴 발라줍니다.\n3. 손바닥으로 얼굴을 감싸듯 가볍게 두드리며 흡수시켜 줍니다.\n4. 아침, 저녁 스킨케어 루틴에 사용하세요.\n5. 세럼이나 크림 사용 전 단계에서 사용하면 다음 제품의 흡수를 높여줍니다.",
  "volume": "230ml",
  "createdAt": "2026-01-01T00:00:00.000Z"
}
PRODDETAILDATA_EOF

      echo "    ✓ mock data: product list + detail (화장품 20종)"

      # 상품 메뉴를 init.json에 추가
      node -e "
const fs = require('fs');
const p = '$PROJECT_ROOT/$d/public/data/framework/init.json';
let c = fs.readFileSync(p, 'utf8');
const data = JSON.parse(c);

// Add product to topMenus
if (data.menusData && data.menusData.topMenus) {
  data.menusData.topMenus.push(
    { id: 'product-list', label: '상품', icon: 'IconShoppingCart', path: '/product-list', public: true },
  );
}

// Add product to sidebar menus (menus.customer array)
if (data.menusData && data.menusData.menus) {
  const menuGroup = data.menusData.menus.customer || data.menusData.menus[Object.keys(data.menusData.menus)[0]];
  if (Array.isArray(menuGroup)) {
    menuGroup.push({
      id: 'product',
      label: '상품관리',
      icon: 'IconShoppingCart',
      path: '/product-list',
      public: true,
      isParent: true,
      showInDrawer: true,
      children: [
        { id: 'product-list', label: '상품 진열', icon: 'IconLayoutGrid', path: '/product-list' },
        { id: 'product-detail', label: '상품 상세', icon: 'IconEye', path: '/product-detail/1' },
      ]
    });
  }
}

fs.writeFileSync(p, JSON.stringify(data, null, 2));
"

      echo "    ✓ menu: 상품관리 메뉴 추가 완료"
    fi

  else
    # No screens specified
    sed -i '' "s|/__FIRST_SCREEN__|/|g" "$PROJECT_ROOT/$d/app/page.tsx"
    # Empty menus
    node -e "
const fs = require('fs');
const p = '$PROJECT_ROOT/$d/public/data/framework/init.json';
let c = fs.readFileSync(p, 'utf8');
c = c.replace('__TOP_MENUS__', '');
c = c.replace('__SIDEBAR_MENUS__', '');
// Fix potential double commas or trailing commas
c = c.replace(/,(\s*[\]}])/g, '\$1');
fs.writeFileSync(p, c);
"
  fi

  port_idx=$((port_idx + 1))
  echo "  ✓ $d/ 생성 완료"
done

            echo ""
echo "[Step 4] 업무도메인 앱 설정 완료 ✓"
              echo ""

#############################################
# Step 5: Root workspace files
#############################################
echo "[Step 5] 루트 워크스페이스 파일 생성 중..."

# pnpm-workspace.yaml
workspace_packages="  - gateway"
for d in "${DOMAIN_NAMES[@]}"; do
  workspace_packages="$workspace_packages
  - $d"
done

cat > "$PROJECT_ROOT/pnpm-workspace.yaml" <<EOF
packages:
$workspace_packages
EOF

# Root package.json
cat > "$PROJECT_ROOT/package.json" <<EOF
{
  "name": "$PROJECT_NAME",
  "private": true,
  "scripts": {
    "dev:gateway": "pnpm --filter ${PROJECT_NAME}-gateway dev",
    "clean": "find . -name node_modules -type d -prune -exec rm -rf {} + && find . -name .next -type d -prune -exec rm -rf {} +"
  }
}
EOF

# Add domain dev scripts
for idx in "${!DOMAIN_NAMES[@]}"; do
  d="${DOMAIN_NAMES[$idx]}"
  mode="${DOMAIN_ROUTER_MODES[$idx]}"
  [ "$mode" = "screen" ] && continue
  node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('$PROJECT_ROOT/package.json', 'utf8'));
pkg.scripts['dev:$d'] = 'pnpm --filter ${PROJECT_NAME}-$d dev';
fs.writeFileSync('$PROJECT_ROOT/package.json', JSON.stringify(pkg, null, 2) + '\n');
"
done

# .npmrc
cat > "$PROJECT_ROOT/.npmrc" <<EOF
strict-peer-dependencies=false
auto-install-peers=true
EOF

# .gitignore
cat > "$PROJECT_ROOT/.gitignore" <<EOF
node_modules/
.next/
dist/
.jw-packs/
.env.local
*.tsbuildinfo
EOF

echo "[Step 5] 루트 파일 생성 완료 ✓"
        echo ""
  
#############################################
# Step 6: Setup pnpm.overrides
#############################################
echo "[Step 6] pnpm.overrides 설정 중..."

  (
    cd "$PROJECT_ROOT"
  node - "$PACK_DIR" <<'NODE'
const fs = require('fs');
const path = require('path');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const tgzDir = process.argv[2];

pkg.packageManager = 'pnpm@' + require('child_process').execSync('pnpm -v').toString().trim();

const makeRelative = (absPath) => {
  const rel = path.relative(process.cwd(), absPath);
  return rel.startsWith('.') ? rel : './' + rel;
};

const overrides = {};
const tgzFiles = fs.readdirSync(tgzDir).filter(f => f.endsWith('.tgz'));
const nameMap = {
  'react': '@jwsl/react', 'next': '@jwsl/next', '_configs': '@jwsl/_configs',
  'router-next-app': '@jwsl/router-next-app', 'router-next-pages': '@jwsl/router-next-pages',
  'router-browser': '@jwsl/router-browser',
  'core': '@jwsl/core', 'provider': '@jwsl/provider', 'lib': '@jwsl/lib',
  'css': '@jwsl/css', 'icons': '@jwsl/icons', 'ui': '@jwsl/ui', 'chat': '@jwsl/chat',
  'eslint-config': '@jwsl/eslint-config', 'gateway': '@jwsl/gateway',
  'framework': '@jwsl/framework', 'typescript-config': '@jwsl/typescript-config',
  'templates': '@jwsl/templates'
};

for (const file of tgzFiles) {
  const match = file.match(/^jwsl-([a-z_-]+?)-\d+\.\d+\.\d+.*\.tgz$/);
  if (match) {
    const shortName = match[1];
    if (shortName === 'router') {
      overrides['@jwsl/router'] = 'file:' + makeRelative(path.join(tgzDir, file));
    } else if (nameMap[shortName]) {
      overrides[nameMap[shortName]] = 'file:' + makeRelative(path.join(tgzDir, file));
    }
  }
}

pkg.pnpm = pkg.pnpm || {};
pkg.pnpm.overrides = overrides;

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
console.log('[OVERRIDES] ' + Object.keys(overrides).length + '개 패키지 등록 완료');
NODE
  )
  
echo "[Step 6] pnpm.overrides 설정 완료 ✓"
    echo ""

#############################################
# Step 6.5: Remove @jwsl/* deps not in overrides
#############################################
echo "[Step 6.5] tgz 없는 @jwsl 의존성 제거 중..."
(
  cd "$PROJECT_ROOT"
  node - <<'NODE'
const fs = require('fs');
const path = require('path');

const rootPkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const overrides = (rootPkg.pnpm && rootPkg.pnpm.overrides) || {};
const availableJwsl = new Set(Object.keys(overrides));

// Scan all workspace package.json files
const workspaceYaml = fs.readFileSync('pnpm-workspace.yaml', 'utf8');
const dirs = workspaceYaml.match(/- (.+)/g).map(m => m.replace('- ', '').trim());

for (const dir of dirs) {
  const pkgPath = path.join(dir, 'package.json');
  if (!fs.existsSync(pkgPath)) continue;
  
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  let changed = false;
  
  for (const section of ['dependencies', 'devDependencies']) {
    if (!pkg[section]) continue;
    for (const dep of Object.keys(pkg[section])) {
      if (dep.startsWith('@jwsl/') && !availableJwsl.has(dep)) {
        console.log(`  [REMOVE] ${dir}: ${dep} (tgz 없음)`);
        delete pkg[section][dep];
        changed = true;
      }
    }
  }
  
  if (changed) {
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
  }
}
console.log('[OK] 정리 완료');
NODE
  )

#############################################
# Step 7: Install dependencies
#############################################
echo "[Step 7] 의존성 설치 중..."
(
  cd "$PROJECT_ROOT"
  pnpm install
)
echo "[Step 7] 의존성 설치 완료 ✓"
echo ""

#############################################
# Step 8: Patch node_modules (Turbopack)
#############################################
echo "[Step 8] node_modules 패치 중..."
(
  cd "$PROJECT_ROOT"
  node -e "
const fs = require('fs');
const path = require('path');

function findFiles(dir, filename) {
  const results = [];
  try {
    const items = fs.readdirSync(dir, { withFileTypes: true });
    for (const item of items) {
      const full = path.join(dir, item.name);
      if (item.isDirectory() && item.name !== '.git') {
        results.push(...findFiles(full, filename));
      } else if (item.name === filename) {
        results.push(full);
      }
    }
  } catch (e) { /* skip */ }
  return results;
}

const files = findFiles(
  path.join(process.cwd(), 'node_modules'),
  'interceptors.js'
).filter(f => f.includes('@jwsl') && f.includes('dist/api'));

let patched = 0;
for (const file of files) {
  let code = fs.readFileSync(file, 'utf8');
  let changed = false;
  if (code.includes(\"require('fs')\")) {
    code = code.replace(/const fs = require\('fs'\);/g, \"const fs = await import('node:fs');\");
    changed = true;
  }
  if (code.includes(\"require('path')\")) {
    code = code.replace(/const path = require\('path'\);/g, \"const path = await import('node:path');\");
    changed = true;
  }
  if (changed) { fs.writeFileSync(file, code); patched++; }
}
console.log('[Patch] interceptors.js: ' + patched + ' file(s) patched');
" 2>/dev/null || echo "[WARN] patch skipped (non-critical)"
)
echo "[Step 8] 패치 완료 ✓"
echo ""

#############################################
# Summary
#############################################
echo ""
echo "=========================================="
echo " 프로젝트 생성 완료!"
echo "=========================================="
echo ""
echo "구조:"
echo "  $PROJECT_ROOT/"
echo "    ├── gateway/       (port 3000, App Router, registry 모드)"
port_idx=0
for idx in "${!DOMAIN_NAMES[@]}"; do
  d="${DOMAIN_NAMES[$idx]}"
  mode="${DOMAIN_ROUTER_MODES[$idx]}"
    p=$((3101 + port_idx))
  if [ "$mode" = "screen" ]; then
    echo "    ├── $d/           (screen package)"
  else
    echo "    ├── $d/           (port $p, App Router, codegen 모드)"
    port_idx=$((port_idx + 1))
  fi
done
echo "    ├── .jw-packs/    (framework packages)"
echo "    └── package.json  (workspace root)"
echo ""
echo "실행 방법:"
echo ""
port_idx=0
for idx in "${!DOMAIN_NAMES[@]}"; do
  d="${DOMAIN_NAMES[$idx]}"
  mode="${DOMAIN_ROUTER_MODES[$idx]}"
  [ "$mode" = "screen" ] && continue
  p=$((3101 + port_idx))
  echo "  # $d (port $p)"
  echo "  cd \"$PROJECT_ROOT/$d\" && pnpm dev"
  echo ""
  port_idx=$((port_idx + 1))
done
echo "  # gateway (port 3000)"
echo "  cd \"$PROJECT_ROOT/gateway\" && pnpm dev"
echo ""
echo "접속 URL:"
echo "  Gateway:  http://localhost:3000"
port_idx=0
for idx in "${!DOMAIN_NAMES[@]}"; do
  d="${DOMAIN_NAMES[$idx]}"
  mode="${DOMAIN_ROUTER_MODES[$idx]}"
  [ "$mode" = "screen" ] && continue
  p=$((3101 + port_idx))
  echo "  $d:     http://localhost:$p"
  port_idx=$((port_idx + 1))
done
echo ""

cd "$WORK_DIR"
# EOF
