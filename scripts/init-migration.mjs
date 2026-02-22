#!/usr/bin/env node

/**
 * JW Framework DB Initialization Script
 *
 * 기능:
 * - JW API 스키마/초기데이터 생성
 * - jw-zulip(채팅) + consultation 스키마/초기데이터 생성
 * - menus 데이터는 init.json을 단일 소스로 동기화
 *
 * 사용법:
 *   pnpm init:sql
 *   pnpm init:sql:dry
 *   node scripts/init-migration.mjs --dry-run
 *   node scripts/init-migration.mjs --compare
 *   node scripts/init-migration.mjs --compare-only
 *   node scripts/init-migration.mjs --reset
 *   node scripts/init-migration.mjs --host=localhost --port=5432 --db=postgres --user=postgres --password=postgres
 *   node scripts/init-migration.mjs --schema=public  (default)
 *
 * 메뉴 데이터 소스: demo/public/data/framework/init.json
 */

import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { argv, exit } from 'node:process';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ===== CLI 인자 파싱 =====
const args = Object.fromEntries(
  argv.slice(2)
    .filter(a => a !== '--' && a.startsWith('--'))
    .map(a => { const [k, v] = a.slice(2).split('='); return [k, v ?? 'true']; })
);

const config = {
  host: args.host || 'localhost',
  port: parseInt(args.port || '5432', 10),
  database: args.db || args.database || 'postgres',
  user: args.user || 'postgres',
  password: args.password || 'postgres',
  schema: args.schema || 'public',
};

function assertSafeSchemaName(schema) {
  // prevent SQL injection in identifiers used in SET search_path
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(schema)) {
    console.error(`Error: invalid schema name: ${schema}`);
    exit(1);
  }
}

assertSafeSchemaName(config.schema);

const DRY_RUN = args['dry-run'] === 'true';
const COMPARE_ONLY = args['compare-only'] === 'true';
const COMPARE = args.compare === 'true' || COMPARE_ONLY;
const RESET = args.reset === 'true';

// ===== init.json 로드 =====
const INIT_JSON_PATH = resolve(__dirname, '../demo/public/data/framework/init.json');

let initData;
try {
  initData = JSON.parse(readFileSync(INIT_JSON_PATH, 'utf-8'));
  console.log(`[init.json] loaded: ${INIT_JSON_PATH}`);
} catch (err) {
  console.error(`Error: init.json을 읽을 수 없습니다: ${INIT_JSON_PATH}`);
  console.error(err.message);
  exit(1);
}

const menusData = initData.menusData;
if (!menusData) {
  console.error('Error: init.json에 menusData가 없습니다.');
  exit(1);
}

// ===== SQL 생성 유틸리티 =====

/** SQL 문자열 이스케이프 */
function esc(val) {
  if (val === null || val === undefined) return 'NULL';
  if (typeof val === 'boolean') return val ? 'true' : 'false';
  if (typeof val === 'number') return String(val);
  return `'${String(val).replace(/'/g, "''")}'`;
}

/** 메뉴 데이터 단일 INSERT VALUES 행 생성 */
function menuRow(id, parentId, label, icon, path, orderSeq, isParent, showInDrawer, menuType, isPublic, badge, action) {
  return `(${esc(id)}, ${esc(parentId)}, ${esc(label)}, ${esc(icon)}, ${esc(path)}, ${orderSeq}, ${isParent}, ${showInDrawer}, ${esc(menuType)}, ${isPublic}, ${esc(badge)}, ${esc(action)})`;
}

const INSERT_COLS_MENU = '(id, parent_id, label, icon, path, order_seq, is_parent, show_in_drawer, menu_type, is_public, badge, action)';

// ===== init.json → SQL 변환 =====

const rows = [];

/**
 * 사이드바 메뉴 재귀 처리 (menus.customer)
 * init.json 구조: { id, label, icon, path, public, isParent, showInDrawer, children[] }
 */
function flattenSidebar(items, parentId, depth = 0) {
  if (!items) return;
  items.forEach((item, idx) => {
    const hasChildren = Array.isArray(item.children) && item.children.length > 0;
    rows.push(menuRow(
      item.id,
      parentId,
      item.label,
      item.icon || null,
      item.path || null,
      idx + 1,
      hasChildren || item.isParent === true,
      item.showInDrawer !== false,
      null,  // sidebar
      item.public !== false,
      item.badge || null,
      item.action || null,
    ));
    if (hasChildren) {
      flattenSidebar(item.children, item.id, depth + 1);
    }
  });
}

// 1) 사이드바 메뉴 (menus → role별, 기본 "customer")
if (menusData.menus) {
  for (const [role, items] of Object.entries(menusData.menus)) {
    // 현재는 customer만 처리 (다중 role은 향후 확장)
    flattenSidebar(items, null);
  }
}

// 2) 상단 메뉴 (topMenus) — ID 충돌 방지: "top-" 접두어
if (Array.isArray(menusData.topMenus)) {
  menusData.topMenus.forEach((item, idx) => {
    rows.push(menuRow(
      `top-${item.id}`,
      null,
      item.label,
      item.icon || null,
      item.path || null,
      idx + 1,
      false,
      false,
      'top',
      item.public !== false,
      item.badge || null,
      item.action || null,
    ));
  });
}

// 3) 하단 메뉴 (bottomMenus) — "bottom-" 접두어
if (Array.isArray(menusData.bottomMenus)) {
  menusData.bottomMenus.forEach((item, idx) => {
    rows.push(menuRow(
      `bottom-${item.id}`,
      null,
      item.label,
      item.icon || null,
      item.path || null,
      idx + 1,
      false,
      false,
      'bottom',
      item.public !== false,
      item.badge || null,
      item.action || null,
    ));
  });
}

// 4) 헤더 메뉴 (headerMenus) — "header-" 접두어
if (Array.isArray(menusData.headerMenus)) {
  menusData.headerMenus.forEach((item, idx) => {
    rows.push(menuRow(
      `header-${item.id}`,
      null,
      item.label,
      item.icon || null,
      item.path || null,
      idx + 1,
      false,
      false,
      'header',
      item.public !== false,
      typeof item.badge === 'number' ? String(item.badge) : (item.badge || null),
      item.action || null,
    ));
  });
}

console.log(`[init.json] 메뉴 ${rows.length}건 파싱 완료`);

// ===== SQL 조립 =====

const SQL_ALTER_MENUS = `
-- 컬럼 추가 (이미 존재하면 무시)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='menus' AND column_name='menu_type')
  THEN ALTER TABLE menus ADD COLUMN menu_type VARCHAR(20) DEFAULT NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='menus' AND column_name='is_public')
  THEN ALTER TABLE menus ADD COLUMN is_public BOOLEAN DEFAULT true; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='menus' AND column_name='badge')
  THEN ALTER TABLE menus ADD COLUMN badge VARCHAR(20); END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='menus' AND column_name='action')
  THEN ALTER TABLE menus ADD COLUMN action VARCHAR(20) DEFAULT NULL; END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_menus_menu_type ON menus(menu_type);
`;

const SQL_DELETE = `
DELETE FROM menus WHERE parent_id IS NOT NULL;
DELETE FROM menus WHERE parent_id IS NULL;
`;

// 부모(parent_id IS NULL)가 먼저, 자식이 나중에 들어가도록 정렬
const parentRows = rows.filter(r => r.includes(', NULL,'));  // parent_id = NULL
const childRows = rows.filter(r => !r.includes(', NULL,'));

const SQL_INSERT_PARENTS = parentRows.length > 0
  ? `INSERT INTO menus ${INSERT_COLS_MENU} VALUES\n${parentRows.join(',\n')}\nON CONFLICT (id) DO NOTHING;`
  : '-- (부모 메뉴 없음)';

const SQL_INSERT_CHILDREN = childRows.length > 0
  ? `INSERT INTO menus ${INSERT_COLS_MENU} VALUES\n${childRows.join(',\n')}\nON CONFLICT (id) DO NOTHING;`
  : '-- (자식 메뉴 없음)';

const SQL_VERIFY = `SELECT menu_type, COUNT(*) as cnt FROM menus GROUP BY menu_type ORDER BY menu_type NULLS FIRST;`;

function readSqlFile(absPath) {
  try {
    return readFileSync(absPath, 'utf-8');
  } catch (err) {
    console.error(`Error: SQL 파일을 읽을 수 없습니다: ${absPath}`);
    console.error(err.message);
    exit(1);
  }
}

const SQL_PATHS = {
  jwApiSchema: resolve(__dirname, '../../server/jw-api/init-scripts/sql/01_init_create_tables.sql'),
  jwApiSeed: resolve(__dirname, '../../server/jw-api/init-scripts/sql/01_init_insert_data.sql'),
  zulipSchema: resolve(__dirname, '../../server/jw-zulip/config/zulip_schema.sql'),
  zulipLinkPreviews: resolve(__dirname, '../../server/jw-zulip/config/zulip_link_previews.sql'),
  consultationMessageEnrichment: resolve(__dirname, '../../server/jw-zulip/config/consultation_message_enrichment.sql'),
  consultationSchema: resolve(__dirname, '../../server/jw-zulip/config/consultation_schema.sql'),
};

const SQL_RESET = `
-- Drop managed tables (DANGER)
DROP TABLE IF EXISTS
  order_items,
  orders,
  cart_items,
  products,
  common_codes,
  role_permissions,
  permissions,
  roles,
  menus,
  jw_users,
  consultation_product_card_shares,
  consultation_care_schedules,
  consultation_coupons,
  consultation_message_templates,
  consultation_customer_info,
  consultation_reviews,
  consultation_product_cards,
  consultation_sessions,
  zulip_attachments,
  zulip_message_recipients,
  zulip_reactions,
  zulip_messages,
  zulip_topics,
  zulip_subscriptions,
  zulip_streams,
  zulip_user_status,
  zulip_users
CASCADE;
`;

const EXPECTED_TABLES = [
  // JW API
  'roles',
  'permissions',
  'role_permissions',
  'jw_users',
  'menus',
  'common_codes',
  'products',
  'cart_items',
  'orders',
  'order_items',
  // Zulip
  'zulip_users',
  'zulip_streams',
  'zulip_subscriptions',
  'zulip_topics',
  'zulip_messages',
  'zulip_reactions',
  'zulip_message_recipients',
  'zulip_attachments',
  'zulip_user_status',
  // Consultation
  'consultation_sessions',
  'consultation_reviews',
  'consultation_customer_info',
  'consultation_product_cards',
  'consultation_product_card_shares',
  'consultation_message_templates',
  'consultation_coupons',
  'consultation_care_schedules',
];

function formatTableDiff({ existing }) {
  const expectedSet = new Set(EXPECTED_TABLES);
  const existingSet = new Set(existing);

  const missing = EXPECTED_TABLES.filter(t => !existingSet.has(t));
  // 'zulip_' tables are owned by this initializer.
  // 'consultation_' tables may exist outside the managed contract (different schema variants),
  // so we intentionally avoid treating all 'consultation_' tables as managed extras.
  const extraManaged = existing
    .filter(t => t.startsWith('zulip_'))
    .filter(t => !expectedSet.has(t));

  return { missing, extraManaged };
}

const steps = [
  RESET ? { name: '0. RESET (DROP TABLES)', sql: SQL_RESET } : null,
  { name: '1. JW API SCHEMA', sqlPath: SQL_PATHS.jwApiSchema },
  { name: '2. JW API SEED', sqlPath: SQL_PATHS.jwApiSeed },
  { name: '3. ZULIP SCHEMA', sqlPath: SQL_PATHS.zulipSchema },
  { name: '3-1. ZULIP LINK PREVIEWS', sqlPath: SQL_PATHS.zulipLinkPreviews },
  { name: '3-2. ZULIP CONSULTATION ENRICHMENT', sqlPath: SQL_PATHS.consultationMessageEnrichment },
  { name: '4. CONSULTATION SCHEMA', sqlPath: SQL_PATHS.consultationSchema },
  { name: '5. MENUS ALTER', sql: SQL_ALTER_MENUS },
  { name: '6. MENUS DELETE', sql: SQL_DELETE },
  { name: '7. MENUS INSERT (PARENTS)', sql: SQL_INSERT_PARENTS },
  { name: '8. MENUS INSERT (CHILDREN)', sql: SQL_INSERT_CHILDREN },
  { name: '9. MENUS VERIFY', sql: SQL_VERIFY, isQuery: true },
].filter(Boolean);

function getStepSql(step) {
  if (typeof step.sql === 'string') return step.sql;
  if (typeof step.sqlPath === 'string') return readSqlFile(step.sqlPath);
  throw new Error(`Invalid step: ${step.name}`);
}

// ===== DRY RUN =====
if (DRY_RUN) {
  console.log('\n-- ============================');
  console.log('-- DRY RUN (SQL 출력만)');
  console.log(`-- Source: ${INIT_JSON_PATH}`);
  console.log(`-- Target: ${config.host}:${config.port}/${config.database}`);
  console.log(`-- Schema: ${config.schema}`);
  console.log(`-- Total rows: ${rows.length}`);
  console.log(`-- Compare: ${COMPARE}`);
  console.log(`-- Compare-only: ${COMPARE_ONLY}`);
  console.log(`-- Reset: ${RESET}`);
  if (COMPARE || COMPARE_ONLY) {
    console.log('-- NOTE: --dry-run 모드에서는 DB에 접속하지 않으므로 compare 결과는 출력되지 않습니다.');
  }
  console.log('-- ============================\n');
  for (const s of steps) {
    console.log(`-- ${s.name}`);
    console.log(getStepSql(s));
    console.log('');
  }
  exit(0);
}

async function fetchExistingTables(client) {
  const res = await client.query(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema=current_schema() AND table_type='BASE TABLE'
    ORDER BY table_name;
  `);
  return res.rows.map(r => r.table_name);
}

async function verifyMenusColumns(client) {
  const res = await client.query(`
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema=current_schema() AND table_name='menus'
    ORDER BY ordinal_position;
  `);
  const cols = new Set(res.rows.map(r => r.column_name));
  const required = ['menu_type', 'is_public', 'badge', 'action'];
  return required.filter(c => !cols.has(c));
}

async function getTableColumns(client, tableName) {
  const res = await client.query(`
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema=current_schema() AND table_name=$1
    ORDER BY ordinal_position;
  `, [tableName]);
  return res.rows.map(r => r.column_name);
}

async function assertCompatibleExistingTables(client) {
  // If a table exists but is not our expected shape, schema SQL can fail (indexes/comments).
  // In that case, require --reset (drop managed tables) or a dedicated database.
  const checks = [
    { table: 'jw_users', required: ['id', 'username', 'password', 'email', 'role_id'] },
    { table: 'menus', required: ['id', 'label', 'order_seq', 'show_in_drawer'] },
  ];

  for (const { table, required } of checks) {
    const cols = await getTableColumns(client, table);
    if (cols.length === 0) continue; // table does not exist
    const colSet = new Set(cols);
    const missing = required.filter(c => !colSet.has(c));
    if (missing.length) {
      throw new Error(
        `[PRECHECK] Existing table "${table}" is incompatible with JW schema.\n` +
        `Missing columns: ${missing.join(', ')}\n` +
        `Action: run with --reset to drop managed tables, or use a dedicated database/schema.`
      );
    }
  }
}

// ===== DB 실행 =====
let pg;
try {
  pg = await import('pg');
} catch {
  console.error('Error: pg 모듈이 없습니다. pnpm -w add -D pg 또는 --dry-run 사용');
  exit(1);
}

const { Client } = pg.default || pg;
const client = new Client(config);

async function main() {
  console.log(`\nConnecting to ${config.host}:${config.port}/${config.database}`);
  await client.connect();
  console.log('Connected.\n');

  if (config.schema !== 'public') {
    await client.query(`CREATE SCHEMA IF NOT EXISTS ${config.schema};`);
  }
  await client.query(`SET search_path TO ${config.schema};`);
  console.log(`Using schema: ${config.schema}\n`);

  if (COMPARE_ONLY) {
    const existing = await fetchExistingTables(client);
    const { missing, extraManaged } = formatTableDiff({ existing });
    console.log('[COMPARE-ONLY] Current DB');
    console.log(`  Existing tables: ${existing.length}`);
    console.log(`  Missing managed tables: ${missing.length}`);
    if (missing.length) console.log('   - ' + missing.join('\n   - '));
    if (extraManaged.length) {
      console.log(`  Extra managed tables: ${extraManaged.length}`);
      console.log('   - ' + extraManaged.join('\n   - '));
    }
    return;
  }

  if (COMPARE) {
    const existingBefore = await fetchExistingTables(client);
    const { missing, extraManaged } = formatTableDiff({ existing: existingBefore });
    console.log('[COMPARE] Before');
    console.log(`  Existing tables: ${existingBefore.length}`);
    console.log(`  Missing managed tables: ${missing.length}`);
    if (missing.length) console.log('   - ' + missing.join('\n   - '));
    if (extraManaged.length) {
      console.log(`  Extra managed tables: ${extraManaged.length}`);
      console.log('   - ' + extraManaged.join('\n   - '));
    }
    console.log('');
  }

  if (!RESET) {
    await assertCompatibleExistingTables(client);
  }

  await client.query('BEGIN');
  try {
    for (const step of steps) {
      console.log(`${step.name}...`);
      const result = await client.query(getStepSql(step));
      if (step.isQuery && result.rows) {
        console.log('');
        console.log('  menu_type  | count');
        console.log('  -----------+------');
        for (const r of result.rows) {
          console.log(`  ${(r.menu_type ?? 'sidebar').padEnd(10)} | ${r.cnt}`);
        }
        console.log('');
      } else {
        console.log('  OK');
      }
    }

    const missingMenusCols = await verifyMenusColumns(client);
    if (missingMenusCols.length) {
      throw new Error(`menus 테이블에 필요한 컬럼이 없습니다: ${missingMenusCols.join(', ')}`);
    }

    await client.query('COMMIT');
    console.log('Migration completed successfully!');
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch { /* ignore */ }
    throw err;
  }

  if (COMPARE) {
    const existingAfter = await fetchExistingTables(client);
    const { missing, extraManaged } = formatTableDiff({ existing: existingAfter });
    console.log('\n[COMPARE] After');
    console.log(`  Existing tables: ${existingAfter.length}`);
    console.log(`  Missing managed tables: ${missing.length}`);
    if (missing.length) console.log('   - ' + missing.join('\n   - '));
    if (extraManaged.length) {
      console.log(`  Extra managed tables: ${extraManaged.length}`);
      console.log('   - ' + extraManaged.join('\n   - '));
    }
  }
}

try {
  await main();
} catch (err) {
  console.error('\nMigration failed:', err.message);
  exit(1);
} finally {
  await client.end();
}