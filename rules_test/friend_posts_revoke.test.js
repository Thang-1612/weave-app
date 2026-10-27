const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, updateDoc, arrayRemove, arrayUnion } = require('firebase/firestore');
const { createEnv, seed, as } = require('./helpers');

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, {
    'friend_posts/f1': {
      authorId: 'alice', audience: ['bob', 'carol'], visibility: 'friends',
      text: 'riêng', reactions: 0, comments: 0, reactionSummary: {},
    },
  });
});

describe('friend_posts: thu hồi quyền xem khi hủy kết bạn', () => {
  test('người xem tự rút mình khỏi audience được, và mất quyền đọc ngay', async () => {
    await assertSucceeds(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { audience: arrayRemove('bob') }));
    await assertFails(getDoc(doc(as(env, 'bob'), 'friend_posts/f1')));
    await assertSucceeds(getDoc(doc(as(env, 'carol'), 'friend_posts/f1')));
  });
  test('tác giả gỡ một người khỏi audience được', async () => {
    await assertSucceeds(updateDoc(doc(as(env, 'alice'), 'friend_posts/f1'), { audience: arrayRemove('bob') }));
    await assertFails(getDoc(doc(as(env, 'bob'), 'friend_posts/f1')));
  });
  test('người xem không gỡ người khác', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { audience: arrayRemove('carol') }));
  });
  test('người xem không gỡ cả nhóm cùng lúc', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { audience: [] }));
  });
  test('người xem không thêm người vào audience', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { audience: arrayUnion('dave') }));
    await assertFails(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { audience: ['bob', 'carol', 'dave'] }));
  });
  test('người xem không kết hợp rút mình với đổi trường khác', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { audience: ['carol'], text: 'sửa' }));
    await assertFails(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { audience: ['carol'], reactions: 9 }));
  });
  test('người ngoài audience không sửa được', async () => {
    await assertFails(updateDoc(doc(as(env, 'dave'), 'friend_posts/f1'), { audience: arrayRemove('bob') }));
  });
});
