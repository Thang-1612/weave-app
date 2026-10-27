const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, setLogLevel } = require('firebase/firestore');

// Các test assertFails cố ý gây PERMISSION_DENIED; không cần SDK in cảnh báo cho từng lần.
setLogLevel('error');

const PROJECT_ID = 'demo-weave';
const RULES_PATH = path.resolve(__dirname, '..', 'firestore.rules');

async function createEnv() {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8'), host, port: Number(port) },
  });
}

/** Ghi dữ liệu mẫu bỏ qua rules. docs: { 'posts/p1': {...}, ... } */
async function seed(env, docs) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [p, data] of Object.entries(docs)) await setDoc(doc(db, p), data);
  });
}

const as = (env, uid) => env.authenticatedContext(uid).firestore();
const anon = (env) => env.unauthenticatedContext().firestore();

/** Hai người đã là bạn bè (id theo thứ tự chữ cái, khớp rules). */
const friends = (a, b) => ({
  [`friendships/${[a, b].sort().join('_')}`]: {
    users: [a, b].sort(), requesterId: a, status: 'accepted',
  },
});

module.exports = { createEnv, seed, as, anon, friends };
