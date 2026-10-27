const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection, writeBatch, serverTimestamp } = require('firebase/firestore');
const { createEnv, seed, as } = require('./helpers');

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });

const fs = (a, b, vis, status = 'accepted') => ({
  [`friendships/${[a, b].sort().join('_')}`]: { users: [a, b].sort(), requesterId: a, status, visibility: vis },
});
const edge = (friend) => ({ friendUid: friend, updatedAt: serverTimestamp() });

beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, {
    // alice–bob: cả hai công khai
    ...fs('alice', 'bob', { alice: 'public', bob: 'public' }),
    // alice–carol: carol ẩn
    ...fs('alice', 'carol', { alice: 'public', carol: 'hidden' }),
    // alice–erin: chưa có visibility (dữ liệu cũ) => coi như ẩn
    ...fs('alice', 'erin', {}),
  });
});

describe('public_edges: tạo cạnh', () => {
  test('chủ cạnh tạo được khi cả hai đã công khai', async () => {
    await assertSucceeds(setDoc(doc(as(env, 'alice'), 'users/alice/public_edges/bob'), edge('bob')));
  });
  test('người bạn trong cạnh ghi được chiều ngược lại', async () => {
    await assertSucceeds(setDoc(doc(as(env, 'bob'), 'users/alice/public_edges/bob'), edge('bob')));
  });
  test('không tạo cạnh khi bên kia ẩn', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'users/alice/public_edges/carol'), edge('carol')));
  });
  test('không tạo cạnh khi chưa có visibility (dữ liệu cũ)', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'users/alice/public_edges/erin'), edge('erin')));
  });
  test('không tạo cạnh với người chưa là bạn', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'users/alice/public_edges/dave'), edge('dave')));
  });
  test('không tạo cạnh khi lời mời còn pending', async () => {
    await seed(env, fs('alice', 'frank', { alice: 'public', frank: 'public' }, 'pending'));
    await assertFails(setDoc(doc(as(env, 'alice'), 'users/alice/public_edges/frank'), edge('frank')));
  });
  test('người thứ ba không tạo hộ cạnh của người khác', async () => {
    await assertFails(setDoc(doc(as(env, 'carol'), 'users/alice/public_edges/bob'), edge('bob')));
  });
  test('friendUid phải khớp id tài liệu, không có trường thừa', async () => {
    const ref = doc(as(env, 'alice'), 'users/alice/public_edges/bob');
    await assertFails(setDoc(ref, { friendUid: 'carol', updatedAt: serverTimestamp() }));
    await assertFails(setDoc(ref, { friendUid: 'bob', updatedAt: serverTimestamp(), extra: 1 }));
  });
});

describe('public_edges: đọc', () => {
  beforeEach(async () => {
    await seed(env, {
      'users/alice/public_edges/bob': { friendUid: 'bob' },
      'users/alice/public_edges/carol': { friendUid: 'carol' }, // cạnh cũ sót lại, carol đã ẩn
    });
  });
  test('người lạ dò được cạnh còn hiệu lực', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'dave'), 'users/alice/public_edges/bob')));
  });
  test('cạnh sót lại không đọc được khi một bên đã ẩn (kiểm tra lúc đọc)', async () => {
    await assertFails(getDoc(doc(as(env, 'dave'), 'users/alice/public_edges/carol')));
  });
  test('cạnh sót lại không đọc được sau khi hủy kết bạn', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'friendships/alice_bob'));
    });
    await assertFails(getDoc(doc(as(env, 'dave'), 'users/alice/public_edges/bob')));
  });
  test('liệt kê: chủ và bạn bè của chủ được, người lạ thì không', async () => {
    const path = 'users/alice/public_edges';
    await assertSucceeds(getDocs(collection(as(env, 'alice'), path)));
    await assertSucceeds(getDocs(collection(as(env, 'bob'), path)));
    await assertFails(getDocs(collection(as(env, 'dave'), path)));
  });
});

describe('public_edges: xóa', () => {
  beforeEach(async () => {
    await seed(env, { 'users/alice/public_edges/bob': { friendUid: 'bob' } });
  });
  test('chủ và người bạn trong cạnh xóa được', async () => {
    await assertSucceeds(deleteDoc(doc(as(env, 'alice'), 'users/alice/public_edges/bob')));
    await seed(env, { 'users/alice/public_edges/bob': { friendUid: 'bob' } });
    await assertSucceeds(deleteDoc(doc(as(env, 'bob'), 'users/alice/public_edges/bob')));
  });
  test('người khác không xóa được', async () => {
    await assertFails(deleteDoc(doc(as(env, 'dave'), 'users/alice/public_edges/bob')));
  });
});

describe('public_edges: các batch mà app thực hiện', () => {
  test('bên thứ hai bật công khai: đổi visibility + ghi cả hai cạnh cùng batch', async () => {
    await seed(env, fs('gina', 'hugo', { gina: 'public', hugo: 'hidden' }));
    const db = as(env, 'hugo');
    const batch = writeBatch(db);
    batch.update(doc(db, 'friendships/gina_hugo'), { 'visibility.hugo': 'public', updatedAt: serverTimestamp() });
    batch.set(doc(db, 'users/hugo/public_edges/gina'), edge('gina'));
    batch.set(doc(db, 'users/gina/public_edges/hugo'), edge('hugo'));
    await assertSucceeds(batch.commit());
  });
  test('bật công khai khi bên kia còn ẩn: batch ghi cạnh bị từ chối', async () => {
    const db = as(env, 'alice');
    const batch = writeBatch(db);
    batch.update(doc(db, 'friendships/alice_carol'), { 'visibility.alice': 'public', updatedAt: serverTimestamp() });
    batch.set(doc(db, 'users/alice/public_edges/carol'), edge('carol'));
    await assertFails(batch.commit());
  });
  test('ẩn quan hệ: đổi visibility + xóa cả hai cạnh cùng batch', async () => {
    await seed(env, {
      'users/alice/public_edges/bob': { friendUid: 'bob' },
      'users/bob/public_edges/alice': { friendUid: 'alice' },
    });
    const db = as(env, 'bob');
    const batch = writeBatch(db);
    batch.update(doc(db, 'friendships/alice_bob'), { 'visibility.bob': 'hidden', updatedAt: serverTimestamp() });
    batch.delete(doc(db, 'users/bob/public_edges/alice'));
    batch.delete(doc(db, 'users/alice/public_edges/bob'));
    await assertSucceeds(batch.commit());
  });
  test('hủy kết bạn: xóa friendship + cả hai cạnh cùng batch', async () => {
    await seed(env, {
      'users/alice/public_edges/bob': { friendUid: 'bob' },
      'users/bob/public_edges/alice': { friendUid: 'alice' },
    });
    const db = as(env, 'alice');
    const batch = writeBatch(db);
    batch.delete(doc(db, 'friendships/alice_bob'));
    batch.delete(doc(db, 'users/alice/public_edges/bob'));
    batch.delete(doc(db, 'users/bob/public_edges/alice'));
    await assertSucceeds(batch.commit());
  });
});

describe('bạn chung (cách MutualFriendsService truy vấn)', () => {
  // me = dave. dave là bạn của bob (cạnh bob–X công khai) và của carol (cạnh carol–X ẩn).
  // X = alice (dave không phải bạn của alice).
  beforeEach(async () => {
    await seed(env, {
      ...fs('dave', 'bob', {}), // dave–bob: dave không cần công khai
      ...fs('dave', 'carol', {}),
      'users/alice/public_edges/bob': { friendUid: 'bob' },
      'users/alice/public_edges/carol': { friendUid: 'carol' },
    });
  });
  test('bob hiện là bạn chung; carol (ẩn) thì không', async () => {
    const db = as(env, 'dave');
    await assertSucceeds(getDoc(doc(db, 'users/alice/public_edges/bob')));
    await assertFails(getDoc(doc(db, 'users/alice/public_edges/carol')));
  });
  test('người lạ không liệt kê được toàn bộ bạn công khai của alice', async () => {
    await assertFails(getDocs(collection(as(env, 'dave'), 'users/alice/public_edges')));
  });
});
