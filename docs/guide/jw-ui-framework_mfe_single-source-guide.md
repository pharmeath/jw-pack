# 업무도메인 싱글소스 CRUD 화면 개발 가이드

> 백엔드 : ../../server/jw-api
> 풀스택 개발자를 위한 단일 파일 기반 개발 표준

## 1. 개요

### 1.1 싱글소스 모델이란?

싱글소스 모델은 **풀스택 개발자가 하나의 파일(또는 최소 파일)에서 화면과 비즈니스 로직을 함께 개발**하는 방식입니다.

> **중요(정책 우선)**: 싱글소스 모델은 "파일/폴더 분리 수준"만 단순화하는 개발 방식이며,
> `jw-ui-framework_mfe_policy.md`의 MUST 정책(저수준 Hook 금지, `next/*` 직접 import 금지, HTTP 호출 표준화 등)은 **동일하게 적용**됩니다.

| 구분 | 분리 모델 | 싱글소스 모델 |
|------|----------|--------------|
| 대상 | 화면 개발자 + 비즈니스 로직 개발자 | **풀스택 개발자 (1인)** |
| 파일 구조 | types/, schema/, api/, services/, hooks/, ui/ 분리 | **단일 파일 또는 최소 파일** |
| 협업 | 역할별 담당 영역 구분 | 개인 또는 소규모 팀 |
| 적합 케이스 | 대규모 팀, 역할 전문화 | **빠른 개발, 소규모 프로젝트, 프로토타이핑** |

### 1.2 싱글소스 모델 선택 기준

**싱글소스 권장:**
- 풀스택 개발자 1인 개발
- 소규모 팀 (2~3명)
- 빠른 프로토타이핑 필요
- 화면 수가 적은 프로젝트 (10개 미만)
- 비즈니스 로직이 단순한 경우

**분리 모델 권장:**
- 대규모 팀 (4명 이상)
- 화면 개발자/비즈니스 로직 개발자 역할 분리
- 복잡한 비즈니스 로직
- 재사용 컴포넌트가 많은 경우

---

## 2. 폴더 구조

### 2.1 기본 구조 (싱글 파일)

```
screens/
├── sample/
│   ├── index.ts              # Public API (re-export)
│   ├── SampleListPage.tsx    # 목록 화면 (타입 + API + 훅 + UI 통합)
│   ├── SampleDetailPage.tsx  # 상세 화면
│   ├── SampleCreatePage.tsx  # 등록 화면
│   └── SampleEditPage.tsx    # 수정 화면
```

### 2.2 index.ts (Public API)

도메인 루트의 `index.ts`는 외부에서 접근할 수 있는 공개 API를 re-export합니다.

```typescript
// screens/sample/index.ts

// UI Pages
export { default as SampleListPage } from './SampleListPage';
export { default as SampleDetailPage } from './SampleDetailPage';
export { default as SampleCreatePage } from './SampleCreatePage';
export { default as SampleEditPage } from './SampleEditPage';
```

확장 구조에서 타입/API를 분리한 경우:

```typescript
// screens/sample/index.ts

// Types (다른 도메인에서 참조 시)
export type { Sample, SampleStatus, SampleListResponse } from './sample.types';

// UI Pages
export { default as SampleListPage } from './SampleListPage';
export { default as SampleDetailPage } from './SampleDetailPage';
export { default as SampleCreatePage } from './SampleCreatePage';
export { default as SampleEditPage } from './SampleEditPage';
```

### 2.3 확장 구조 (공유 요소 분리)

복잡도가 증가하면 공통 요소만 분리합니다:

```
screens/
├── sample/
│   ├── index.ts
│   ├── sample.types.ts       # [선택] 타입만 분리 (여러 화면에서 공유 시)
│   ├── sample.api.ts         # [선택] API만 분리 (여러 화면에서 공유 시)
│   ├── sample.service.ts     # [선택] 순수 함수만 분리 (테스트 용이)
│   ├── SampleListPage.tsx
│   ├── SampleDetailPage.tsx
│   ├── SampleCreatePage.tsx
│   └── SampleEditPage.tsx
```

### 2.4 분리 시점 판단

| 상황 | 권장 |
|------|------|
| 타입을 2개 이상 화면에서 사용 | `sample.types.ts` 분리 |
| API를 2개 이상 화면에서 호출 | `sample.api.ts` 분리 |
| 순수 함수 테스트가 필요 | `sample.service.ts` 분리 |
| 그 외 | 싱글 파일 유지 |

---

## 3. 싱글 파일 코드 구조

### 3.1 영역 구분 (필수)

싱글 파일 내에서 **주석 영역**으로 코드를 구조화합니다.
아래 14개 영역 중 해당 없는 영역은 주석만 남기고 비워둡니다.

```typescript
/********************************************************
 * 1. 화면프로그램 jsDoc
 * 화면명 :
 * 화면ID :
 * 프로그램ID :
 * 작성일자 :
 * 작성자 :
 * 화면 설명
 * 유의사항
 ********************************************************/

/********************************************************
 * 2. 이력 영역
 ********************************************************/

/********************************************************
 * 3. import 영역
 ********************************************************/

/********************************************************
 * 4. 글로벌 선언 영역
 * 변수, 스타일(css or cx)
 ********************************************************/

/********************************************************
 * 5. TYPE 정의 영역
 ********************************************************/

/********************************************************
 * 6. API 정의 영역
 ********************************************************/

/********************************************************
 * 7. SERVICE 영역 (순수 함수)
 ********************************************************/

/********************************************************
 * 8. HOOK 영역 (커스텀 훅)
 ********************************************************/

/********************************************************
 * 9. 컴포넌트 시작 (export default function)
 ********************************************************/

/********************************************************
 * 10. STATE 선언 영역
 ********************************************************/

/********************************************************
 * 11. 화면초기화 영역
 * 새로고침시 형상관리 데이터 로드
 * 공통코드, 사용자정보, 다른화면에서 주입받은 데이터
 ********************************************************/

/********************************************************
 * 12. 필수 FUNCTION 영역 (CRUD)
 ********************************************************/

/********************************************************
 * 13. 사용자 FUNCTION 영역
 ********************************************************/

/********************************************************
 * 14. RENDER
 ********************************************************/
```

---

## 4. Import 정책

### 4.1 Import 경로 규칙

화면 개발자는 아래 패키지만 import할 수 있습니다.

| 패키지 | 용도 | 필수 여부 |
|--------|------|----------|
| `@jwsl/framework/hooks` | 선언적 Hook (상태, 생명주기, API, UX) | **필수** |
| `@jwsl/framework/api` | HTTP 클라이언트 (`api.get`, `api.post`) | **필수** |
| `@jwsl/framework/validation` | 폼 검증 (`useFormValidation`, `z`) | 선택 |
| `@jwsl/framework/types` | 공통 타입 (`User`, `MenuItem`, `ApiRequestConfig`) | 선택 |
| `@jwsl/framework/utils` | 유틸리티 (`formatDate`, `formatCurrency`, `StorageManager`) | 선택 |
| `@jwsl/framework/css` | CSS 유틸리티 (`cx`, `cssVar`, `spacing`) | 선택 |
| `@jwsl/framework/icons` | 아이콘 (`IconSearch`, `IconPlus`, `renderIcon`) | 선택 |
| `@jwsl/ui/mantine` | UI 컴포넌트 (Button, Table, Modal, Select 등) | **필수** |
| `@jwsl/core` | 라우터, 인증, 권한 Hook | **필수** |

> **참고**: `@jwsl/framework/{subpath}`는 `@jwsl/lib/{subpath}`를 re-export합니다.
> `@jwsl/lib/hooks`를 직접 import해도 동일하게 동작하지만, 일관성을 위해 `@jwsl/framework/hooks`를 권장합니다.

### 4.2 금지 import

```typescript
// ❌ 금지: react 직접 import
import { useState, useEffect } from 'react';

// ❌ 금지: @jwsl/react에서 저수준 Hook import (화면 개발)
import { useState, useEffect } from '@jwsl/react';

// ❌ 금지: next 직접 import
import { useRouter } from 'next/router';
import { useRouter } from 'next/navigation';
import Link from 'next/link';

// ❌ 금지: @mantine/core 직접 import
import { Paper, Title } from '@mantine/core';

// ❌ 금지: axios 직접 사용
import axios from 'axios';
```

### 4.3 올바른 import 패턴

```typescript
/********************************************************
 * 3. import 영역
 ********************************************************/

// Hook (상태 관리, 생명주기, API, UX)
import {
  useFormState, useListState, useToggle, useSelection,
  useMount, useUpdateEffect,
  useApiRequest, useAutoFetch, useNotification, useCommonCode,
  usePagination, useDebounce, useTableState,
} from '@jwsl/framework/hooks';

// 폼 검증 (Zod 기반)
import { useFormValidation, z } from '@jwsl/framework/validation';

// API 클라이언트
import { api } from '@jwsl/framework/api';

// 유틸리티
import { formatDate, formatCurrency } from '@jwsl/framework/utils';

// CSS 유틸리티
import { cx, spacing } from '@jwsl/framework/css';

// 라우터, 인증, 권한 (반드시 @jwsl/core에서 import)
import { useRouter, useParams, usePathname } from '@jwsl/core';
import { useAuth, useUser, usePermission } from '@jwsl/core';
import { ErrorBoundary } from '@jwsl/core';

// UI 컴포넌트 (반드시 @jwsl/ui/mantine에서 import)
import { Paper, Title, Group, Stack, Badge, Modal, Text } from '@jwsl/ui/mantine';
import { Button, Table, TextInput, Select, Pagination } from '@jwsl/ui/mantine';

// 아이콘
import { IconSearch, IconPlus, IconEdit } from '@jwsl/framework/icons';
```

### 4.4 @jwsl/ui/mantine 컴포넌트 참고

`@jwsl/ui/mantine`에서 import 가능한 컴포넌트:

| 구분 | 컴포넌트 | 비고 |
|------|---------|------|
| **커스텀 (확장 기능)** | `Button`, `Table`, `Modal`, `Select`, `Input`, `Alert`, `DatePicker`, `Grid`, `Calendar`, `Card`, `Badge`, `Code`, `List`, `Menu`, `Search`, `Divider`, `Switch`, `Tabs`, `Toolbar` | `buttonDiv` 등 JW 전용 기능 포함 |
| **Mantine 원본 (재export)** | `Paper`, `Title`, `Group`, `Stack`, `Text`, `TextInput`, `Textarea`, `Pagination`, `NumberInput`, `Checkbox`, `Radio`, `Tooltip`, `Accordion`, `ActionIcon` 등 | @mantine/core 전체 |
| **레이아웃** | `ResponsiveLayout`, `ResponsiveContainer`, `ResponsiveGrid` | 반응형 레이아웃 |

---

## 5. 상태 관리 규칙

### 5.1 Hook 매핑표

| 상태 유형 | 사용할 Hook | import 경로 |
|----------|------------|------------|
| 폼 입력값 (검증 불필요) | `useFormState` | `@jwsl/framework/hooks` |
| 폼 입력값 (Zod 검증) | `useFormValidation` | `@jwsl/framework/validation` |
| 검색/페이징 조건 | `useFormState` | `@jwsl/framework/hooks` |
| 모달 열림/닫힘 | `useToggle` | `@jwsl/framework/hooks` |
| 배열 상태 (선택된 ID 등) | `useListState` | `@jwsl/framework/hooks` |
| 체크박스 다중 선택 | `useSelection` | `@jwsl/framework/hooks` |
| 테이블 통합 상태 (정렬/필터/페이징) | `useTableState` | `@jwsl/framework/hooks` |
| API 조회 (마운트 시 자동) | `useAutoFetch` | `@jwsl/framework/hooks` |
| API 호출 (수동 실행) | `useApiRequest` | `@jwsl/framework/hooks` |
| 마운트 시 1회 실행 | `useMount` | `@jwsl/framework/hooks` |
| 조건 변경 시 재실행 | `useUpdateEffect` | `@jwsl/framework/hooks` |
| 검색 디바운스 | `useDebounce` | `@jwsl/framework/hooks` |
| 공통코드 조회 | `useCommonCode` | `@jwsl/framework/hooks` |
| 토스트 알림 | `useNotification` | `@jwsl/framework/hooks` |
| 파일 업로드 | `useFileUpload` | `@jwsl/framework/hooks` |

### 5.2 저수준 Hook 금지 (예외 없음)

정책 문서(`jw-ui-framework_mfe_policy.md`) 기준으로, 싱글소스 모델이라도 화면 코드는
`react`/`@jwsl/react`의 `useState`/`useEffect`를 직접 사용하지 않습니다.

```typescript
// ❌ 금지
const [value, setValue] = useState('');
useEffect(() => { fetchData(); }, []);

// ✅ 필수
const form = useFormState({ initialValues: { value: '' } });
useMount(() => { fetchData(); });
```

### 5.3 허용되는 React Hook (re-export)

다음 Hook은 `@jwsl/framework/hooks`에서 re-export되어 경고 없이 사용 가능합니다:

```typescript
import { useMemo, useCallback, useRef, useContext, useReducer, useId } from '@jwsl/framework/hooks';
```

이 Hook들은 "상태 관리"가 아닌 "최적화/참조" 용도이므로 직접 사용이 허용됩니다.

---

## 6. API 호출 표준

### 6.1 백엔드 API 구조

```java
// 방식 1: 직접 컨트롤러
@RestController
@RequestMapping("/api/v1/sample-order")
public class SampleOrderController {

    @GetMapping("/list")
    public Map<String, Object> list(@RequestParam Map<String, Object> param) {
        // ...
    }

    @PostMapping("/save")
    public Map<String, Object> save(@RequestBody Map<String, Object> param) {
        // ...
    }
}

// 방식 2: 중앙 컨트롤러 + AOP 서비스빈
@Service
public class SampleOrderService {

    private final SqlxDao dao;

    SampleOrderService(SqlxDao dao) {
        this.dao = dao;
    }

    public ContextServlet list(ApiServletContext request) {
        Map<String, Object> param = request.getParameter();
        return dao.select("ORDER.select_sample_order_list", param);
    }
}

@Repository
public class SampleOrderDao {
    // DAO 구현
}
```

### 6.2 프론트엔드 API 호출

프론트엔드에서 API 호출 시 **상대 경로**를 사용합니다. 실제 백엔드 WAS 주소는 서버(Next.js/Nginx)에서 프록시 매핑합니다.

```typescript
// ❌ 금지: 직접 호출
// import axios from 'axios';
// const data = await axios.get('http://localhost:8080/api/v1/sample-order/list');

// ❌ 금지: 절대 경로 (보안 위험 - 서버 주소 노출)
// const data = await api.get('http://api.example.com/api/v1/sample-order/list');

// ✅ 필수: @jwsl/framework/api + 상대 경로
import { api } from '@jwsl/framework/api';

const data = await api.get('/api/v1/sample-order/list', { params: { page: 1 } });
const result = await api.post('/api/v1/sample-order/save', formData);
```

### 6.3 useAutoFetch vs useApiRequest 선택 기준

| 상황 | 사용 Hook | 설명 |
|------|----------|------|
| 마운트 시 자동 조회 | `useAutoFetch` | 페이지 진입 시 자동으로 데이터 로드 |
| 조건 변경 시 자동 재조회 | `useAutoFetch` + `deps` | 필터/페이지 변경 시 자동 재호출 |
| 버튼 클릭 등 수동 실행 | `useApiRequest` | 저장, 삭제 등 명시적 트리거 |
| 목록 조회 + 검색 | `useAutoFetch` | 초기 로딩 + 필터 변경 자동 처리 |

```typescript
// 자동 조회 (권장: 목록/상세)
const listQuery = useAutoFetch('/api/v1/sample-order/list', {
  params: filter.values,
  deps: [filter.values.page, filter.values.status],
});

// 수동 실행 (저장/삭제)
const saveMutation = useApiRequest({
  requestFn: (data: SampleFormInput) => api.post('/api/v1/sample-order/save', data),
  onSuccess: () => {
    notify.success('저장되었습니다.');
    listQuery.refetch();
  },
});
```

---

## 7. 싱글소스 CRUD 화면 예시

### 7.1 목록 화면 (SampleListPage.tsx)

```typescript
/********************************************************
 * 1. 화면프로그램 jsDoc
 * 화면명 : 샘플 주문 목록
 * 화면ID : SCR-SAMPLE-001
 * 프로그램ID : SampleListPage
 * 작성일자 : 2026-02-07
 * 작성자 : 홍길동
 * 화면 설명 : 샘플 주문 데이터 목록 조회 및 CRUD
 * 유의사항 : 삭제 시 확인 모달 필수
 ********************************************************/

/********************************************************
 * 2. 이력 영역
 * 2026-02-07 v1.0 최초 작성 (홍길동)
 ********************************************************/

/********************************************************
 * 3. import 영역
 ********************************************************/
'use client';

import {
  useFormState, useListState, useToggle,
  useAutoFetch, useApiRequest,
  useNotification, useCommonCode,
  useMount,
} from '@jwsl/framework/hooks';
import { useRouter } from '@jwsl/core';
import { api } from '@jwsl/framework/api';
import { Paper, Title, Group, Stack, Badge, Modal, Text } from '@jwsl/ui/mantine';
import { Button, Table, TextInput, Select, Pagination } from '@jwsl/ui/mantine';
import { IconSearch } from '@jwsl/framework/icons';

/********************************************************
 * 5. TYPE 정의 영역
 ********************************************************/

/** 샘플 엔티티 */
interface Sample {
  id: string;
  title: string;
  content: string;
  status: SampleStatus;
  createdAt: string;
}

/** 상태 타입 */
type SampleStatus = 'draft' | 'published' | 'deleted';

/** 목록 조회 응답 */
interface SampleListResponse {
  items: Sample[];
  total: number;
  page: number;
  pageSize: number;
}

/********************************************************
 * 6. API 정의 영역
 ********************************************************/

const sampleApi = {
  basePath: '/api/v1/sample-order',

  getList: (params: { page: number; pageSize: number; keyword?: string; status?: string }) =>
    api.get<SampleListResponse>(`${sampleApi.basePath}/list`, { params }),

  delete: (id: string) =>
    api.delete(`${sampleApi.basePath}/${id}`),
};

/********************************************************
 * 7. SERVICE 영역 (순수 함수)
 ********************************************************/

const sampleService = {
  getStatusLabel: (status: SampleStatus): string => {
    const labels: Record<SampleStatus, string> = {
      draft: '임시저장',
      published: '게시됨',
      deleted: '삭제됨',
    };
    return labels[status] ?? status;
  },

  getStatusColor: (status: SampleStatus): string => {
    const colors: Record<SampleStatus, string> = {
      draft: 'yellow',
      published: 'green',
      deleted: 'red',
    };
    return colors[status] ?? 'gray';
  },

  formatDate: (dateString: string): string => {
    return new Date(dateString).toLocaleDateString('ko-KR');
  },
};

/********************************************************
 * 9. 컴포넌트 시작
 ********************************************************/

export default function SampleListPage() {
  const { navigate } = useRouter();
  const notify = useNotification();
  const statuses = useCommonCode('SAMPLE_STATUS', { includeAll: true });

  /********************************************************
   * 10. STATE 선언 영역
   ********************************************************/

  const filter = useFormState({
    initialValues: {
      page: 1,
      pageSize: 10,
      keyword: '',
      status: '',
    },
  });

  const selectedIds = useListState<string>([]);
  const [isDeleteOpen, deleteModal] = useToggle(false);

  /********************************************************
   * 11. 화면초기화 영역 (API 자동 조회)
   ********************************************************/

  /** 목록 자동 조회 - 마운트 시 + 필터 변경 시 자동 재호출 */
  const listQuery = useAutoFetch<SampleListResponse>(
    sampleApi.basePath + '/list',
    {
      params: filter.values,
      deps: [filter.values.page, filter.values.status],
    },
  );

  /** 삭제 API */
  const deleteMutation = useApiRequest({
    requestFn: () => Promise.all(selectedIds.state.map((id) => sampleApi.delete(id))),
    onSuccess: () => {
      notify.success('삭제되었습니다.');
      selectedIds.setState([]);
      listQuery.refetch();
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
    listQuery.refetch();
  };

  /** handleCreate - 등록 화면 이동 */
  const handleCreate = () => {
    navigate('/sample/create');
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
    listQuery.refetch();
  };

  /********************************************************
   * 13. 사용자 FUNCTION 영역
   ********************************************************/

  const handleRowClick = (id: string) => {
    navigate(`/sample/${id}`);
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
            placeholder="제목 검색"
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
          <Title order={4}>샘플 목록</Title>
          <Group gap="xs">
            <Badge color="blue">총 {listQuery.data?.total ?? 0}건</Badge>
            <Badge color="green">선택 {selectedIds.state.length}건</Badge>
          </Group>
        </Group>

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
                <Badge color={sampleService.getStatusColor(row.status)}>
                  {sampleService.getStatusLabel(row.status)}
                </Badge>
              ),
            },
            {
              key: 'createdAt',
              header: '작성일',
              render: (row) => sampleService.formatDate(row.createdAt),
            },
          ]}
          onRowClick={(row) => handleRowClick(row.id)}
        />

        <Pagination
          total={Math.ceil((listQuery.data?.total ?? 0) / filter.values.pageSize)}
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
```

### 7.2 등록/수정 화면 (SampleCreatePage.tsx)

```typescript
/********************************************************
 * 1. 화면프로그램 jsDoc
 * 화면명 : 샘플 주문 등록
 * 화면ID : SCR-SAMPLE-002
 * 프로그램ID : SampleCreatePage
 * 작성일자 : 2026-02-07
 * 작성자 : 홍길동
 * 화면 설명 : 샘플 주문 신규 등록
 ********************************************************/

/********************************************************
 * 3. import 영역
 ********************************************************/
'use client';

import { useApiRequest, useNotification } from '@jwsl/framework/hooks';
import { useFormValidation, z } from '@jwsl/framework/validation';
import { useRouter } from '@jwsl/core';
import { api } from '@jwsl/framework/api';
import { Paper, Title, Stack, Group } from '@jwsl/ui/mantine';
import { Button, TextInput, Textarea, Select } from '@jwsl/ui/mantine';

/********************************************************
 * 5. TYPE & SCHEMA 정의 영역
 ********************************************************/

const sampleFormSchema = z.object({
  title: z.string().min(1, '제목을 입력하세요').max(100, '제목은 100자 이내'),
  content: z.string().min(1, '내용을 입력하세요'),
  status: z.enum(['draft', 'published']).default('draft'),
});

type SampleFormInput = z.infer<typeof sampleFormSchema>;

/********************************************************
 * 6. API 정의 영역
 ********************************************************/

const sampleApi = {
  create: (data: SampleFormInput) =>
    api.post<{ id: string }>('/api/v1/sample-order/save', data),
};

/********************************************************
 * 9. 컴포넌트 시작
 ********************************************************/

export default function SampleCreatePage() {
  const { navigate } = useRouter();
  const notify = useNotification();

  /********************************************************
   * 10. STATE / HOOK 영역
   ********************************************************/

  const form = useFormValidation({
    schema: sampleFormSchema,
    defaultValues: { title: '', content: '', status: 'draft' },
  });

  const mutation = useApiRequest({
    requestFn: (data: SampleFormInput) => sampleApi.create(data),
    onSuccess: (result) => {
      notify.success('등록되었습니다.');
      navigate(`/sample/${result.id}`);
    },
    onError: (error) => {
      notify.error(error.message);
    },
  });

  /********************************************************
   * 12. FUNCTION 영역
   ********************************************************/

  const onSubmit = form.handleSubmit((data) => mutation.execute(data));

  /********************************************************
   * 14. RENDER
   ********************************************************/

  return (
    <form onSubmit={onSubmit}>
      <Stack gap="md">
        <Paper p="md" withBorder>
          <Title order={4} mb="md">샘플 등록</Title>

          <Stack gap="sm">
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
              minRows={5}
              required
            />

            <Select
              label="상태"
              data={[
                { value: 'draft', label: '임시저장' },
                { value: 'published', label: '게시' },
              ]}
              {...form.register('status')}
            />
          </Stack>
        </Paper>

        <Group justify="flex-end">
          <Button variant="outline" onClick={() => navigate('/sample')}>취소</Button>
          <Button type="submit" loading={mutation.isLoading}>등록</Button>
        </Group>
      </Stack>
    </form>
  );
}
```

---

## 8. 환경 설정

### 8.1 NEXT_PUBLIC_ROUTER_MODE

싱글소스 모델은 **단일 페이지 화면 개발**이므로 `NEXT_PUBLIC_ROUTER_MODE`는 **항상 `app`**입니다.

```bash
# .env.development / .env.production
NEXT_PUBLIC_ROUTER_MODE=app
```

| 항목 | 값 |
|------|-----|
| 허용 값 | `app` (고정) |
| 평가 시점 | 빌드 타임 (Next.js 인라인) |
| 접근 방법 | `APP_CONFIG.routerMode` 또는 `isAppRouter()` (`@jwsl/_configs/app`) |
| 디렉토리 | `app/` 디렉토리만 사용, `pages/` 생성 금지 |

> **주의:** 싱글소스 모델에서는 `page` 모드를 사용하지 않습니다. Gateway 멀티 도메인 구성에서만 `page` 모드가 허용됩니다.

---

## 9. 에러 처리 규칙

### 9.1 프레임워크 기본 에러 처리

`CoreProvider`를 마운트하면 **별도 설정 없이** 아래 에러 처리가 자동 적용됩니다:

| 레벨 | 컴포넌트 | 기본 동작 (주입 없이) | 커스텀 주입 prop |
|------|---------|---------------------|----------------|
| **L1 Root** | `ErrorBoundary` | `DefaultErrorUI` 전체화면 표시 + 재시도 버튼 | `errorFallback` |
| **L2 Init** | `CoreInitChecker` | `DefaultErrorUI` + 재시도/홈 버튼 + 트러블슈팅 팁 | `errorFallback` |
| **API 에러** | `ApiErrorModal` | CSS-in-JS 기본 모달 팝업 + 재시도/확인 버튼 | `renderApiError` |

- 개발 환경(`isDevelopment()`)에서는 **콘솔에 상세 에러 정보가 자동 출력**됩니다 (component stack, API URL/method 등).
- Burst 감지(1초 내 5회 에러)로 무한 루프를 자동 차단합니다.
- 개발자가 `fallback`/`renderApiError`를 주입하면 기본 UI를 커스텀 UI로 교체할 수 있습니다.

### 9.2 API 에러 처리

```typescript
// ❌ 금지: 임의의 try/catch + alert
try {
  await api.post('/api/v1/sample-order/save', data);
} catch (e) {
  alert('에러 발생');
}

// ✅ 권장: useApiRequest의 onError 콜백
const mutation = useApiRequest({
  requestFn: () => api.post('/api/v1/sample-order/save', data),
  onError: (error) => {
    notify.error(error.message);
  },
});

// ✅ 에러 상태 표시
if (mutation.error) {
  return <Text color="red">{mutation.error.message}</Text>;
}
```

### 9.3 ErrorBoundary 적용

`CoreProvider`에 L1/L2 ErrorBoundary가 내장되어 있으므로 화면 코드에서는 **Feature 단위 격리가 필요한 경우에만** 추가합니다:

```typescript
import { ErrorBoundary } from '@jwsl/core';

// 선택: 특정 화면/기능을 격리해야 할 때만 래핑
<ErrorBoundary fallback={<Text>화면 로딩 중 오류가 발생했습니다.</Text>}>
  <SampleListPage />
</ErrorBoundary>
```

> **참고:** fallback을 생략하면 `DefaultErrorUI`가 기본 표시됩니다. 별도 fallback 작성은 선택 사항입니다.

---

## 10. @jwsl/core 주요 Hook

라우터/인증/권한 Hook은 `@jwsl/core`에서 직접 import합니다.

### 10.1 라우터

```typescript
import { useRouter, useParams, usePathname } from '@jwsl/core';

const { navigate, replace, back } = useRouter();
const { id } = useParams();          // URL 파라미터 (/sample/:id)
const pathname = usePathname();       // 현재 경로
```

### 10.2 인증/사용자

```typescript
import { useAuth, useUser } from '@jwsl/core';

// 인증 상태
const { isAuthenticated, login, logout } = useAuth();

// 사용자 정보
const { user, username, role, permissions, isAdmin } = useUser();
```

### 10.3 권한

```typescript
import { usePermission } from '@jwsl/core';

const { hasPermission, hasAnyPermission, can, cannot } = usePermission();

// 권한 기반 UI 분기
if (can('sample:write')) {
  // 등록/수정 버튼 표시
}
```

---

## 11. 버튼 표준 (buttonDiv)

`@jwsl/ui/mantine`의 `Button` 컴포넌트는 `buttonDiv` prop으로 사전 정의된 아이콘+라벨을 제공합니다:

```tsx
// 표준 버튼 타입
<Button buttonDiv="search" onClick={handleSearch} />   // 조회 (IconSearch + '조회')
<Button buttonDiv="create" onClick={handleCreate} />   // 저장 (IconPlus + '저장')
<Button buttonDiv="update" onClick={handleUpdate} />   // 수정 (IconEdit + '수정')
<Button buttonDiv="delete" onClick={handleDelete} />   // 삭제 (IconTrash + '삭제')
<Button buttonDiv="refresh" onClick={handleReset} />   // 새로고침 (IconRefresh + '새로고침')
<Button buttonDiv="save" onClick={handleSave} />       // 저장 (IconDeviceFloppy + '저장')
<Button buttonDiv="confirm" onClick={handleConfirm} /> // 확인 (IconCheck + '확인')
<Button buttonDiv="cancel" onClick={handleCancel} />   // 취소 (IconX + '취소')
<Button buttonDiv="download" onClick={handleExcel} />  // 다운로드 (IconDownload + '다운로드')
<Button buttonDiv="upload" component="label" />        // 업로드 (IconUpload + '업로드')
```

---

## 12. IDE 스니펫 지원

### 12.1 사용 가능한 스니펫

| 스니펫 | 단축키 | 설명 |
|--------|--------|------|
| CRUD 페이지 | `jwCrudPage` | 전체 CRUD 페이지 템플릿 |
| 조회 페이지 | `jwSearchPage` | 조회 전용 페이지 템플릿 |
| Master-Detail | `jwMasterDetail` | Master-Detail 레이아웃 |
| useAutoFetch | `jwUseAutoFetch` | 자동 조회 훅 |
| useNotification | `jwNotification` | 알림 훅 사용 |
| useCommonCode | `jwCommonCode` | 공통코드 훅 사용 |
| Button | `jwButton` | 표준 버튼 |
| 파일 헤더 | `jwHeader` | 파일 헤더 주석 |
| 함수 주석 | `jwFunc` | 함수 주석 |

### 12.2 스니펫 설치

1. IDE 스니펫 파일 위치: `demo/jwCreatePage.single.snippet`
2. VSCode/WebStorm에 스니펫 등록
3. 단축키 입력으로 템플릿 자동 생성

---

## 13. PR 체크리스트 (싱글소스)

### 코드 구조
- [ ] 영역별 주석 구분 (`/*** 1. jsDoc ***/`, `/*** 5. TYPE ***/` 등)
- [ ] 타입 정의 완료 (API 요청/응답, 엔티티)
- [ ] API 함수 정의 (`@jwsl/framework/api` 사용)

### Import 정책
- [ ] `useState`/`useEffect` 직접 사용 없음
- [ ] `react` 직접 import 없음
- [ ] `next/*` 직접 import 없음
- [ ] `@mantine/core` 직접 import 없음
- [ ] `axios`/`fetch` 직접 사용 없음

### Hook 정책
- [ ] `useAutoFetch` 또는 `useApiRequest` 사용
- [ ] `useFormState` 또는 `useFormValidation` 사용
- [ ] `useToggle`, `useListState` 적극 활용
- [ ] `useMount`, `useUpdateEffect` 사용 (useEffect 금지)

### 라우터/인증/UI
- [ ] `@jwsl/core`의 `useRouter` 사용
- [ ] `@jwsl/ui/mantine` UI 컴포넌트 사용
- [ ] `@jwsl/framework/icons` 또는 `@jwsl/icons` 아이콘 사용

### CRUD 기능
- [ ] 조회 (handleSearch) 구현
- [ ] 등록 (handleCreate) 구현
- [ ] 수정 (handleUpdate) 구현
- [ ] 삭제 (handleDelete) + 확인 모달
- [ ] 새로고침 (handleReset) 구현

### 에러/로딩
- [ ] 로딩 상태 표시 (`isLoading`)
- [ ] 에러 처리 (`onError` 콜백 또는 `error` 상태)
- [ ] ErrorBoundary 적용 (Feature 단위)

---

## 14. 분리 모델로 전환

싱글소스에서 분리 모델로 전환이 필요한 시점:

1. **파일이 500줄 이상**으로 커질 때
2. **동일 타입/API를 3개 이상 화면에서 공유**할 때
3. **팀원이 추가**되어 역할 분리가 필요할 때
4. **비즈니스 로직 테스트**가 필요할 때

전환 시:
1. TYPE 정의 → `types/` 폴더로 이동
2. API 정의 → `api/` 폴더로 이동
3. SERVICE 영역 → `services/` 폴더로 이동
4. HOOK 영역 → `hooks/` 폴더로 이동
5. 컴포넌트 → `ui/` 폴더로 이동

분리 모델 가이드: [jw-ui-framework_mfe_screen-guide.md](./jw-ui-framework_mfe_screen-guide.md)

---

## 부록 A. Import 경로 빠른 참조표

| 용도 | Import 경로 | 예시 |
|------|------------|------|
| 선언적 Hook | `@jwsl/framework/hooks` | `useFormState`, `useListState`, `useToggle`, `useMount`, `useAutoFetch`, `useApiRequest`, `useNotification`, `useCommonCode` |
| 폼 검증 | `@jwsl/framework/validation` | `useFormValidation`, `z`, `ValidationRules` |
| API 클라이언트 | `@jwsl/framework/api` | `api`, `httpClient`, `createRequestApi` |
| 공통 타입 | `@jwsl/framework/types` | `User`, `MenuItem`, `Permission`, `ApiRequestConfig` |
| 유틸리티 | `@jwsl/framework/utils` | `formatDate`, `formatCurrency`, `StorageManager` |
| CSS 유틸리티 | `@jwsl/framework/css` | `cx`, `cssVar`, `spacing`, `fontSize` |
| 아이콘 | `@jwsl/framework/icons` | `IconSearch`, `IconPlus`, `renderIcon` |
| UI 컴포넌트 | `@jwsl/ui/mantine` | `Button`, `Table`, `Modal`, `Paper`, `Stack` |
| 라우터 | `@jwsl/core` | `useRouter`, `useParams`, `usePathname` |
| 인증/권한 | `@jwsl/core` | `useAuth`, `useUser`, `usePermission`, `useMenu` |
| 에러 경계 | `@jwsl/core` | `ErrorBoundary`, `AuthGuard`, `PermissionGuard` |
| React 타입 | `@jwsl/react` (타입만) | `type ReactNode`, `type ComponentProps` |

> **원칙**: `@jwsl/framework/{subpath}` > `@jwsl/lib/{subpath}` > 기타 `@jwsl/*`
> framework re-export가 있으면 framework 경로를 우선 사용합니다.
