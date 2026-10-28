import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const rootDir = process.cwd();

// Remove git_commit_and_push.mjs
const f = path.join(rootDir, 'scripts', 'git_commit_and_push.mjs');
if (fs.existsSync(f)) {
  fs.unlinkSync(f);
  console.log('Removed scripts/git_commit_and_push.mjs');
}

function run(cmd) {
  try {
    const out = execSync(cmd, { cwd: rootDir, encoding: 'utf-8', env: { ...process.env, PAGER: 'cat', GIT_TERMINAL_PROMPT: '0' } });
    console.log(`[${cmd}]:\n${out}`);
    return out;
  } catch (e) {
    console.error(`[${cmd} ERROR]:\n${e.stdout || ''}\n${e.stderr || ''}`);
    return null;
  }
}

run('git add -A');
const status = run('git status --short');
if (status && status.trim().length > 0) {
  run('git commit -m "chore: remove temporary deployment setup scripts"');
  run('git push origin main');
}

console.log('Final remote verification:');
run('git log -n 3 --oneline');
