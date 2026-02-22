# Framework Package Downloader

JW Framework 패키지(.tgz)를 다운로드하는 스크립트입니다.

- 기본: GitHub Releases assets 다운로드
- 추가: pack 저장소(`pharmeath/jw-pack`)의 `.jw-packs/*.tgz`를 git ref 기준으로 직접 다운로드

## 사용법

### 기본 사용
```bash
# 최신 버전 다운로드
./scripts/download-framework.sh

# 특정 버전 다운로드
./scripts/download-framework.sh v1.0.0

# (권장) pack 저장소에서 직접 다운로드 (태그/브랜치)
./scripts/download-framework.sh --from-git v0.0.3
./scripts/download-framework.sh --from-git main
```

### 환경변수 설정

#### GITHUB_REPO (저장소 지정)
```bash
# 다른 저장소에서 다운로드
GITHUB_REPO=your-org/jw-framework ./scripts/download-framework.sh
```

#### PACK_GITHUB_REPO (pack 저장소 지정: git 모드)
```bash
# git 모드에서 다운로드할 pack 저장소 지정
PACK_GITHUB_REPO=your-org/react_jw_pack ./scripts/download-framework.sh --from-git v0.0.3
```

#### GITHUB_TOKEN (Private Repository)
```bash
# Private repository 접근용 토큰
GITHUB_TOKEN=ghp_xxxxxxxxxxxx ./scripts/download-framework.sh
```

**GitHub Token 생성 방법**:
1. GitHub → Settings → Developer settings → Personal access tokens
2. "Generate new token (classic)" 클릭
3. Scopes 선택: `repo` (Full control of private repositories)
4. 생성된 토큰 복사 및 사용

### 실행 예시

```bash
# 예시 1: 최신 버전 다운로드
./scripts/download-framework.sh
# → .jw-packs/에 최신 버전 tgz 파일 다운로드

# 예시 2: 특정 버전 다운로드
./scripts/download-framework.sh v1.0.0
# → .jw-packs/에 v1.0.0 버전 tgz 파일 다운로드

# 예시 3: Private repo + 특정 버전
GITHUB_TOKEN=ghp_xxxx GITHUB_REPO=my-org/framework ./scripts/download-framework.sh v1.2.3

# 예시 4: 재다운로드
./scripts/download-framework.sh v1.0.0
# → 이미 다운로드된 버전이면 확인 후 스킵 또는 재다운로드
```

## 다운로드되는 패키지

스크립트는 다음 패키지를 다운로드합니다:
- `@jwsl/core` → `jwsl-core-*.tgz`
- `@jwsl/ui` → `jwsl-ui-*.tgz`
- `@jwsl/lib` → `jwsl-lib-*.tgz`
- `@jwsl/provider` → `jwsl-provider-*.tgz`
- `@jwsl/icons` → `jwsl-icons-*.tgz`

## 버전 관리

다운로드된 버전은 `.jw-packs/.version` 파일에 저장됩니다.

```bash
# 현재 다운로드된 버전 확인
cat .jw-packs/.version
# 출력: v1.0.0
```

## 문제 해결

### 문제 1: "Failed to fetch latest version"
**원인**: GitHub API 접근 실패 또는 Release가 없음

**해결**:
```bash
# Release 확인
open https://github.com/your-org/jw-framework/releases

# 특정 버전 명시
./scripts/download-framework.sh v1.0.0
```

### 문제 2: "Failed (HTTP 404)"
**원인**: 
- Release에 해당 버전이 없음
- Private repo인데 토큰 미설정
- tgz 파일명 불일치

**해결**:
```bash
# 1. Release 페이지에서 정확한 버전 확인
open https://github.com/your-org/jw-framework/releases

# 2. Private repo라면 토큰 설정
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
./scripts/download-framework.sh v1.0.0

# 3. 파일명 확인
# Release에서 업로드된 실제 파일명과 스크립트의 PACKAGES 배열이 일치하는지 확인
```

### 문제 3: git 모드에서 "No .tgz files found at .jw-packs"
**원인**:
- pack 저장소의 해당 ref에 `.jw-packs/*.tgz`가 없음
- 저장소/권한 문제

**해결**:
```bash
# pack 저장소 ref 확인(태그/브랜치)
./scripts/download-framework.sh --from-git main
./scripts/download-framework.sh --from-git v0.0.3

# 다른 pack 저장소를 쓰는 경우
PACK_GITHUB_REPO=your-org/react_jw_pack ./scripts/download-framework.sh --from-git v0.0.3
```

## CI/CD 통합

### GitHub Actions 예시
```yaml
name: Build Project

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install pnpm
        run: npm install -g pnpm
      
      - name: Download Framework
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_REPO: your-org/jw-framework
        run: ./scripts/download-framework.sh v1.0.0
      
      - name: Create Project
        run: ./scripts/create-jw-app.sh pharmeath order cart
      
      - name: Build
        run: |
          cd app/pharmeath
          pnpm build
```

### Docker 통합
```dockerfile
FROM node:18 AS builder

WORKDIR /app

# 환경변수로 버전 지정
ARG FRAMEWORK_VERSION=v1.0.0
ARG GITHUB_REPO=your-org/jw-framework
ARG GITHUB_TOKEN

# 다운로드 스크립트 복사
COPY scripts/download-framework.sh /app/scripts/
RUN chmod +x /app/scripts/download-framework.sh

# Framework 다운로드
RUN GITHUB_REPO=${GITHUB_REPO} \
    GITHUB_TOKEN=${GITHUB_TOKEN} \
    /app/scripts/download-framework.sh ${FRAMEWORK_VERSION}

# 프로젝트 빌드
COPY app/pharmeath /app
RUN pnpm install && pnpm build
```

## 고급 사용법

### 여러 버전 동시 관리
```bash
# v1.0.0 다운로드
./scripts/download-framework.sh v1.0.0

# v1.1.0 다운로드 (덮어쓰기)
./scripts/download-framework.sh v1.1.0

# 버전별 디렉토리 분리 (수동)
mkdir -p .jw-packs/v1.0.0
mv .jw-packs/*.tgz .jw-packs/v1.0.0/

./scripts/download-framework.sh v1.1.0
mkdir -p .jw-packs/v1.1.0
mv .jw-packs/*.tgz .jw-packs/v1.1.0/
```

### 오프라인 환경
```bash
# 온라인 환경에서 다운로드
./scripts/download-framework.sh v1.0.0
tar -czf framework-packages.tar.gz .jw-packs/

# 오프라인 환경으로 파일 전송 후
tar -xzf framework-packages.tar.gz
# → .jw-packs/ 디렉토리 복원
```

## 참고사항

- 다운로드된 파일은 `.jw-packs/` 디렉토리에 저장됩니다
- `.jw-packs/`의 Git 추적 여부는 운영 모델에 따라 다릅니다.
  - pack 저장소 커밋 기반 공급 모델이면: pack 저장소에서는 `.jw-packs/`를 커밋/태그로 관리합니다.
  - 단순 로컬 다운로드(임시 캐시) 용도면: `.gitignore`로 제외해도 됩니다.
- 각 프로젝트 생성 전에 한 번만 실행하면 됩니다
- 여러 프로젝트에서 동일한 `.jw-packs/` 재사용 가능

## 관련 문서

- pack 저장소 기반 운영 가이드: [USAGE_GUIDE_PACK_REPO.md](USAGE_GUIDE_PACK_REPO.md)

- [create-app.md](./create-app.md) - 프로젝트 생성 가이드
- [GitHub Releases 문서](https://docs.github.com/en/repositories/releasing-projects-on-github)
