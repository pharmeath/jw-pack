#!/usr/bin/env node

/**
 * JW Framework 사용자 초기화 스크립트
 *
 * PostgreSQL의 인증(JPA) users / user_authorities 테이블에
 * 관리자(admin)와 일반사용자(user) 계정을 생성합니다.
 *
 * 사용법:
 *   pnpm init:users                                     # 기본 실행
 *   pnpm init:users:dry                                 # SQL만 출력
 *   node scripts/init-users.mjs --dry-run               # SQL만 출력
 *   node scripts/init-users.mjs --host=localhost --port=5432 --db=postgres
 *   node scripts/init-users.mjs --schema=public         (default)
 */

import { argv, exit } from 'node:process';
import bcrypt from 'bcryptjs';

// ===== CLI 인자 파싱 =====
const args = Object.fromEntries(
  argv.slice(2)
    .filter(a => a !== '--' && a.startsWith('--'))
    .map(a => {
      const [k, v] = a.slice(2).split('=');
      return [k, v ?? 'true'];
    })
);

const DRY_RUN = args['dry-run'] === 'true';
const DB_HOST = args.host ?? 'localhost';
const DB_PORT = parseInt(args.port ?? '5432', 10);
const DB_NAME = args.db ?? 'postgres';
const DB_USER = args.user ?? 'postgres';
const DB_PASS = args.password ?? 'postgres';
const DB_SCHEMA = args.schema ?? 'public';

function assertSafeSchemaName(schema) {
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(schema)) {
    console.error(`Error: invalid schema name: ${schema}`);
    exit(1);
  }
}

assertSafeSchemaName(DB_SCHEMA);

// ===== 사용자 데이터 정의 =====
const USERS = [
  {
    userId: 'admin',
    userName: 'admin',
    userRealName: '관리자',
    email: 'admin@jwsoftlab.com',
    phone: '010-0000-0001',
    password: 'admin1234!',
    enabled: true,
    accountNonExpired: true,
    accountNonLocked: true,
    credentialsNonExpired: true,
    authorities: ['ROLE_ADMIN', 'ROLE_USER'],
  },
  {
    userId: 'user',
    userName: 'user',
    userRealName: '일반사용자',
    email: 'user@jwsoftlab.com',
    phone: '010-0000-0002',
    password: 'user1234!',
    enabled: true,
    accountNonExpired: true,
    accountNonLocked: true,
    credentialsNonExpired: true,
    authorities: ['ROLE_USER'],
  },
];

// ===== BCrypt 해시 생성 =====
async function hashPasswords(users) {
  const SALT_ROUNDS = 10; // Spring Security BCryptPasswordEncoder 기본값
  const result = [];
  for (const user of users) {
    // Spring Security BCryptPasswordEncoder는 $2a$ 형식을 사용.
    // bcryptjs 3.x는 기본 $2b$를 생성하므로, 해시 후 접두사를 $2a$로 치환.
    const hashed = await bcrypt.hash(user.password, SALT_ROUNDS);
    const springCompatible = hashed.replace(/^\$2b\$/, '$2a$');
    result.push({ ...user, hashedPassword: springCompatible });
  }
  return result;
}

// ===== DB 작업 유틸리티 =====
function toTimestamp() {
  return new Date().toISOString().replace('T', ' ').replace(/\.\d+Z$/, '');
}

function buildAuthorities(user) {
  return user.authorities.join(',');
}

async function assertTablesExist(client) {
  const res = await client.query(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema=current_schema() AND table_name IN ('users', 'user_authorities')
    ORDER BY table_name;
  `);
  const existing = new Set(res.rows.map(r => r.table_name));
  const missing = ['users', 'user_authorities'].filter(t => !existing.has(t));
  if (missing.length) {
    throw new Error(
      `필수 테이블이 없습니다: ${missing.join(', ')}\n` +
      `인증(JPA) 모듈 스키마가 생성되었는지 확인하세요. (예: auth 모듈 기동/초기화)`
    );
  }
}

async function upsertUser(client, user) {
  const now = toTimestamp();
  await client.query(
    `INSERT INTO users (
        user_id,
        user_name,
        user_real_name,
        email,
        phone,
        password,
        authorities,
        enabled,
        account_non_expired,
        account_non_locked,
        credentials_non_expired,
        created_at,
        updated_at
      )
      VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
      )
      ON CONFLICT (user_id) DO UPDATE SET
        user_name = EXCLUDED.user_name,
        user_real_name = EXCLUDED.user_real_name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        password = EXCLUDED.password,
        authorities = EXCLUDED.authorities,
        enabled = EXCLUDED.enabled,
        account_non_expired = EXCLUDED.account_non_expired,
        account_non_locked = EXCLUDED.account_non_locked,
        credentials_non_expired = EXCLUDED.credentials_non_expired,
        updated_at = EXCLUDED.updated_at`,
    [
      user.userId,
      user.userName,
      user.userRealName,
      user.email,
      user.phone,
      user.hashedPassword,
      buildAuthorities(user),
      user.enabled,
      user.accountNonExpired,
      user.accountNonLocked,
      user.credentialsNonExpired,
      now,
      now,
    ]
  );

  // 권한 테이블(user_authorities)이 실제로 사용되는 환경을 위해 동기화
  // - users.authorities는 CSV로 보관
  // - user_authorities는 정규화 테이블
  await client.query('DELETE FROM user_authorities WHERE user_id = $1', [user.userId]);
  for (const authority of user.authorities) {
    await client.query(
      'INSERT INTO user_authorities (user_id, authority) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [user.userId, authority]
    );
  }
}

// ===== 실행 =====
async function main() {
  console.log('=== JW Framework 사용자 초기화 ===\n');

  console.log('1. BCrypt 비밀번호 해싱...');
  const usersWithHash = await hashPasswords(USERS);
  for (const u of usersWithHash) {
    console.log(`   ${u.userId}: ${u.password} → ${u.hashedPassword.substring(0, 20)}...`);
  }
  console.log('');

  if (DRY_RUN) {
    console.log('=== DRY RUN: 실행 단계만 출력 ===\n');
    console.log(`- schema: ${DB_SCHEMA}`);
    console.log('- users/user_authorities UPSERT + sync (admin, user)');
    console.log('\n=== DRY RUN 완료 (DB 변경 없음) ===');
    return;
  }

  console.log(`3. DB 연결: ${DB_HOST}:${DB_PORT}/${DB_NAME}`);

  let pg;
  try {
    pg = await import('pg');
  } catch {
    console.error('pg 모듈을 찾을 수 없습니다. pnpm -C framework add -D pg 를 실행하세요.');
    exit(1);
  }

  const client = new (pg.default?.Client ?? pg.Client)({
    host: DB_HOST,
    port: DB_PORT,
    database: DB_NAME,
    user: DB_USER,
    password: DB_PASS,
  });

  try {
    await client.connect();
    console.log('   연결 성공\n');

    if (DB_SCHEMA !== 'public') {
      await client.query(`CREATE SCHEMA IF NOT EXISTS ${DB_SCHEMA};`);
    }
    await client.query(`SET search_path TO ${DB_SCHEMA};`);
    console.log(`   스키마: ${DB_SCHEMA}\n`);

    await assertTablesExist(client);

    await client.query('BEGIN');
    try {
      console.log('4. SQL 실행...');
      for (const u of usersWithHash) {
        await upsertUser(client, u);
        console.log(`   OK: ${u.userId}`);
      }
      await client.query('COMMIT');
      console.log('\n   트랜잭션 커밋 완료');
    } catch (err) {
      try { await client.query('ROLLBACK'); } catch { /* ignore */ }
      throw err;
    }

    console.log('\n5. 검증...');
    const userResult = await client.query(
      `SELECT user_id, user_name, user_real_name, email, authorities, enabled
       FROM users
       WHERE user_id IN ('admin', 'user')
       ORDER BY user_id`
    );

    console.log('\n   [users 테이블]');
    console.log('   ' + '-'.repeat(95));
    console.log(`   ${'user_id'.padEnd(12)} ${'user_name'.padEnd(12)} ${'real_name'.padEnd(12)} ${'email'.padEnd(25)} ${'authorities'.padEnd(25)} enabled`);
    console.log('   ' + '-'.repeat(95));
    for (const row of userResult.rows) {
      console.log(`   ${row.user_id.padEnd(12)} ${(row.user_name || '').padEnd(12)} ${(row.user_real_name || '').padEnd(12)} ${row.email.padEnd(25)} ${(row.authorities || '').padEnd(25)} ${row.enabled}`);
    }

    console.log('\n=== 사용자 초기화 완료! ===');
    console.log('\n로그인 정보:');
    console.log('  관리자: admin / admin1234!  (ROLE_ADMIN, ROLE_USER)');
    console.log('  사용자: user  / user1234!   (ROLE_USER)');
  } catch (err) {
    console.error('DB 오류:', err.message);
    exit(1);
  } finally {
    await client.end();
  }
}

main().catch(err => {
  console.error('스크립트 오류:', err);
  exit(1);
});
