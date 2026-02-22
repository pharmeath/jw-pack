# jw-ui-framework 가이드 문서 (SHOULD)

> 이 문서는 **권장 가이드**를 포함한다. 프로덕션 품질 향상을 위해 점진 도입을 권장한다.

**관련 문서**:
- 필수 정책(MUST)은 [정책 문서](./jw-ui-framework_mfe_policy.md) 참조
- 구조/API 레퍼런스는 [레퍼런스 문서](./jw-ui-framework_mfe_reference.md) 참조
- 주문(Order) 화면 개발 실무 가이드는 [주문 도메인 Screen 가이드](./jw-ui-framework_mfe_screen-guide_order.md) 참조

---

## 권장 운영/설정 항목 (Gateway)

정책 문서에 포함되지 않은 **권장 구성**이다.

### 권장 환경변수 (Gateway)

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `GATEWAY_DOMAIN_{NAME}_URL` | URL | `http://localhost:310X` | 도메인별 URL (예: `GATEWAY_DOMAIN_ORDER_URL`) |
| `GATEWAY_PROTECTED_PATHS` | string | 모든 도메인 | 인증 필요 경로 (쉼표 구분) |
| `GATEWAY_SECURITY_HEADERS_ENABLED` | boolean | `false` | 보안 헤더 활성화 토글 |
| `NEXT_PUBLIC_API_URL` | path | `/api` | API 프록시 경로 (브라우저에는 절대 URL 노출 금지) |

### 권장 헤더 전파 (Gateway → Domain)

| 헤더 | 설명 |
|------|------|
| `x-user-id` | 인증된 사용자 ID |
| `x-roles` | 사용자 역할 (쉼표 구분) |
| `traceparent` | W3C Trace Context |

### 운영 형태 권장
- Gateway를 **단일 런타임(단일 Next.js App)** 으로 운영하면 보안/관측/장애대응 정책의 중앙화가 용이하다.

## 목차

1. [Migration Strategy](#migration-strategy)
2. [Performance Budgets](#performance-budgets)
3. [Caching & CDN Strategy](#caching--cdn-strategy)
4. [i18n Architecture](#i18n-architecture)
5. [Testing Strategy](#testing-strategy)
6. [로그 정책](#로그-정책)
7. [모니터링 대시보드](#모니터링-대시보드)
8. [접근성 정책](#접근성-정책)
9. [SEO 정책](#seo-정책)
10. [보안 감사 정책](#보안-감사-정책)
11. [코드 리뷰 체크리스트](#코드-리뷰-체크리스트)
12. [성능 벤치마크](#성능-벤치마크)
13. [팀 온보딩 가이드](#팀-온보딩-가이드)
14. [버전 호환성 매트릭스](#버전-호환성-매트릭스)

---

## Migration Strategy

레거시 앱에서 jw-ui-framework MFE 구조로 점진 이관한다.

> MFE 아키텍처 및 기본 구조는 [레퍼런스 문서 - 기본구조](./jw-ui-framework_mfe_reference.md#기본구조)를 참조한다.

### Step 1: Gateway 우선 도입
- rewrites를 이용해 기존 앱을 프록시
- 인증/관측/장애 폴백 정책을 Gateway에 중앙화

### Step 2: 도메인별 점진 이관
- `/order/*` 등 도메인 prefix 단위로 신규 도메인 앱으로 라우팅 전환
- 전환 단위는 화면/기능(Feature) 또는 라우팅 세그먼트로 정의

### Step 3: Feature 구조 점진 도입
- 라우팅 레이어(`pages/**` 또는 `app/**`)는 thin 유지
- UI/상태/도메인 규칙은 도메인 루트의 feature 폴더로 단계적 이동
- 중간 `features/` 폴더는 사용하지 않음

### Recommended: Router entrypoints & adapters

To reduce operational variance and prevent router-specific logic from leaking into feature code:

- Keep routing files **thin** and delegate initialization/layout to framework entrypoints.
- Use **Unified Router** adapters at the entrypoint only.
  - Next.js **App Router**: use the App entrypoint template (e.g. `@jwsl/framework/app`) and obtain navigation via `@jwsl/router-next-app`.
  - Next.js **Pages Router**: use the Pages entrypoint template (e.g. `@jwsl/framework/page`) and wrap `AppProps.router` via `@jwsl/router-next-pages`.
- Feature/Screens MUST access routing only through the single entry hooks from `@jwsl/core`.

Notes:
- Pages Router is supported for customer compatibility, but new implementations SHOULD prefer App Router when feasible.
- For a build/publish perspective on why `@jwsl/framework` may ship both entrypoints, see: [@jwsl/framework build inclusion note](./jwsl-framework_page-in-build.md).

### 마이그레이션 코드 예시

#### Before: Legacy 구조

```
legacy-app/
├── pages/
│   └── order/
│       └── list.tsx       # UI + API + 상태 혼합
├── components/
│   └── OrderTable.tsx     # 공통 컴포넌트
└── utils/
    └── api.ts             # raw fetch
```

```tsx
// legacy-app/pages/order/list.tsx (Before)
import { useState, useEffect } from 'react';
import { Table } from 'antd';  // 직접 import

export default function OrderListPage() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    fetch('/api/orders')  // raw fetch
      .then(res => res.json())
      .then(data => {
        setOrders(data);
        setLoading(false);
      });
  }, []);
  
  return <Table dataSource={orders} loading={loading} />;
}
```

#### After: MFE Feature 구조

```
order/
├── order-list/
│   ├── components/
│   │   └── OrderListTable.tsx
│   ├── hooks/
│   │   └── useOrderList.ts
│   ├── api/
│   │   └── orderListApi.ts
│   ├── types/
│   │   └── order.types.ts
│   └── index.ts
└── pages/
    └── index.tsx          # thin routing only
```

```tsx
// order/order-list/hooks/useOrderList.ts (After)
import { useAutoFetch } from '@jwsl/lib';
import { orderListApi } from '../api/orderListApi';
import type { Order } from '../types/order.types';

export function useOrderList() {
  return useAutoFetch<Order[]>({
    queryKey: ['orders'],
    queryFn: orderListApi.getList,
  });
}
```

```tsx
// order/order-list/components/OrderListTable.tsx (After)
import { Table } from '@jwsl/ui';  // 추상화된 컴포넌트
import type { Order } from '../types/order.types';

interface Props {
  orders: Order[];
  loading: boolean;
}

export function OrderListTable({ orders, loading }: Props) {
  return <Table dataSource={orders} loading={loading} columns={...} />;
}
```

```tsx
// order/pages/index.tsx (After) - Thin Routing
import { OrderListTable, useOrderList } from '@/order-list';

export default function OrderListPage() {
  const { data: orders, isLoading } = useOrderList();
  return <OrderListTable orders={orders ?? []} loading={isLoading} />;
}
```

---

## Performance Budgets

Next.js MFE 구성에서 초기 로딩 비용과 hydration 비용을 통제한다.

### 번들 크기 예산
- Domain MFE initial bundle (entry) < **200KB** (gzipped)
- Feature 단위 lazy-loading은 `dynamic import()`를 기본 전략으로 사용

### Tree-shaking 요구사항
- `@jwsl/*`는 tree-shaking이 가능하도록 설계
  - 사이드이펙트 최소화
  - 명시적 export 경로 사용 (필요한 모듈만 import)

### 중복 방지
- 도메인 앱은 중복 런타임을 방지하기 위해 의존성 버전 및 번들 중복 점검

---

## Caching & CDN Strategy

정적 자산과 API 응답의 캐싱을 통해 성능을 최적화하고 서버 부하를 감소시킨다.

### 정적 자산 캐싱
- `/_next/static/*` 경로: **immutable** 캐싱 적용
  ```
  Cache-Control: public, max-age=31536000, immutable
  ```
- 각 도메인 앱의 `/<domain>/_next/static/*`도 동일 정책 적용
- CDN(CloudFront, Vercel Edge, Cloudflare 등)을 Gateway 앞단에 배치

### API 응답 캐싱
- 읽기 전용 API: `stale-while-revalidate` 패턴 적용
  ```
  Cache-Control: public, max-age=60, stale-while-revalidate=300
  ```
- 인증 필요 API: `public` 캐싱 금지
  ```
  Cache-Control: private, no-store
  ```
- BFF 레이어에서 Redis 기반 응답 캐싱 고려

### ISR/SSG 전략
- 자주 변경되지 않는 페이지: **ISR** 적용 (`revalidate: 60` ~ `revalidate: 3600`)
- 완전 정적 페이지: **SSG** 적용
- 사용자별 동적 콘텐츠: SSR 또는 CSR 유지

### CDN 캐시 무효화
- 배포 시 정적 자산은 content-hash 기반 파일명으로 자동 무효화
- ISR 페이지는 on-demand revalidation API 제공 (`/api/revalidate?path=...`)

---

## i18n Architecture

다국어 지원을 위한 표준 아키텍처를 정의한다.

### 라우팅 전략
- **Subpath 라우팅** 사용 (`/ko/order`, `/en/order`)
- Domain 라우팅 허용 (`ko.example.com`, `en.example.com`) - 인프라 복잡도 증가
- Gateway에서 locale 감지 및 기본 locale 리다이렉트 처리

### Locale 감지 우선순위
1. URL path (`/ko/...`, `/en/...`)
2. Cookie (`NEXT_LOCALE`)
3. `Accept-Language` 헤더
4. 기본 locale (예: `ko`)

### 번역 리소스 관리

```
locales/
├── ko/
│   ├── common.json
│   └── order.json
└── en/
    ├── common.json
    └── order.json
```

- 네임스페이스 기반 로딩으로 번들 크기 최적화
- `@jwsl/lib`에서 `useTranslation()` 훅 제공

### 도메인 앱 책임
- 각 도메인 앱은 자체 번역 네임스페이스 소유 (예: `order`, `cart`)
- 공통 번역은 `common` 네임스페이스로 Gateway/Framework에서 제공
- 날짜/숫자/통화 포맷은 `Intl` API 기반 유틸리티 사용

### @jwsl/lib i18n 구현 (Internal/External 모드)

| 모드 | 환경변수 | 설명 |
|------|----------|------|
| **internal** (기본) | `NEXT_PUBLIC_JWSL_I18N_PROVIDER=internal` | 프레임워크 내장 번역 데이터 사용 |
| **external** | `NEXT_PUBLIC_JWSL_I18N_PROVIDER=external` | 외부 라이브러리 어댑터 연동 |

#### Internal 모드 (기본)
```tsx
import { useTranslation, initializeI18n } from '@jwsl/lib/i18n';

// 초기화 (_app.tsx 또는 layout.tsx)
await initializeI18n();

// 컴포넌트에서 사용
function MyComponent() {
  const { t, lang, setLanguage } = useTranslation();
  return <button onClick={() => setLanguage('en')}>{t('common.save')}</button>;
}
```

#### External 모드 (어댑터 연동)
```tsx
import i18next from 'i18next';
import { registerExternalI18nBackend } from '@jwsl/lib/i18n';

await i18next.init({ /* 설정 */ });

registerExternalI18nBackend({
  t: (key, params, defaultValue) => i18next.t(key, { ...params, defaultValue }),
  getLanguage: () => i18next.language,
  setLanguage: (lang) => i18next.changeLanguage(lang),
  subscribe: (listener) => {
    i18next.on('languageChanged', listener);
    return () => i18next.off('languageChanged', listener);
  },
});
```

### 모드 선택 기준

| 조건 | 권장 모드 |
|------|----------|
| 단순 다국어 지원, 빠른 시작 | internal |
| 기존 i18next/react-intl 마이그레이션 | external |
| 복잡한 pluralization, 네임스페이스 분리 필요 | external |
| 프레임워크 표준화 우선 | internal |

---

## Testing Strategy

MFE 구조에서 테스트 전략을 정의하여 품질을 보장한다.

> Feature 폴더 구조는 [레퍼런스 문서 - Feature 구조](./jw-ui-framework_mfe_reference.md#feature-구조)를 참조한다.

### 테스트 피라미드

| 레벨 | 테스트 유형 | 도구 | 범위 | 실행 시점 |
|------|------------|------|------|----------|
| **L1** | Unit Test | Vitest/Jest | 함수, 훅, 유틸 | Pre-commit |
| **L2** | Component Test | Testing Library | UI 컴포넌트 | Pre-commit |
| **L3** | Integration Test | Testing Library + MSW | Feature 단위 | PR 빌드 |
| **L4** | E2E Test | Playwright/Cypress | 사용자 시나리오 | Nightly/Release |
| **L5** | Contract Test | Pact | Gateway ↔ Domain API | PR 빌드 |

### 테스트 범위 기준
- `@jwsl/*` 패키지: **80% 이상** 코드 커버리지 유지
- Domain App Feature: **70% 이상** 커버리지 권장
- 핵심 사용자 흐름: E2E 테스트로 보장 (로그인, 주문, 결제 등)

### 테스트 구조 (Feature 기준)

```
order-list/
├── components/
│   ├── OrderListTable.tsx
│   └── OrderListTable.test.tsx      # Component Test
├── hooks/
│   ├── useOrderList.ts
│   └── useOrderList.test.ts         # Unit Test
├── api/
│   └── orderListApi.test.ts         # Integration Test (MSW)
└── __tests__/
    └── order-list.integration.test.tsx  # Feature Integration
```

### MSW (Mock Service Worker) 정책
- API 모킹은 MSW를 표준으로 사용
- 모킹 핸들러는 `mocks/handlers/` 폴더에 도메인별 분리
- 실제 API 스키마와 모킹 응답 일치 검증 (Contract Test)

### E2E 테스트 정책
- E2E 테스트는 **격리된 테스트 환경**에서 실행
- 테스트 데이터는 시드 스크립트로 초기화
- 주요 시나리오별 Smoke Test:
  - 인증 흐름 (로그인 → 대시보드)
  - 주문 흐름 (목록 → 상세 → 취소)
  - 결제 흐름 (장바구니 → 결제 → 완료)

### CI 통합
- PR 빌드: L1~L3 테스트 실행
- Nightly 빌드: L4 E2E 테스트 실행
- 테스트 실패 시 PR 머지 차단

---

## 로그 정책

### 로그 수집 아키텍처

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Gateway    │────▶│  Fluent Bit │────▶│  Loki/ELK   │
│  Domain App │────▶│  (Sidecar)  │────▶│  (Storage)  │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │  Grafana    │
                                        │  (Query)    │
                                        └─────────────┘
```

### 로그 레벨 정책

| 레벨 | 사용 시점 | 프로덕션 활성화 |
|------|----------|----------------|
| `debug` | 개발 디버깅 | X |
| `info` | 정상 동작 기록 | O |
| `warn` | 잠재적 문제 | O |
| `error` | 에러 발생 | O |

### 보관 정책

| 로그 유형 | 보관 기간 | 샘플링 |
|----------|----------|--------|
| Access Log | 30일 | 100% |
| Error Log | 90일 | 100% |
| Debug Log | 7일 | 10% (개발환경만) |
| Audit Log | 1년 | 100% |

### 로그 포맷 (JSON)

```json
{
  "timestamp": "2026-01-21T10:30:00.000Z",
  "level": "info",
  "service": "gateway",
  "request_id": "abc-123",
  "method": "GET",
  "path": "/order/dashboard",
  "status": 200,
  "latency_ms": 150,
  "user_id": "user-456",
  "trace_id": "trace-789"
}
```

---

## 모니터링 대시보드

### 권장 메트릭

| 메트릭 | 타입 | 알림 임계값 | 설명 |
|--------|------|------------|------|
| `http_request_duration_seconds` | Histogram | p99 > 3s | 요청 응답 시간 |
| `http_requests_total` | Counter | - | 총 요청 수 |
| `http_requests_errors_total` | Counter | 5xx > 1% | 에러 요청 수 |
| `domain_health_status` | Gauge | 0 (unhealthy) | 도메인 앱 상태 |
| `active_connections` | Gauge | > 10000 | 활성 연결 수 |
| `memory_usage_bytes` | Gauge | > 80% | 메모리 사용량 |

### 알림 규칙 (PagerDuty/Slack)

| 레벨 | 조건 | 알림 채널 |
|------|------|----------|
| P1 (Critical) | 5xx > 5% (5분 지속) | PagerDuty + Slack #incidents |
| P2 (High) | p99 > 5s (10분 지속) | Slack #alerts |
| P3 (Medium) | 도메인 앱 1개 unhealthy | Slack #alerts |
| P4 (Low) | 메모리 > 70% | Slack #monitoring |

---

## 접근성 정책

### 준수 기준
- **WCAG 2.1 Level AA** 준수

### 권장 요구사항

| 항목 | 요구사항 | 검증 방법 |
|------|----------|----------|
| 키보드 네비게이션 | 모든 인터랙티브 요소 Tab 접근 가능 | 수동 테스트 |
| 포커스 표시 | 포커스 상태 시각적 표시 | axe-core |
| 대비 비율 | 텍스트 4.5:1, 큰 텍스트 3:1 | axe-core |
| 이미지 alt | 모든 `<img>`에 alt 속성 | ESLint jsx-a11y |
| 폼 라벨 | 모든 입력 필드에 연결된 label | axe-core |
| 에러 메시지 | 에러 발생 시 aria-live로 알림 | 수동 테스트 |

### ESLint 설정

```javascript
// .eslintrc.js
module.exports = {
  extends: ['plugin:jsx-a11y/recommended'],
  rules: {
    'jsx-a11y/alt-text': 'error',
    'jsx-a11y/anchor-has-content': 'error',
    'jsx-a11y/click-events-have-key-events': 'error',
  }
};
```

### 자동화 테스트

```typescript
// 컴포넌트 테스트에 axe-core 통합
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

it('접근성 위반 없음', async () => {
  const { container } = render(<OrderListTable />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

---

## SEO 정책

### 메타태그 권장 요소

#### Pages Router (next/head)

```tsx
import Head from '@jwsl/next/head';

export default function OrderListPage() {
  return (
    <>
      <Head>
        <title>{pageTitle} | {siteName}</title>
        <meta name="description" content={description} />
        <meta name="robots" content="index, follow" />
        <link rel="canonical" href={canonicalUrl} />
        
        {/* Open Graph */}
        <meta property="og:title" content={pageTitle} />
        <meta property="og:description" content={description} />
        <meta property="og:image" content={ogImage} />
        <meta property="og:url" content={canonicalUrl} />
      </Head>
      {/* 페이지 컨텐츠 */}
    </>
  );
}
```

#### App Router (metadata API)

```tsx
import type { Metadata } from '@jwsl/next';

export const metadata: Metadata = {
  title: `${pageTitle} | ${siteName}`,
  description: description,
  robots: { index: true, follow: true },
  alternates: { canonical: canonicalUrl },
  openGraph: {
    title: pageTitle,
    description: description,
    images: [ogImage],
    url: canonicalUrl,
  },
};
```

### 사이트맵 정책

```javascript
// next-sitemap.config.js
module.exports = {
  siteUrl: 'https://example.com',
  generateRobotsTxt: true,
  exclude: ['/admin/*', '/api/*'],
};
```

### 구조화된 데이터 (JSON-LD)

```tsx
<script type="application/ld+json">
{JSON.stringify({
  "@context": "https://schema.org",
  "@type": "WebApplication",
  "name": "JW Platform",
  "applicationCategory": "BusinessApplication"
})}
</script>
```

---

## 보안 감사 정책

### 의존성 취약점 스캔

```bash
# CI에서 자동 실행
pnpm audit --audit-level=high

# 취약점 발견 시 빌드 실패
if [ $? -ne 0 ]; then
  echo "High severity vulnerabilities found."
  exit 1
fi
```

### 보안 리뷰 체크리스트

| 항목 | 확인 사항 | 빈도 |
|------|----------|------|
| 의존성 취약점 | `pnpm audit` | 매 빌드 |
| 시크릿 노출 | `git-secrets` 스캔 | 매 커밋 |
| CSP 위반 | Report-Only 모드 모니터링 | 상시 |
| 인증 토큰 | 만료 시간, 갱신 로직 | 분기별 |
| 권한 검증 | 미인가 접근 테스트 | 분기별 |

### 보안 헤더 검증

```bash
#!/bin/bash
RESPONSE=$(curl -sI https://example.com)
echo "$RESPONSE" | grep -q 'Strict-Transport-Security:' || { echo 'HSTS header missing.'; exit 1; }
echo "$RESPONSE" | grep -q 'X-Content-Type-Options: nosniff' || { echo 'X-Content-Type-Options missing.'; exit 1; }
echo "$RESPONSE" | grep -q 'Content-Security-Policy:' || { echo 'CSP header missing.'; exit 1; }
echo 'All security headers are present.'
```

### 침투 테스트 일정
- 연 1회 외부 보안 업체 침투 테스트
- 분기 1회 내부 보안 점검

---

## 코드 리뷰 체크리스트

### Feature 구현 PR

- [ ] **구조**: Feature 폴더 구조 준수 (`components/`, `hooks/`, `api/`, `types/`)
- [ ] **진입점**: `index.ts`에서 공개 API만 export
- [ ] **의존성**: `@jwsl/*` 패키지만 import, 다른 Feature 내부 import 금지
- [ ] **타입**: TypeScript strict 모드 에러 없음
- [ ] **테스트**: Unit/Component 테스트 포함 (커버리지 70% 이상)
- [ ] **접근성**: 키보드 네비게이션, aria 속성 확인

### UI 컴포넌트 PR

- [ ] **추상화**: `@jwsl/ui` 컴포넌트 사용 (직접 Mantine/Ant 금지)
- [ ] **반응형**: 모바일/태블릿/데스크톱 레이아웃 확인
- [ ] **다크모드**: 테마 호환성 확인
- [ ] **로딩/에러**: 로딩 상태, 에러 상태 UI 포함

### API 연동 PR

- [ ] **훅 사용**: `@jwsl/lib`의 데이터 훅 사용 (raw fetch 금지)
- [ ] **에러 처리**: try-catch 또는 Error Boundary 적용
- [ ] **타입 안전**: API 응답 타입 정의
- [ ] **모킹**: MSW 핸들러 추가

### Gateway/Domain PR

- [ ] **환경변수**: 새 환경변수 문서화
- [ ] **헬스체크**: healthz 엔드포인트 영향 없음 확인
- [ ] **rewrites**: 라우팅 규칙 충돌 없음 확인
- [ ] **미들웨어**: 성능 영향 평가 (latency 증가 확인)

---

## 성능 벤치마크

### 측정 기준 환경

| 항목 | 값 |
|------|-----|
| 네트워크 | 4G (1.5 Mbps) |
| CPU | 4x slowdown |
| 디바이스 | Moto G4 (에뮬레이션) |
| 도구 | Lighthouse CI |

### 성능 예산

| 메트릭 | 목표 | 경고 | 실패 |
|--------|------|------|------|
| LCP (Largest Contentful Paint) | < 2.5s | < 4s | >= 4s |
| FID (First Input Delay) | < 100ms | < 300ms | >= 300ms |
| CLS (Cumulative Layout Shift) | < 0.1 | < 0.25 | >= 0.25 |
| TTI (Time to Interactive) | < 3.8s | < 7.3s | >= 7.3s |
| Bundle Size (gzipped) | < 200KB | < 300KB | >= 300KB |

### Lighthouse CI 설정

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000/order/list'],
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'first-contentful-paint': ['error', { maxNumericValue: 2000 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
      },
    },
    upload: {
      target: 'lhci',
      serverBaseUrl: 'https://lhci.example.com',
    },
  },
};
```

### 번들 분석

```bash
# 번들 크기 분석
pnpm --filter order build
npx @next/bundle-analyzer

# 결과 예시
Route                 Size     First Load JS
├ /order/list         45 kB    180 kB  ✅
├ /order/detail       52 kB    187 kB  ✅
└ /order/checkout     78 kB    213 kB  ⚠️ (예산 초과)
```

---

## 팀 온보딩 가이드

### 학습 경로 (2주 과정)

#### Week 1: 기초

| 일차 | 주제 | 학습 자료 | 실습 |
|------|------|----------|------|
| Day 1 | MFE 개요 | 레퍼런스 문서 "기본구조" | - |
| Day 2 | Gateway 이해 | 레퍼런스 문서 "Gateway 역할" | Gateway 로컬 실행 |
| Day 3 | Domain App 구조 | 레퍼런스 문서 "업무도메인 앱" | order 앱 분석 |
| Day 4 | @jwsl/* 패키지 | 각 패키지 README | Storybook 탐색 |
| Day 5 | Router 정책 | 정책 문서 "Standards" | App/Pages 전환 실습 |

#### Week 2: 심화

| 일차 | 주제 | 학습 자료 | 실습 |
|------|------|----------|------|
| Day 6 | Feature 패턴 | 레퍼런스 문서 "Feature 패턴" | 신규 Feature 생성 |
| Day 7 | 테스트 작성 | 가이드 문서 "Testing Strategy" | 단위 테스트 작성 |
| Day 8 | 에러 처리 | 정책 문서 "Error Handling" | Error Boundary 적용 |
| Day 9 | 배포 파이프라인 | 정책 문서 "배포 파이프라인" | CI/CD 분석 |
| Day 10 | 종합 실습 | - | 전체 Feature 구현 |

### 온보딩 체크리스트

- [ ] 로컬 개발 환경 설정 완료
- [ ] Gateway, Domain App 실행 성공
- [ ] @jwsl/* 패키지 역할 이해
- [ ] Feature 폴더 구조 생성 가능
- [ ] 단위 테스트 작성 가능
- [ ] PR 제출 및 리뷰 프로세스 이해
- [ ] 배포 파이프라인 이해

### 멘토링 구조
- 1:1 멘토 배정 (2주간)
- 일일 스탠드업 참석
- 주간 코드 리뷰 세션 참여

---

## 버전 호환성 매트릭스

### @jwsl/react 호환성

| @jwsl/react | React | React DOM | 상태 |
|-------------|-------|-----------|------|
| 18.3.x | 18.3.x | 18.3.x | 지원 |
| 19.0.x | 19.0.x | 19.0.x | 지원 |
| 19.1.x | 19.1.x | 19.1.x | 최신 |

### @jwsl/next 호환성

| @jwsl/next | Next.js | Node.js | 상태 |
|------------|---------|---------|------|
| 16.0.x | 16.0.x | 18.x, 20.x | 지원 |
| 16.1.x | 16.1.x | 18.x, 20.x | 최신 |

### 패키지 간 호환성

| @jwsl/framework | @jwsl/core | @jwsl/ui | @jwsl/lib |
|-----------------|------------|----------|-----------|
| 1.0.x | 0.9.x+ | 0.8.x+ | 0.7.x+ |
| 1.1.x | 0.10.x+ | 0.9.x+ | 0.8.x+ |

### 권장 릴리즈 세트

프로덕션 환경에서는 검증된 릴리즈 세트 사용을 권장한다.

```json
// 2026-01 릴리즈 세트
{
  "@jwsl/react": "19.1.0",
  "@jwsl/next": "16.1.0",
  "@jwsl/framework": "1.1.0",
  "@jwsl/core": "0.10.0",
  "@jwsl/ui": "0.9.0",
  "@jwsl/lib": "0.8.0"
}
```

---

## 관련 문서

- [정책 문서 (MUST)](./jw-ui-framework_mfe_policy.md)
- [레퍼런스 문서 (API/구조)](./jw-ui-framework_mfe_reference.md)
- [예시 코드](./jw-ui-framework_mfe.examples.md)
- [@jwsl/framework 빌드 산출물 점검](./jwsl-framework_page-in-build.md)
