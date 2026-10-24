import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-weave',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});
after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'groups/g1'), {
      ownerId: 'host', memberIds: ['host', 'a', 'b', 'c'],
    });
    await setDoc(doc(db, 'weave_activities/act1'), {
      hostId: 'host', groupId: 'g1', status: 'planning',
      memberIds: ['host', 'a', 'b'],
    });
    await setDoc(doc(db, 'stories/s1'), {
      ownerId: 'owner', collaboratorIds: ['owner', 'c1'], missing: [],
      title: 'T',
    });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

test('thành viên rời đúng mình: được', async () => {
  await assertSucceeds(
    updateDoc(doc(as('a'), 'weave_activities/act1'), { memberIds: ['host', 'b'] }));
});
test('rời kèm chèn người lạ: bị từ chối', async () => {
  await assertFails(
    updateDoc(doc(as('a'), 'weave_activities/act1'), { memberIds: ['host', 'x'] }));
});
test('rời kèm bỏ thêm người khác: bị từ chối', async () => {
  await assertFails(
    updateDoc(doc(as('a'), 'weave_activities/act1'), { memberIds: ['host'] }));
});
test('người ngoài tự thêm mình: bị từ chối', async () => {
  await assertFails(
    updateDoc(doc(as('x'), 'weave_activities/act1'),
      { memberIds: ['host', 'a', 'b', 'x'] }));
});
test('host thêm người thuộc nhóm: được', async () => {
  await assertSucceeds(
    updateDoc(doc(as('host'), 'weave_activities/act1'),
      { memberIds: ['host', 'a', 'b', 'c'] }));
});
test('host thêm người ngoài nhóm: bị từ chối', async () => {
  await assertFails(
    updateDoc(doc(as('host'), 'weave_activities/act1'),
      { memberIds: ['host', 'a', 'b', 'x'] }));
});
test('cộng tác viên tự rời truyện: được', async () => {
  await assertSucceeds(
    updateDoc(doc(as('c1'), 'stories/s1'), { collaboratorIds: ['owner'] }));
});
test('cộng tác viên rời kèm chèn người lạ: bị từ chối', async () => {
  await assertFails(
    updateDoc(doc(as('c1'), 'stories/s1'), { collaboratorIds: ['x'] }));
});