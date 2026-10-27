const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection, query, limit, serverTimestamp } = require('firebase/firestore');
const { createEnv, seed, as, anon } = require('./helpers');

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const req = (from, to, extra = {}) => ({
  users: [from, to].sort(), requesterId: from, status: 'pending', createdAt: serverTimestamp(), ...extra,
});
const fid = (a, b) => `friendships/${[a, b].sort().join('_')}`;

describe('friendships', () => {
  test('gửi lời mời hợp lệ', async () => {
    await assertSucceeds(setDoc(doc(as(env, 'alice'), fid('alice', 'bob')), req('alice', 'bob')));
  });
  test('không giả mạo người gửi', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), fid('alice', 'bob')), req('bob', 'alice')));
  });
  test('không tự tạo quan hệ đã "accepted"', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), fid('alice', 'bob')),
      req('alice', 'bob', { status: 'accepted' })));
  });
  test('id tài liệu phải khớp cặp uid đã sắp xếp', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'friendships/bob_alice'), req('alice', 'bob')));
  });
  test('tôn trọng allowFriendRequests = false', async () => {
    await seed(env, { 'users/bob': { allowFriendRequests: false } });
    await assertFails(setDoc(doc(as(env, 'alice'), fid('alice', 'bob')), req('alice', 'bob')));
  });
  describe('khi đã có lời mời alice → bob', () => {
    beforeEach(async () => { await seed(env, { [fid('alice', 'bob')]: { users: ['alice', 'bob'], requesterId: 'alice', status: 'pending' } }); });
    test('người gửi không tự chấp nhận', async () => {
      await assertFails(updateDoc(doc(as(env, 'alice'), fid('alice', 'bob')), { status: 'accepted', updatedAt: serverTimestamp() }));
    });
    test('người nhận chấp nhận được', async () => {
      await assertSucceeds(updateDoc(doc(as(env, 'bob'), fid('alice', 'bob')), { status: 'accepted', updatedAt: serverTimestamp() }));
    });
    test('người nhận không sửa thêm trường khác khi chấp nhận', async () => {
      await assertFails(updateDoc(doc(as(env, 'bob'), fid('alice', 'bob')), { status: 'accepted', requesterId: 'bob' }));
    });
    test('người thứ ba không đọc, không xóa được', async () => {
      await assertFails(getDoc(doc(as(env, 'carol'), fid('alice', 'bob'))));
      await assertFails(deleteDoc(doc(as(env, 'carol'), fid('alice', 'bob'))));
    });
    test('một trong hai người hủy được', async () => {
      await assertSucceeds(deleteDoc(doc(as(env, 'alice'), fid('alice', 'bob'))));
    });
  });
});

describe('users', () => {
  beforeEach(async () => { await seed(env, { 'users/alice': { displayName: 'Alice' } }); });
  test('phải đăng nhập mới đọc hồ sơ', async () => {
    await assertFails(getDoc(doc(anon(env), 'users/alice')));
    await assertSucceeds(getDoc(doc(as(env, 'bob'), 'users/alice')));
  });
  test('không sửa hồ sơ người khác', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'users/alice'), { displayName: 'x' }));
  });
  test('không tự nâng quyền (role, isAdmin, isPremium...)', async () => {
    const ref = doc(as(env, 'alice'), 'users/alice');
    await assertSucceeds(updateDoc(ref, { displayName: 'Alice 2' }));
    for (const k of ['role', 'isAdmin', 'isVerified', 'isPremium', 'banned']) {
      await assertFails(updateDoc(ref, { [k]: true }));
    }
  });
  test('không xóa được hồ sơ', async () => {
    await assertFails(deleteDoc(doc(as(env, 'alice'), 'users/alice')));
  });
  test('liệt kê người dùng bắt buộc có limit ≤ 30', async () => {
    const db = as(env, 'bob');
    await assertSucceeds(getDocs(query(collection(db, 'users'), limit(30))));
    await assertFails(getDocs(query(collection(db, 'users'), limit(31))));
    await assertFails(getDocs(collection(db, 'users')));
  });
  test('users/{uid}/private chỉ chủ đọc ghi', async () => {
    await seed(env, { 'users/alice/private/contact': { email: 'a@x.vn' } });
    await assertSucceeds(getDoc(doc(as(env, 'alice'), 'users/alice/private/contact')));
    await assertFails(getDoc(doc(as(env, 'bob'), 'users/alice/private/contact')));
  });
  test('closeFriends: chỉ chủ và người được thêm đọc được', async () => {
    await seed(env, { 'users/alice/closeFriends/bob': { at: 1 } });
    await assertSucceeds(getDoc(doc(as(env, 'bob'), 'users/alice/closeFriends/bob')));
    await assertFails(getDoc(doc(as(env, 'carol'), 'users/alice/closeFriends/bob')));
  });
  // Danh sách bạn dạng mảng (public/edges) đã bị thay bằng public_edges
  // (xem public_edges.test.js). Dữ liệu cũ chỉ chủ đọc/xóa được.
  test('public/edges kiểu cũ: người lạ không đọc, không ghi mới', async () => {
    await seed(env, { 'users/alice/public/edges': { friends: ['bob'] } });
    await assertFails(getDoc(doc(as(env, 'carol'), 'users/alice/public/edges')));
    await assertSucceeds(getDoc(doc(as(env, 'alice'), 'users/alice/public/edges')));
    await assertFails(setDoc(doc(as(env, 'alice'), 'users/alice/public/edges'),
      { friends: ['bob'], updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(as(env, 'alice'), 'users/alice/public/edges')));
  });
  // user_prefs.dart lưu mutedUsers, favoriteUsers, favoriteSpaces, restrictedSpaces
  // trong users/{uid}/private/settings (không phải trong hồ sơ công khai).
  test('cài đặt cá nhân (tắt tiếng, yêu thích) chỉ chủ đọc được', async () => {
    await seed(env, { 'users/alice/private/settings': { mutedUsers: ['carol'], favoriteUsers: ['bob'] } });
    await assertSucceeds(getDoc(doc(as(env, 'alice'), 'users/alice/private/settings')));
    await assertFails(getDoc(doc(as(env, 'dave'), 'users/alice/private/settings')));
  });
});

describe('reports', () => {
  test('gửi báo cáo được, nhưng không đọc lại được', async () => {
    const db = as(env, 'alice');
    await assertSucceeds(setDoc(doc(db, 'reports/r1'), { reporterId: 'alice', reason: 'spam' }));
    await assertFails(getDoc(doc(db, 'reports/r1')));
  });
  test('không báo cáo mạo danh người khác', async () => {
    await assertFails(setDoc(doc(as(env, 'alice'), 'reports/r2'), { reporterId: 'bob' }));
  });
});
