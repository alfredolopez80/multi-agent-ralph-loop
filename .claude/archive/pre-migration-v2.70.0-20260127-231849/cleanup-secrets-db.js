#!/usr/bin/env node
/**
 * Script para limpiar secretos de la base de datos de Claude-Mem
 *
 * Uso: node cleanup-secrets-db.js [--dry-run]
 *
 * --dry-run: Solo muestra que se limpiaria sin hacer cambios
 */

const { execFileSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const DB_PATH = path.join(os.homedir(), '.claude-mem', 'claude-mem.db');

const SECRET_PATTERNS = [
  { sql: "content LIKE '%ghp_%'", name: 'GitHub PAT' },
  { sql: "content LIKE '%github_pat_%'", name: 'GitHub Fine-grained PAT' },
  { sql: "content LIKE '%sk-proj-%'", name: 'OpenAI Project Key' },
  { sql: "content LIKE '%sk-ant-%'", name: 'Anthropic Key' },
  { sql: "content LIKE '%AKIA%'", name: 'AWS Access Key' },
  { sql: "content LIKE '%aws_secret%'", name: 'AWS Secret' },
  { sql: "content LIKE '%private_key%0x%'", name: 'ETH Private Key' },
  { sql: "content LIKE '%mnemonic%'", name: 'Seed Phrase' },
  { sql: "content LIKE '%api_key=%'", name: 'API Key' },
  { sql: "content LIKE '%password=%'", name: 'Password' },
  { sql: "content LIKE '%eyJ%'", name: 'JWT Token' },
  { sql: "content LIKE '%xoxb-%'", name: 'Slack Token' },
  { sql: "content LIKE '%sk_live_%'", name: 'Stripe Live Key' },
  { sql: "content LIKE '%sk_test_%'", name: 'Stripe Test Key' },
];

const isDryRun = process.argv.includes('--dry-run');

function runSql(query) {
  try {
    const result = spawnSync('sqlite3', [DB_PATH, query], { encoding: 'utf-8' });
    return result.stdout || '';
  } catch (error) {
    console.error('SQL Error:', error.message);
    return '';
  }
}

function countAffectedRows() {
  let total = 0;
  console.log('\n=== Escaneando base de datos por secretos ===\n');

  for (const pattern of SECRET_PATTERNS) {
    const count = runSql(`SELECT COUNT(*) FROM observations WHERE ${pattern.sql};`).trim();
    if (parseInt(count) > 0) {
      console.log(`  [!] ${pattern.name}: ${count} registros`);
      total += parseInt(count);
    }
  }

  return total;
}

function createBackup() {
  const backupPath = `${DB_PATH}.backup-${Date.now()}`;
  fs.copyFileSync(DB_PATH, backupPath);
  return backupPath;
}

async function main() {
  console.log('========================================');
  console.log('   Claude-Mem Secret Cleanup Tool      ');
  console.log('========================================');

  if (!fs.existsSync(DB_PATH)) {
    console.log('\n  [!] Base de datos no encontrada:', DB_PATH);
    return;
  }

  if (isDryRun) {
    console.log('\n  [MODO: DRY-RUN - No se haran cambios]\n');
  }

  const affected = countAffectedRows();

  if (affected === 0) {
    console.log('\n  [OK] No se encontraron secretos en la base de datos\n');
    return;
  }

  console.log(`\n  Total registros con posibles secretos: ${affected}`);

  if (!isDryRun) {
    const backupPath = createBackup();
    console.log(`\n  [OK] Backup creado: ${backupPath}`);
    console.log('\n  Para eliminar registros con secretos, usa SQL manualmente:');
    console.log(`  sqlite3 "${DB_PATH}" "DELETE FROM observations WHERE content LIKE '%ghp_%';"`);
  } else {
    console.log('\n  Para ver detalles, ejecuta sin --dry-run');
  }
}

main().catch(console.error);
