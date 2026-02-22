
# 업무도메인(UI + 비즈니스) CRUD 화면 개발 가이드

## 1. 분리 모델

### 1.1 역할별 책임 범위

#### 화면 개발자

| 개발영역 | 제외영역 |
|--------|----------------|
| 화면(UI) 구성 | axios / fetch 직접 호출 |
| 사용자 이벤트 연결 | API URL 직접 작성 |
| 훅 호출 및 데이터 바인딩 | 인증 토큰 처리 |
| UI 상태 관리 (모달, 탭) | 비즈니스 로직 JSX 안에 작성 |
| | 전역 상태 임의 생성 |

#### 비즈니스 화면로직 개발자

| 개발영역 | 제외영역 |
|--------|----------------|
| 타입/스키마 정의 (`types/`) | JSX 작성 |
| API 엔드포인트 정의 (`api/`) | 스타일/레이아웃 |
| 비즈니스 서비스 (`services/`) | UI 컴포넌트 선택 |
| 화면용 훅 정의 (`hooks/`) | |
| 검증 규칙 정의 (`schema/`) | |

#### 플랫폼 (@jwsl/*)

| 제공 항목 | 패키지/모듈 |
|----------|------------|
| HTTP 클라이언트, 인터셉터 | `@jwsl/framework/api` |
| 인증/토큰 관리 | Gateway 정책 |
| 전역 에러 핸들링 | `@jwsl/core` ErrorBoundary |
| Router 구현 | `@jwsl/core` useRouter |
| 공통 UI 컴포넌트 | `@jwsl/ui/*` |
| 상태 관리 훅 | `@jwsl/framework/hooks` |

### 1.2 폴더 구조

> 도메인(업무명 또는 서비스명): `sample/`

#### 비즈니스 로직 개발자 담당 영역

| 폴더 | 파일 | 설명 |
|------|------|------|
| `types/` | `sample.types.ts` | 타입 정의 |
| | `index.ts` | re-export |
| `schema/` | `sample.schema.ts` | Zod 검증 스키마 |
| | `index.ts` | re-export |
| `api/` | `sample.api.ts` | API 엔드포인트 |
| | `index.ts` | re-export |
| `services/` | `sample.service.ts` | 비즈니스 로직 (순수 함수) |
| | `index.ts` | re-export |
| `hooks/` | `useSampleList.ts` | 목록 조회 훅 |
| | `useSampleDetail.ts` | 상세 조회 훅 |
| | `useSampleCreate.ts` | 등록 훅 |
| | `useSampleEdit.ts` | 수정 훅 |
| | `index.ts` | re-export |

#### 화면 개발자 담당 영역
| 폴더 | 파일 | 설명 |
|------|------|------|
| `ui/` | `sampleListPage.tsx` | 목록 페이지 |
| | `sampleDetailPage.tsx` | 상세 페이지 |
| | `sampleCreatePage.tsx` | 등록 페이지 |
| | `sampleEditPage.tsx` | 수정 페이지 |
| | `index.ts` | re-export |
| `ui/components/` | `sampleTable.tsx` | 테이블 컴포넌트 |
| | `sampleForm.tsx` | 폼 컴포넌트 |
| | `sampleSearchForm.tsx` | 검색 폼 컴포넌트 |
| | `sampleDeleteModal.tsx` | 삭제 확인 모달 |

#### 공통

| 파일 | 담당자 | 설명 |
|------|--------|------|
| `index.ts` | 비즈니스 로직 개발자 | 도메인 Public API |

### 1.3 역할별 담당 파일 요약

| 폴더 | 담당자 | 파일 예시 | 설명 |
|------|--------|----------|------|
| `types/` | 비즈니스 개발자 | `sample.types.ts` | 타입 정의 |
| `schema/` | 비즈니스 개발자 | `sample.schema.ts` | Zod 검증 스키마 |
| `api/` | 비즈니스 개발자 | `sample.api.ts` | API 엔드포인트 |
| `services/` | 비즈니스 개발자 | `sample.service.ts` | 비즈니스 로직 (순수 함수) |
| `hooks/` | 비즈니스 개발자 | `useSampleList.ts` | 화면용 훅 |
| `ui/` | **화면 개발자** | `sampleListPage.tsx` | 모든 UI 코드 |

### 1.4 협업 흐름

| 단계 | 비즈니스 개발자 산출 | 임포트(화면개발자) | 화면 개발자 산출 | 비고 |
|---|---|---|---|---|
| 1 | `types/sample.types.ts` | `import type { Sample, SampleFormInput } from '../types'` | - | 화면에서 타입만 사용 |
| 2 | `schema/sample.schema.ts` | `import type { SampleFormInput } from '../schema'` | - | 스키마는 훅에서 검증에 사용 |
| 3 | `api/sample.api.ts` | (직접 사용 금지, 훅에서만 사용) | - | 화면에서 URL 직접 작성 금지 |
| 4 | `services/sample.service.ts` | `import { sampleService } from '../services'` | - | JSX 안의 비즈니스 로직 최소화(순수 함수만 호출) |
| 5 | `hooks/useSampleList.ts`, `hooks/useSampleCreate.ts` 등 | `import { useSampleList, useSampleCreate } from '../hooks'` | - | 화면은 훅 결과 바인딩/이벤트 연결만 수행 |
| 6 | - | - | `ui/**` (예: `ui/SampleListPage.tsx`) | 화면 개발자는 `ui/` 폴더만 수정 |

### 1.5 화면 개발자가 사용하는 것 (import 대상)

```text
// [허용] 화면 개발자가 import 하는 것
import { useSampleList, useSampleCreate } from '../hooks';  // 훅
import { sampleService } from '../services';               // 비즈니스 로직
import type { Sample, SampleFormInput } from '../types';    // 타입

// [허용] 플랫폼에서 import 하는 것
import { Button, Table, Stack } from '@jwsl/ui/mantine';       // UI 컴포넌트
import { useFormState, useToggle } from '@jwsl/framework/hooks'; // 상태 훅
import { useRouter } from '@jwsl/core';                        // 라우터
```

---

## 2. 목적 (sample CRUD 기준)

- 화면 개발자는 **업무도메인 UI를 구성하고 CRUD 이벤트를 처리**한다.
- 데이터 호출/인증/토큰/인터셉터/표준 에러 처리는 **플랫폼(@jwsl/*)이 책임**진다.

핵심 원칙:
- 화면 코드는 "API URL/인증/토큰/저수준 훅"을 직접 다루지 않는다.
- 화면 코드는 "Feature 단위 구조 + 공개 API(index.ts) + 표준 훅(@jwsl/framework/hooks)"만 사용한다.

---

## 3. 필수정책 및 제약

1) **Hook 정책**
- 금지: `react` 또는 `@jwsl/react`에서 `useState`, `useEffect` 직접 import
- 필수: `@jwsl/framework/hooks`의 선언적 훅 사용 (`useFormState`, `useListState`, `useToggle`, `useMount`, `useUpdateEffect`)

2) **Router 단일 진입**
- 필수: 라우터 접근은 `@jwsl/core`의 RouterContext 훅만 사용 (`useRouter`, `usePathname`)
- 금지: `next/router`, `next/navigation` 직접 import

3) **HTTP 호출 표준화**
- 금지: `fetch`, `axios` 직접 호출
- 필수: `@jwsl/framework/api` 또는 `@jwsl/framework/hooks`의 `useApiRequest`를 통해 호출

4) **런타임 레이어 경계**
- Screen 개발자는 `@jwsl/ui`, `@jwsl/lib`, `@jwsl/core`, `@jwsl/framework`를 사용한다.
- `@jwsl/react`, `@jwsl/next`는 "직접 사용"이 아니라 "플랫폼 내부/경로 래핑" 용도다.

5) **의존성/Feature 경계**
- Feature는 `index.ts`로 공개 API만 노출
- 다른 Feature의 내부 폴더 접근 금지 (`components/*`, `hooks/*` 직접 import 금지)

6) **스키마 기반 폼 검증**
- 금지: 컴포넌트 내 인라인 검증 로직 (`if (!title) alert(...)`)
- 필수: `@jwsl/framework/validation`의 `z`, `createSimpleSchema`, `useFormValidation` 사용
- 필수: 스키마에서 타입 추론 (`z.infer<typeof schema>`)
- 필수: `form.errors`를 UI `error` prop에 연결

---

## 4. 화면 개발 단계(권장)

### 시작 전 정책 체크

- Hook: `react`/`@jwsl/react`에서 `useState`/`useEffect` 직접 import 금지 → `@jwsl/framework/hooks` 사용
- Router: `next/*` 직접 import 금지 → `@jwsl/core`의 `useRouter`, `usePathname`, `useQuery`만 사용
- HTTP: `fetch`/`axios` 직접 호출 금지 → `@jwsl/framework/api` 또는 `@jwsl/framework/hooks` 사용

### Step 1. 구조 선택 (도메인 통합 vs Feature 분리)

- 파일 수 최소화가 목표면 “도메인 통합(최소 파일)” 구조를 우선 적용한다.
- 복잡도가 증가하면 `sample-list/sample-detail/...` Feature 구조로 분리한다.

### Step 2. 타입/스키마 정의

- `types.ts`: API 요청/응답 타입
- `schema.ts`: Zod 스키마 및 `z.infer` 기반 타입 추론

### Step 3. API 모듈 정의

- URL/Method는 `api.ts` 또는 `*/api/*.ts`에만 정의한다.
- View에서 URL 문자열 조합 금지.

### Step 4. Hook 구성

- Read(목록/상세): `useApiRequest` + `useMount`/`useUpdateEffect`로 선언적 조회(loading/error/data)
- Mutation(등록/수정/삭제): `useApiRequest` 사용
- 에러는 `@jwsl/framework/error`의 `useErrorHandler().addError(...)`로 등록(커스텀 분기 최소화)

### Step 5. View 구현

- View는 “UI + 이벤트 연결 + 훅 결과 바인딩”만 포함한다.
- 로직은 types/schema/api/hooks로 이동한다.

### Step 6. 파라미터/네비게이션 연결

- 이동: `const router = useRouter(); router.push('/path')`
- 파라미터: `const query = useQuery(); const id = query.id` 패턴을 기본으로 사용한다.

### Step 7. 로딩/에러 UI 통일

- 로딩: `loading` 기반으로 로딩 UI 노출
- 에러: 훅의 `error` 기반으로 표준 Error UI 또는 `addError()` 전역 등록

---

## 5. 비즈니스 로직 개발 예시 코드

> 이 섹션의 모든 코드는 **비즈니스 로직 개발자**가 작성한다.

### 5.1 types/sample.types.ts (타입 정의)

```javaScript
// sample/types/sample.types.ts
// 담당: 비즈니스 로직 개발자

/** 게시글 엔티티 */
export interface Sample {
  id: string;
  title: string;
  content: string;
  author: string;
  createdAt: string;
  updatedAt: string;
  viewCount: number;
  status: SampleStatus;
}

/** 게시글 상태 */
export type SampleStatus = 'draft' | 'published' | 'deleted';

/** 목록 조회 쿼리 */
export interface SampleListQuery {
  page: number;
  pageSize: number;
  keyword?: string;
  searchType?: 'title' | 'content' | 'author';
  status?: SampleStatus;
}

/** 목록 조회 응답 */
export interface SampleListResponse {
  items: Sample[];
  total: number;
  page: number;
  pageSize: number;
}

/** 등록/수정 입력 (스키마에서 추론) */
export type { SampleFormInput } from '../schema';
```

### 5.2 schema/sample.schema.ts (검증 스키마)

```javaScript
// sample/schema/sample.schema.ts
// 담당: 비즈니스 로직 개발자

import { z } from '@jwsl/framework/validation';

/** 게시글 등록/수정 스키마 */
export const sampleFormSchema = z.object({
  title: z.string()
    .min(1, '제목을 입력하세요')
    .max(100, '제목은 100자 이내로 입력하세요'),
  content: z.string()
    .min(1, '내용을 입력하세요')
    .max(10000, '내용은 10000자 이내로 입력하세요'),
  status: z.enum(['draft', 'published']).default('draft'),
});

/** 스키마에서 타입 추론 */
export type SampleFormInput = z.infer<typeof sampleFormSchema>;

/** 검색 폼 스키마 */
export const sampleSearchSchema = z.object({
  keyword: z.string().optional(),
  searchType: z.enum(['title', 'content', 'author']).optional(),
});

export type SampleSearchInput = z.infer<typeof sampleSearchSchema>;
```

### 5.3 api/sample.api.ts (API 엔드포인트)

```javaScript
// sample/api/sample.api.ts
// 담당: 비즈니스 로직 개발자

import { api } from '@jwsl/framework/api';
import type { Sample, SampleListQuery, SampleListResponse } from '../types';
import type { SampleFormInput } from '../schema';

export const sampleApi = {
  /** API base path (single source of truth) */
  basePath: '/api/sample',

  /** 목록 조회 */
  getList: (query: SampleListQuery) =>
    api.get<SampleListResponse>(sampleApi.basePath, { params: query }),

  /** 상세 조회 */
  getDetail: (id: string) =>
    api.get<Sample>(`${sampleApi.basePath}/${id}`),

  /** 등록 */
  create: (input: SampleFormInput) =>
    api.post<Sample>(sampleApi.basePath, input),

  /** 수정 */
  update: (id: string, input: SampleFormInput) =>
    api.put<Sample>(`${sampleApi.basePath}/${id}`, input),

  /** 삭제 */
  delete: (id: string) =>
    api.delete(`${sampleApi.basePath}/${id}`),
};
```

### 5.4 services/sample.service.ts (비즈니스 로직)

```javaScript
// sample/services/sample.service.ts
// 담당: 비즈니스 로직 개발자
// 특징: React/UI에 의존하지 않는 순수 함수

import type { Sample, SampleStatus } from '../types';

export const sampleService = {
  /** 상태 라벨 변환 */
  getStatusLabel: (status: SampleStatus): string => {
    const labels: Record<SampleStatus, string> = {
      draft: '임시저장',
      published: '게시됨',
      deleted: '삭제됨',
    };
    return labels[status] ?? status;
  },

  /** 조회수 포맷 */
  formatViewCount: (count: number): string => {
    if (count >= 10000) return `${(count / 10000).toFixed(1)}만`;
    if (count >= 1000) return `${(count / 1000).toFixed(1)}천`;
    return String(count);
  },

  /** 작성일 포맷 */
  formatDate: (dateString: string): string => {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) return '오늘';
    if (days === 1) return '어제';
    if (days < 7) return `${days}일 전`;
    return date.toLocaleDateString('ko-KR');
  },

  /** 게시글 요약 생성 */
  getSummary: (item: Sample, maxLength = 100): string => {
    if (item.content.length <= maxLength) return item.content;
    return item.content.slice(0, maxLength) + '...';
  },

  /** 수정 가능 여부 */
  canEdit: (item: Sample, userId: string): boolean => {
    return item.author === userId && item.status !== 'deleted';
  },

  /** 삭제 가능 여부 */
  canDelete: (item: Sample, userId: string): boolean => {
    return item.author === userId && item.status !== 'deleted';
  },
};
```

### 5.5 hooks/ (화면용 훅)

```javaScript
// sample/hooks/useSampleList.ts
// 담당: 비즈니스 로직 개발자

import { useApiRequest, useMount, useUpdateEffect } from '@jwsl/framework/hooks';
import type { SampleListQuery, SampleListResponse } from '../types';
import { sampleApi } from '../api';

export function useSampleList(query: SampleListQuery) {
  const listQuery = useApiRequest<SampleListResponse>({
    requestFn: () => sampleApi.getList(query),
  });

  // 마운트 시 자동 조회
  useMount(() => {
    listQuery.execute();
  });

  // 검색 조건 변경 시 재조회
  useUpdateEffect(() => {
    listQuery.execute();
  }, [query.page, query.pageSize, query.keyword, query.searchType]);

  return listQuery;
}
```

```javaScript
// sample/hooks/useSampleDetail.ts
// 담당: 비즈니스 로직 개발자

import { useApiRequest, useMount } from '@jwsl/framework/hooks';
import { useRouter } from '@jwsl/core';
import { sampleApi } from '../api';

export function useSampleDetail(id: string) {
  const { navigate } = useRouter();

  const detail = useApiRequest({
    requestFn: () => sampleApi.getDetail(id),
  });

  // id가 있을 때만 마운트 시 자동 조회
  useMount(() => {
    if (id) {
      detail.execute();
    }
  });

  const deleteMutation = useApiRequest({
    requestFn: () => sampleApi.delete(id),
    onSuccess: () => navigate('/sample'),
  });

  return { detail, deleteMutation };
}
```

```javaScript
// sample/hooks/useSampleCreate.ts
// 담당: 비즈니스 로직 개발자

import { useApiRequest } from '@jwsl/framework/hooks';
import { useFormValidation } from '@jwsl/framework/validation';
import { useRouter } from '@jwsl/core';
import { sampleApi } from '../api';
import { sampleFormSchema, type SampleFormInput } from '../schema';

export function useSampleCreate() {
  const { navigate } = useRouter();

  const form = useFormValidation<SampleFormInput>({
    schema: sampleFormSchema,
    defaultValues: { title: '', content: '', status: 'draft' },
  });

  const mutation = useApiRequest({
    requestFn: (data: SampleFormInput) => sampleApi.create(data),
    onSuccess: (result) => navigate(`/sample/${result.id}`),
  });

  const onSubmit = form.handleSubmit((data) => mutation.execute(data));

  return { form, mutation, onSubmit };
}
```

```javaScript
// sample/hooks/useSampleEdit.ts
// 담당: 비즈니스 로직 개발자

import { useApiRequest, useMount, useUpdateEffect } from '@jwsl/framework/hooks';
import { useFormValidation } from '@jwsl/framework/validation';
import { useRouter } from '@jwsl/core';
import { sampleApi } from '../api';
import { sampleFormSchema, type SampleFormInput } from '../schema';

export function useSampleEdit(id: string) {
  const { navigate } = useRouter();

  // 기존 데이터 로드
  const detail = useApiRequest({
    requestFn: () => sampleApi.getDetail(id),
  });

  // id가 있을 때만 마운트 시 자동 조회
  useMount(() => {
    if (id) {
      detail.execute();
    }
  });

  // 폼 상태
  const form = useFormValidation<SampleFormInput>({
    schema: sampleFormSchema,
    defaultValues: { title: '', content: '', status: 'draft' },
  });

  // 기존 데이터 로드 시 폼에 반영
  useUpdateEffect(() => {
    if (detail.data) {
      form.reset({
        title: detail.data.title,
        content: detail.data.content,
        status: detail.data.status,
      });
    }
  }, [detail.data]);

  // 수정 요청
  const mutation = useApiRequest({
    requestFn: (data: SampleFormInput) => sampleApi.update(id, data),
    onSuccess: () => navigate(`/sample/${id}`),
  });

  const onSubmit = form.handleSubmit((data) => mutation.execute(data));

  return { detail, form, mutation, onSubmit };
}
```

```javaScript
// sample/hooks/index.ts
// 담당: 비즈니스 로직 개발자

export { useSampleList } from './useSampleList';
export { useSampleDetail } from './useSampleDetail';
export { useSampleCreate } from './useSampleCreate';
export { useSampleEdit } from './useSampleEdit';
```

---

## 6. 화면 개발 예시 코드

> 이 섹션의 모든 코드는 **화면 개발자**가 작성한다.
> 화면 개발자는 `ui/` 폴더만 수정하며, hooks/api/types/schema/services는 import만 한다.

### 6.1 ui/SampleListPage.tsx (목록 화면)

```javaScript
// sample/ui/SampleListPage.tsx
// 담당: 화면 개발자
'use client';

import { Table, Pagination, TextInput, Button, Stack, Group } from '@jwsl/ui/mantine';
import { useFormState } from '@jwsl/framework/hooks';
import { useRouter } from '@jwsl/core';
import { useSampleList } from '../hooks';           // 훅 import
import { sampleService } from '../services';        // 비즈니스 로직 import

export default function SampleListPage() {
  const { navigate } = useRouter();

  // UI 상태 (검색/페이징)
  const filter = useFormState({
    initialValues: { page: 1, pageSize: 10, keyword: '' },
  });

  // 데이터 조회 (훅 호출)
  const { data, isLoading, error } = useSampleList(filter.values);

  // 이벤트 핸들러
  const handleSearch = () => filter.setValue('page', 1);
  const handleCreate = () => navigate('/sample/create');
  const handleRowClick = (id: string) => navigate(`/sample/${id}`);

  if (error) return null; // ErrorBoundary가 처리

  return (
    <Stack gap="md">
      {/* 검색 영역 */}
      <Group>
        <TextInput
          placeholder="검색어 입력"
          value={filter.values.keyword}
          onChange={(e) => filter.setValue('keyword', e.target.value)}
        />
        <Button onClick={handleSearch}>검색</Button>
        <Button onClick={handleCreate}>글쓰기</Button>
      </Group>

      {/* 테이블 */}
      <Table
        data={data?.items ?? []}
        loading={isLoading}
        columns={[
          { key: 'title', header: '제목' },
          { key: 'author', header: '작성자' },
          {
            key: 'createdAt',
            header: '작성일',
            render: (row) => sampleService.formatDate(row.createdAt),  // 비즈니스 로직 사용
          },
          {
            key: 'viewCount',
            header: '조회수',
            render: (row) => sampleService.formatViewCount(row.viewCount),  // 비즈니스 로직 사용
          },
        ]}
        onRowClick={(row) => handleRowClick(row.id)}
      />

      {/* 페이징 */}
      <Pagination
        total={Math.ceil((data?.total ?? 0) / filter.values.pageSize)}
        value={filter.values.page}
        onChange={(page) => filter.setValue('page', page)}
      />
    </Stack>
  );
}
```

### 6.2 ui/SampleDetailPage.tsx (상세 화면)

```javaScript
// sample/ui/SampleDetailPage.tsx
// 담당: 화면 개발자
'use client';

import { Stack, Title, Text, Button, Group, Modal, Loading } from '@jwsl/ui/mantine';
import { useToggle } from '@jwsl/framework/hooks';
import { useRouter, useParams } from '@jwsl/core';
import { useSampleDetail } from '../hooks';          // 훅 import
import { sampleService } from '../services';         // 비즈니스 로직 import

export default function SampleDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { navigate } = useRouter();
  const [isDeleteOpen, toggleDelete] = useToggle(false);

  // 데이터 조회 + 삭제 (훅 호출)
  const { detail, deleteMutation } = useSampleDetail(id);

  // 이벤트 핸들러
  const handleEdit = () => navigate(`/sample/${id}/edit`);
  const handleList = () => navigate('/sample');
  const handleDelete = () => deleteMutation.execute();

  if (detail.isLoading) return <Loading />;
  if (detail.error) return null;

  const item = detail.data;

  return (
    <Stack gap="md">
      <Title order={2}>{item?.title}</Title>

      <Group>
        <Text size="sm" c="dimmed">작성자: {item?.author}</Text>
        <Text size="sm" c="dimmed">
          작성일: {sampleService.formatDate(item?.createdAt ?? '')}
        </Text>
        <Text size="sm" c="dimmed">
          조회수: {sampleService.formatViewCount(item?.viewCount ?? 0)}
        </Text>
      </Group>

      <Text>{item?.content}</Text>

      <Group>
        <Button onClick={handleList}>목록</Button>
        <Button onClick={handleEdit}>수정</Button>
        <Button color="red" onClick={() => toggleDelete.setTrue()}>삭제</Button>
      </Group>

      {/* 삭제 확인 모달 */}
      <Modal opened={isDeleteOpen} onClose={() => toggleDelete.setFalse()} title="삭제 확인">
        <Text>정말 삭제하시겠습니까?</Text>
        <Group mt="md">
          <Button variant="outline" onClick={() => toggleDelete.setFalse()}>취소</Button>
          <Button color="red" loading={deleteMutation.isLoading} onClick={handleDelete}>
            삭제
          </Button>
        </Group>
      </Modal>
    </Stack>
  );
}
```

### 6.3 ui/SampleCreatePage.tsx (등록 화면)

```javaScript
// sample/ui/SampleCreatePage.tsx
// 담당: 화면 개발자
'use client';

import { Stack, TextInput, Textarea, Button, Group } from '@jwsl/ui/mantine';
import { useRouter } from '@jwsl/core';
import { useSampleCreate } from '../hooks';          // 훅 import

export default function SampleCreatePage() {
  const { navigate } = useRouter();

  // 폼 + 등록 (훅 호출)
  const { form, mutation, onSubmit } = useSampleCreate();

  return (
    <form onSubmit={onSubmit}>
      <Stack gap="md">
        <TextInput
          label="제목"
          placeholder="제목을 입력하세요"
          {...form.register('title')}
          error={form.formState.errors.title?.message}
          required
        />

        <Textarea
          label="내용"
          placeholder="내용을 입력하세요"
          {...form.register('content')}
          error={form.formState.errors.content?.message}
          minRows={10}
          required
        />

        <Group>
          <Button type="button" onClick={() => navigate('/sample')} variant="outline">
            취소
          </Button>
          <Button type="submit" loading={mutation.isLoading}>등록</Button>
        </Group>
      </Stack>
    </form>
  );
}
```

### 6.4 ui/SampleEditPage.tsx (수정 화면)

```javaScript
// sample/ui/SampleEditPage.tsx
// 담당: 화면 개발자
'use client';

import { Stack, TextInput, Textarea, Button, Group, Loading } from '@jwsl/ui/mantine';
import { useRouter, useParams } from '@jwsl/core';
import { useSampleEdit } from '../hooks';            // 훅 import

export default function SampleEditPage() {
  const { id } = useParams<{ id: string }>();
  const { navigate } = useRouter();

  // 기존 데이터 + 폼 + 수정 (훅 호출)
  const { detail, form, mutation, onSubmit } = useSampleEdit(id);

  if (detail.isLoading) return <Loading />;
  if (detail.error) return null;

  return (
    <form onSubmit={onSubmit}>
      <Stack gap="md">
        <TextInput
          label="제목"
          placeholder="제목을 입력하세요"
          {...form.register('title')}
          error={form.formState.errors.title?.message}
          required
        />

        <Textarea
          label="내용"
          placeholder="내용을 입력하세요"
          {...form.register('content')}
          error={form.formState.errors.content?.message}
          minRows={10}
          required
        />

        <Group>
          <Button type="button" onClick={() => navigate(`/sample/${id}`)} variant="outline">
            취소
          </Button>
          <Button type="submit" loading={mutation.isLoading}>수정</Button>
        </Group>
      </Stack>
    </form>
  );
}
```

### 6.5 index.ts (도메인 Public API)

```javaScript
// sample/index.ts
// 담당: 비즈니스 로직 개발자

// Types
export * from './types';

// Schema
export * from './schema';

// API
export * from './api';

// Services
export * from './services';

// Hooks
export * from './hooks';

// UI Pages (화면 개발자가 작성, 여기서 export)
export { default as SampleListPage } from './ui/SampleListPage';
export { default as SampleDetailPage } from './ui/SampleDetailPage';
export { default as SampleCreatePage } from './ui/SampleCreatePage';
export { default as SampleEditPage } from './ui/SampleEditPage';
```

---

## 7. 상태 관리 규칙 (sample 화면)

- 공유 데이터(게시글 목록/상세)는 **Feature 훅의 반환값**으로 관리한다.
- 단순 UI 상태(모달, 탭, 폼)는 `useToggle`, `useFormState` 등으로 관리한다.
- Zustand/Jotai 등 외부 전역 상태 라이브러리 신규 도입은 표준이 아니므로, 필요 시 플랫폼 승인 절차가 필요하다.

권장 매핑:
| 상태 유형 | 사용할 Hook |
|----------|------------|
| 폼 입력값 (검증 필요) | `useFormValidation` (`@jwsl/framework/validation`) |
| 폼 입력값 (검증 불필요) | `useFormState` (`@jwsl/framework/hooks`) |
| 검색/페이징 조건 | `useFormState` |
| 모달 열림/닫힘 | `useToggle` |
| 리스트 선택 상태 | `useListState` |
| 데이터 로드 시 1회 실행 | `useMount` |
| 조건 변경 시 재실행 | `useUpdateEffect` |

---

## 8. 폼 처리 규칙 (sample 등록/수정) - 스키마 패턴

### 8.1 스키마 패턴 원칙

- **선언적 검증**: 스키마에 필드별 규칙을 선언하고, 검증 로직은 플랫폼(`@jwsl/framework/validation`)에 위임한다.
- **타입 추론**: 스키마에서 TypeScript 타입을 자동 추론한다 (`z.infer<typeof schema>`).
- **에러 통합**: `useFormValidation`의 `formState.errors`와 UI 컴포넌트의 `error` prop을 연결한다.

### 8.2 스키마 정의 위치

```
sample/
├── shared/
│   └── schema/
│       └── sampleSchema.ts    ← 공통 스키마 (등록/수정 공유)
├── sample-create/
│   └── hooks/
│       └── useSampleCreate.ts ← 스키마 import 및 검증 실행
└── sample-edit/
    └── hooks/
        └── useSampleEdit.ts   ← 스키마 import 및 검증 실행
```

### 8.3 스키마 검증 흐름 (useFormValidation 기반)

```
┌─────────────────────────────────────────────────────────────┐
│  1. 스키마 정의 (shared/schema/sampleSchema.ts)                │
│     - z.string().min(1, '에러메시지')                         │
│     - 타입 추론: type SampleFormInput = z.infer<...>          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 훅에서 폼 초기화 (hooks/useSampleCreate.ts)                 │
│     - useFormValidation(sampleFormSchema, { defaultValues })  │
│     - form.handleSubmit() 호출 시 자동 검증                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  3. 뷰에서 에러 표시 (view/index.tsx)                         │
│     - {...form.register('title')}                           │
│     - error={form.formState.errors.title?.message}          │
└─────────────────────────────────────────────────────────────┘
```

### 8.4 스키마 규칙 예시

```text
// sample/shared/schema/sampleSchema.ts
import { z } from '@jwsl/framework/validation';

export const sampleFormSchema = z.object({
  // 필수 + 최대 길이
  title: z.string()
    .min(1, '제목을 입력하세요')
    .max(100, '제목은 100자 이내로 입력하세요'),

  // 필수 + 최대 길이
  content: z.string()
    .min(1, '내용을 입력하세요')
    .max(10000, '내용은 10000자 이내로 입력하세요'),

  // 선택적 필드
  category: z.string().optional(),

  // 열거형
  status: z.enum(['draft', 'published']).default('draft'),

  // 숫자 범위
  priority: z.number().min(1).max(10).optional(),

  // 이메일 형식
  authorEmail: z.string().email('올바른 이메일 형식이 아닙니다').optional(),

  // 커스텀 검증
  tags: z.array(z.string()).max(5, '태그는 최대 5개까지 가능합니다').optional(),
});

export type SampleFormInput = z.infer<typeof sampleFormSchema>;
```

### 8.5 useFormValidation 사용법

```javaScript
// hooks/useSampleCreate.ts
import { useApiRequest } from '@jwsl/framework/hooks';
import { useFormValidation } from '@jwsl/framework/validation';
import { sampleApi } from '../api';
import { sampleFormSchema } from '../schema';

export function useSampleCreate() {
  // 스키마 기반 폼 상태 관리 (React Hook Form + Zod)
  const form = useFormValidation(sampleFormSchema, {
    defaultValues: { title: '', content: '' },
  });

  // API 요청은 useApiRequest 사용
  const mutation = useApiRequest({
    requestFn: (data) => sampleApi.create(data),
  });

  // form.handleSubmit()은 제출 시 스키마 검증을 자동 실행
  const onSubmit = form.handleSubmit((data) => mutation.execute(data));

  return { form, mutation, onSubmit };
}

// ui/SampleCreatePage.tsx (뷰에서 사용)
<form onSubmit={onSubmit}>
  <TextInput
    {...form.register('title')}
    error={form.formState.errors.title?.message}
  />
</form>
```

---

## 9. 환경 설정

### 9.1 NEXT_PUBLIC_ROUTER_MODE

`NEXT_PUBLIC_ROUTER_MODE`는 `.env.development` / `.env.production`에서 설정합니다.

```bash
# .env.development / .env.production
NEXT_PUBLIC_ROUTER_MODE=app    # app | page
```

| 항목 | 설명 |
|------|------|
| 허용 값 | `app` (App Router) 또는 `page` (Pages Router) |
| 평가 시점 | 빌드 타임 (Next.js 인라인) |
| 접근 방법 | `APP_CONFIG.routerMode` 또는 `isAppRouter()` (`@jwsl/_configs/app`) |
| 디렉토리 규칙 | `app` → `app/` 디렉토리만 사용, `page` → `pages/` 디렉토리만 사용 |

> **참고:** 싱글소스 모델(단일 페이지 화면 개발)에서는 `NEXT_PUBLIC_ROUTER_MODE=app` 고정입니다. `page` 모드는 Gateway 멀티 도메인 구성에서 사용됩니다.

---

## 10. 에러 처리 규칙

### 10.1 프레임워크 기본 에러 처리

`CoreProvider`를 마운트하면 **별도 설정 없이** 아래 에러 처리가 자동 적용됩니다:

| 레벨 | 컴포넌트 | 기본 동작 (주입 없이) | 커스텀 주입 prop |
|------|---------|---------------------|----------------|
| **L1 Root** | `ErrorBoundary` | `DefaultErrorUI` 전체화면 표시 + 재시도 버튼 | `errorFallback` |
| **L2 Init** | `CoreInitChecker` | `DefaultErrorUI` + 재시도/홈 버튼 + 트러블슈팅 팁 | `errorFallback` |
| **API 에러** | `ApiErrorModal` | CSS-in-JS 기본 모달 팝업 + 재시도/확인 버튼 | `renderApiError` |

- 개발 환경(`isDevelopment()`)에서는 **콘솔에 상세 에러 정보가 자동 출력**됩니다 (component stack, API URL/method 등).
- Burst 감지(1초 내 5회 에러)로 무한 루프를 자동 차단합니다.
- 개발자가 `fallback`/`renderApiError`를 주입하면 기본 UI를 커스텀 UI로 교체할 수 있습니다.

### 10.2 에러 처리 원칙

- 화면에서 임의의 `try/catch`로 정책을 우회하지 않는다.
- `useApiRequest`의 `error`를 UI 레벨에서 표준 컴포넌트로 표시한다.
- 인증(401)/권한(403)은 Gateway 정책에 따라 리다이렉트/표준 페이지로 처리된다.

### 10.3 Feature 단위 ErrorBoundary

`CoreProvider`에 L1/L2가 내장되어 있으므로 Feature 코드에서는 **기능 격리가 필요한 경우에만** 추가합니다:

```typescript
import { ErrorBoundary } from '@jwsl/core';

// 선택: 특정 Feature를 격리해야 할 때만 래핑
<ErrorBoundary fallback={<Text>기능을 불러올 수 없습니다.</Text>}>
  <SampleListPage />
</ErrorBoundary>
```

> **참고:** fallback을 생략하면 `DefaultErrorUI`가 기본 표시됩니다. 별도 fallback 작성은 선택 사항입니다.

---

## 11. PR 체크리스트 (역할별)

### 비즈니스 로직 개발자 체크리스트

**types/ 폴더**
- [ ] 모든 API 요청/응답 타입 정의
- [ ] 엔티티 인터페이스 정의
- [ ] 열거형(enum) 타입 정의

**schema/ 폴더**
- [ ] Zod 스키마 정의 (`@jwsl/framework/validation`의 `z` 사용)
- [ ] `z.infer`로 타입 추론 export
- [ ] 검증 메시지 한국어로 작성

**api/ 폴더**
- [ ] `@jwsl/framework/api` 사용 (`fetch`/`axios` 직접 호출 금지)
- [ ] CRUD 메서드 명명 규칙 준수 (`getList`, `getDetail`, `create`, `update`, `delete`)
- [ ] 타입 안전성 확보 (제네릭 사용)

**services/ 폴더**
- [ ] 순수 함수로 작성 (React/UI 의존성 없음)
- [ ] 비즈니스 규칙 로직만 포함
- [ ] 테스트 가능한 형태로 작성

**hooks/ 폴더**
- [ ] `@jwsl/framework/hooks` 사용 (`useState`/`useEffect` 직접 import 금지)
- [ ] `useApiRequest` + `useMount`/`useUpdateEffect` 사용
- [ ] `useFormValidation` + 스키마 통합
- [ ] 성공/에러 콜백 정의

---

### 화면 개발자 체크리스트

**공통**
- [ ] `ui/` 폴더 내에서만 작업
- [ ] `@jwsl/ui/*` 컴포넌트 우선 사용
- [ ] `@jwsl/framework/hooks`의 `useFormState`, `useToggle` 사용
- [ ] `@jwsl/core`의 `useRouter`, `useParams` 사용
- [ ] `next/*` 직접 import 금지

**훅/서비스 사용**
- [ ] hooks에서 제공하는 훅만 호출 (직접 구현 금지)
- [ ] services의 비즈니스 로직 활용 (JSX 내 로직 금지)
- [ ] types에서 타입 import

**CRUD 화면별**

| 화면 | 체크 항목 |
|------|----------|
| **목록** | 페이징/검색 상태 관리, 로딩 표시, 빈 데이터 처리 |
| **상세** | ID 파라미터 처리, 로딩/에러 상태 처리 |
| **등록** | `form.register()` + `formState.errors` 연결, 성공 후 이동 |
| **수정** | 기존 데이터 로드 확인, 스키마 검증 에러 표시 |
| **삭제** | 삭제 확인 모달, 성공 후 목록 이동 |

---

## 12. 다음 단계 (권장)

- sample 화면 1개를 선정해(예: `sample-list`) "Feature 구조 + 선언적 훅 + 표준 API"로 스캐폴딩한다.
- 예시 코드는 [Examples](./jw-ui-framework_mfe.examples.md)에만 추가하고, 이 문서는 원칙/체크리스트만 유지한다.
