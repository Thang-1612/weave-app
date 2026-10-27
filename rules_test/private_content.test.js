const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp } = require('firebase/firestore');
const { createEnv, seed, as } = require('./helpers');

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

describe('friend_posts (bài chỉ người trong audience xem)', () => {
  beforeEach(async () => {
    await seed(env, { 'friend_posts/f1': { authorId: 'alice', audience: ['bob'], text: 'riêng', reactions: 0, comments: 0, reactionSummary: {} } });
  });
  test('tác giả và người trong audience đọc được', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'alice'), 'friend_posts/f1')));
    await assertSucceeds(getDoc(doc(as(env, 'bob'), 'friend_posts/f1')));
  });
  test('người ngoài audience không đọc được', async () => {
    await assertFails(getDoc(doc(as(env, 'carol'), 'friend_posts/f1')));
  });
  test('không giả mạo authorId khi tạo', async () => {
    await assertFails(setDoc(doc(as(env, 'carol'), 'friend_posts/x'),
      { authorId: 'alice', audience: ['carol'], reactions: 0, comments: 0, reactionSummary: {} }));
  });
  test('người trong audience chỉ đổi được bộ đếm ±1', async () => {
    await assertSucceeds(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { reactions: 1 }));
    await assertFails(updateDoc(doc(as(env, 'bob'), 'friend_posts/f1'), { text: 'sửa' }));
  });
  test('người ngoài audience không đổi được gì', async () => {
    await assertFails(updateDoc(doc(as(env, 'carol'), 'friend_posts/f1'), { reactions: 1 }));
  });
  test('tác giả không tự sửa bộ đếm, người khác không xóa', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'friend_posts/f1'), { reactions: 50 }));
    await assertFails(deleteDoc(doc(as(env, 'bob'), 'friend_posts/f1')));
  });
});

describe('capsules (hộp thời gian)', () => {
  const future = () => Timestamp.fromMillis(Date.now() + 7 * 86400e3);
  const past = () => Timestamp.fromMillis(Date.now() - 86400e3);
  test('người nhận KHÔNG đọc được trước ngày mở', async () => {
    await seed(env, { 'capsules/c1': { authorId: 'alice', audience: ['bob'], visibility: 'friends', openAt: future(), reactions: 0, comments: 0 } });
    await assertFails(getDoc(doc(as(env, 'bob'), 'capsules/c1')));
    await assertSucceeds(getDoc(doc(as(env, 'alice'), 'capsules/c1')));
  });
  test('người nhận đọc được sau ngày mở', async () => {
    await seed(env, { 'capsules/c2': { authorId: 'alice', audience: ['bob'], visibility: 'friends', openAt: past(), reactions: 0, comments: 0 } });
    await assertSucceeds(getDoc(doc(as(env, 'bob'), 'capsules/c2')));
    await assertFails(getDoc(doc(as(env, 'carol'), 'capsules/c2')));
  });
  test('tạo hộp với ngày mở ở quá khứ bị từ chối', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'capsules/c3'), {
      authorId: 'alice', audience: ['bob'], visibility: 'friends',
      openAt: past(), createdAt: serverTimestamp(), reactions: 0, comments: 0, reactionSummary: {},
    }));
  });
  test('tạo hộp hợp lệ', async () => {
    await assertSucceeds(setDoc(doc(as(env, 'alice'), 'capsules/c4'), {
      authorId: 'alice', audience: ['bob'], visibility: 'friends',
      openAt: future(), createdAt: serverTimestamp(), reactions: 0, comments: 0, reactionSummary: {},
    }));
  });
  test('không đổi audience sau khi tạo', async () => {
    await seed(env, { 'capsules/c5': { authorId: 'alice', audience: ['bob'], visibility: 'friends', openAt: future(), reactions: 0, comments: 0 } });
    await assertFails(updateDoc(doc(as(env, 'alice'), 'capsules/c5'), { audience: ['bob', 'carol'] }));
  });
});

describe('chats', () => {
  const direct = (extra = {}) => ({
    type: 'direct', name: '', members: ['alice', 'bob'], admins: [], createdBy: 'alice',
    acceptedBy: ['alice'], createdAt: serverTimestamp(), lastMessageAt: serverTimestamp(),
    disappearAfterSec: 0, ...extra,
  });
  test('tạo chat trực tiếp hợp lệ', async () => {
    await assertSucceeds(setDoc(doc(as(env, 'alice'), 'chats/alice_bob'), direct()));
  });
  test('id chat phải khớp cặp thành viên', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'chats/alice_carol'), direct()));
  });
  test('không tạo chat mà mình không phải thành viên', async () => {
    await assertFails(setDoc(doc(as(env, 'carol'), 'chats/alice_bob'), direct({ createdBy: 'carol' })));
  });
  test('không tự đánh dấu hộ người kia đã chấp nhận', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'chats/alice_bob'), direct({ acceptedBy: ['alice', 'bob'] })));
  });
  describe('chat đã tồn tại', () => {
    beforeEach(async () => {
      await seed(env, { 'chats/alice_bob': { type: 'direct', name: '', members: ['alice', 'bob'], admins: [], createdBy: 'alice', acceptedBy: ['alice', 'bob'], disappearAfterSec: 0 } });
    });
    test('thành viên đọc được, người ngoài thì không', async () => {
      await assertSucceeds(getDoc(doc(as(env, 'bob'), 'chats/alice_bob')));
      await assertFails(getDoc(doc(as(env, 'carol'), 'chats/alice_bob')));
    });
    test('người ngoài không sửa được', async () => {
      await assertFails(updateDoc(doc(as(env, 'carol'), 'chats/alice_bob'), { name: 'x' }));
    });
    test('không ai xóa được chat', async () => {
      await assertFails(deleteDoc(doc(as(env, 'alice'), 'chats/alice_bob')));
    });
    test('không thêm người vào chat trực tiếp', async () => {
      await assertFails(updateDoc(doc(as(env, 'alice'), 'chats/alice_bob'), { members: ['alice', 'bob', 'carol'] }));
    });
  });
});
