const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection } = require('firebase/firestore');
const { createEnv, seed, as, anon, friends } = require('./helpers');

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, {
    'posts/p1': { authorId: 'alice', text: 'hi', reactions: 0, comments: 0, reactionSummary: {} },
    ...friends('alice', 'bob'),
  });
});

describe('posts', () => {
  test('người chưa đăng nhập không đọc được', async () => {
    await assertFails(getDoc(doc(anon(env), 'posts/p1')));
  });
  test('người đã đăng nhập đọc được bài công khai', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'carol'), 'posts/p1')));
  });
  test('không giả mạo authorId khi tạo', async () => {
    await assertFails(setDoc(doc(as(env, 'bob'), 'posts/x'), { authorId: 'alice', text: 'x' }));
  });
  test('không tạo bài với bộ đếm khác 0', async () => {
    await assertFails(setDoc(doc(as(env, 'bob'), 'posts/x'),
      { authorId: 'bob', text: 'x', reactions: 5, comments: 0, reactionSummary: {} }));
  });
  test('tạo bài hợp lệ', async () => {
    await assertSucceeds(setDoc(doc(as(env, 'bob'), 'posts/x'),
      { authorId: 'bob', text: 'x', reactions: 0, comments: 0, reactionSummary: {} }));
  });
  test('tác giả không đổi được authorId', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'posts/p1'), { authorId: 'bob' }));
  });
  test('tác giả sửa nội dung được, nhưng không tự sửa bộ đếm', async () => {
    const ref = doc(as(env, 'alice'), 'posts/p1');
    await assertSucceeds(updateDoc(ref, { text: 'new' }));
    await assertFails(updateDoc(ref, { reactions: 99 }));
  });
  test('người khác chỉ đổi bộ đếm ±1', async () => {
    const ref = doc(as(env, 'bob'), 'posts/p1');
    await assertSucceeds(updateDoc(ref, { reactions: 1 }));
  });
  test('người khác không tăng bộ đếm quá 1 lần mỗi lượt', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'posts/p1'), { reactions: 3 }));
  });
  test('người khác không sửa nội dung hoặc xóa bài', async () => {
    const ref = doc(as(env, 'bob'), 'posts/p1');
    await assertFails(updateDoc(ref, { text: 'hack' }));
    await assertFails(deleteDoc(ref));
  });
  test('tác giả xóa được bài của mình', async () => {
    await assertSucceeds(deleteDoc(doc(as(env, 'alice'), 'posts/p1')));
  });
});

describe('posts/{id}/layers (Layers)', () => {
  beforeEach(async () => {
    await seed(env, {
      'posts/p1/layers/lf': { authorId: 'alice', audienceType: 'friends', name: 'Bạn bè', blocks: [] },
      'posts/p1/layers/lc': { authorId: 'alice', audienceType: 'close', name: 'Thân', blocks: [] },
      'posts/p1/layers/lm': { authorId: 'alice', audienceType: 'me', name: 'Riêng', blocks: [] },
      'users/alice/closeFriends/bob': { at: 1 },
    });
  });
  test('bạn bè đọc được lớp "friends", người lạ thì không', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'bob'), 'posts/p1/layers/lf')));
    await assertFails(getDoc(doc(as(env, 'carol'), 'posts/p1/layers/lf')));
  });
  test('lớp "close" chỉ dành cho người trong closeFriends', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'bob'), 'posts/p1/layers/lc')));
    await assertFails(getDoc(doc(as(env, 'carol'), 'posts/p1/layers/lc')));
  });
  test('lớp "me" chỉ tác giả đọc được', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'alice'), 'posts/p1/layers/lm')));
    await assertFails(getDoc(doc(as(env, 'bob'), 'posts/p1/layers/lm')));
  });
  test('chỉ tác giả được liệt kê các lớp', async () => {
    await assertSucceeds(getDocs(collection(as(env, 'alice'), 'posts/p1/layers')));
    await assertFails(getDocs(collection(as(env, 'bob'), 'posts/p1/layers')));
  });
  test('người khác không tạo lớp trên bài của người khác', async () => {
    await assertFails(setDoc(doc(as(env, 'bob'), 'posts/p1/layers/new'),
      { authorId: 'bob', audienceType: 'public', name: 'x', blocks: [] }));
  });
});
