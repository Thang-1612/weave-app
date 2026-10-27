const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp } = require('firebase/firestore');
const { createEnv, seed, as, friends } = require('./helpers');

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

describe('groups', () => {
  beforeEach(async () => {
    await seed(env, {
      'groups/g1': { ownerId: 'alice', memberIds: ['alice'] },
      ...friends('alice', 'bob'),
    });
  });
  test('chỉ thành viên đọc được nhóm', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'alice'), 'groups/g1')));
    await assertFails(getDoc(doc(as(env, 'bob'), 'groups/g1')));
  });
  test('chủ nhóm thêm đúng một người là bạn bè', async () => {
    await assertSucceeds(updateDoc(doc(as(env, 'alice'), 'groups/g1'), { memberIds: ['alice', 'bob'] }));
  });
  test('không thêm người chưa là bạn bè', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'groups/g1'), { memberIds: ['alice', 'carol'] }));
  });
  test('không thêm nhiều người cùng lúc', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'groups/g1'), { memberIds: ['alice', 'bob', 'carol'] }));
  });
  test('không chiếm quyền chủ nhóm', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'groups/g1'), { ownerId: 'bob' }));
  });
  test('người khác không sửa hay xóa nhóm', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'groups/g1'), { memberIds: ['alice', 'bob'] }));
    await assertFails(deleteDoc(doc(as(env, 'bob'), 'groups/g1')));
  });
});

describe('weave_activities (Together)', () => {
  beforeEach(async () => {
    await seed(env, {
      'groups/g1': { ownerId: 'alice', memberIds: ['alice', 'bob', 'dave'] },
      'weave_activities/a1': { hostId: 'alice', groupId: 'g1', memberIds: ['alice', 'bob', 'dave'], status: 'active' },
      'weave_activities/a2': { hostId: 'alice', groupId: 'g1', memberIds: ['alice', 'bob'], status: 'ended' },
    });
  });
  test('thành viên đọc được, người ngoài thì không', async () => {
    await assertSucceeds(getDoc(doc(as(env, 'bob'), 'weave_activities/a1')));
    await assertFails(getDoc(doc(as(env, 'carol'), 'weave_activities/a1')));
  });
  test('tạo hoạt động: chỉ mời người thuộc nhóm', async () => {
    const db = as(env, 'alice');
    await assertSucceeds(setDoc(doc(db, 'weave_activities/n1'), { hostId: 'alice', groupId: 'g1', memberIds: ['alice', 'bob'], status: 'planning' }));
    await assertFails(setDoc(doc(db, 'weave_activities/n2'), { hostId: 'alice', groupId: 'g1', memberIds: ['alice', 'carol'], status: 'planning' }));
  });
  test('không tạo hoạt động mạo danh host', async () => {
    await assertFails(setDoc(doc(as(env, 'bob'), 'weave_activities/n3'), { hostId: 'alice', groupId: 'g1', memberIds: ['alice', 'bob'] }));
  });
  test('host không đổi hostId, không thêm người ngoài nhóm', async () => {
    const ref = doc(as(env, 'alice'), 'weave_activities/a1');
    await assertFails(updateDoc(ref, { hostId: 'bob' }));
    await assertFails(updateDoc(ref, { memberIds: ['alice', 'bob', 'dave', 'carol'] }));
  });
  test('hoạt động đã kết thúc không mở lại được', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'weave_activities/a2'), { status: 'active' }));
  });
  test('thành viên tự rời được, nhưng không đuổi người khác', async () => {
    await assertSucceeds(updateDoc(doc(as(env, 'bob'), 'weave_activities/a1'), { memberIds: ['alice', 'dave'] }));
  });
  test('thành viên không đuổi người khác', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'weave_activities/a1'), { memberIds: ['bob', 'dave'] }));
  });
  test('thành viên không xóa hoạt động', async () => {
    await assertFails(deleteDoc(doc(as(env, 'bob'), 'weave_activities/a1')));
  });

  describe('moments', () => {
    const m = (a, extra = {}) => ({ authorId: a, caption: 'khoảnh khắc', createdAt: serverTimestamp(), ...extra });
    test('thành viên đăng được khi hoạt động chưa kết thúc', async () => {
      await assertSucceeds(setDoc(doc(as(env, 'bob'), 'weave_activities/a1/moments/m1'), m('bob')));
    });
    test('người ngoài không đăng được', async () => {
      await assertFails(setDoc(doc(as(env, 'carol'), 'weave_activities/a1/moments/m1'), m('carol')));
    });
    test('không đăng thay người khác', async () => {
      await assertFails(setDoc(doc(as(env, 'bob'), 'weave_activities/a1/moments/m1'), m('alice')));
    });
    test('không đăng vào hoạt động đã kết thúc', async () => {
      await assertFails(setDoc(doc(as(env, 'bob'), 'weave_activities/a2/moments/m1'), m('bob')));
    });
    test('moment không sửa được; chỉ tác giả hoặc host xóa được', async () => {
      await seed(env, { 'weave_activities/a1/moments/m9': { authorId: 'bob', caption: 'x' } });
      await assertFails(updateDoc(doc(as(env, 'bob'), 'weave_activities/a1/moments/m9'), { caption: 'y' }));
      await assertFails(deleteDoc(doc(as(env, 'dave'), 'weave_activities/a1/moments/m9')));
      await assertSucceeds(deleteDoc(doc(as(env, 'alice'), 'weave_activities/a1/moments/m9')));
    });
  });
});

describe('stories (Storymaker)', () => {
  beforeEach(async () => {
    await seed(env, {
      'stories/s1': { ownerId: 'alice', collaboratorIds: ['alice', 'bob'], title: 'Chuyến đi', missing: [] },
      'stories/s1/blocks/ai': { type: 'narration', text: 'AI', sourceIds: ['s1'], aiGenerated: true, order: 0, createdBy: 'alice' },
      'stories/s1/blocks/bobs': { type: 'narration', text: 'của Bob', sourceIds: [], aiGenerated: false, lastEditedBy: 'bob', order: 1, createdBy: 'bob' },
      'stories/s1/sources/src1': { type: 'note', text: 'ghi chú', image: null },
    });
  });
  test('chỉ cộng tác viên đọc được truyện, khối và tư liệu', async () => {
    for (const p of ['stories/s1', 'stories/s1/blocks/ai', 'stories/s1/sources/src1']) {
      await assertSucceeds(getDoc(doc(as(env, 'bob'), p)));
      await assertFails(getDoc(doc(as(env, 'carol'), p)));
    }
  });
  test('cộng tác viên sửa khối thì khối không còn là "AI viết"', async () => {
    const ref = doc(as(env, 'bob'), 'stories/s1/blocks/ai');
    await assertFails(updateDoc(ref, { text: 'sửa', aiGenerated: true, lastEditedBy: 'bob' }));
    await assertSucceeds(updateDoc(ref, { text: 'sửa', aiGenerated: false, lastEditedBy: 'bob' }));
  });
  test('cộng tác viên chỉ xóa khối do mình tạo', async () => {
    const db = as(env, 'bob');
    await assertFails(deleteDoc(doc(db, 'stories/s1/blocks/ai')));
    await assertSucceeds(deleteDoc(doc(db, 'stories/s1/blocks/bobs')));
  });
  test('chủ truyện xóa được mọi khối', async () => {
    await assertSucceeds(deleteDoc(doc(as(env, 'alice'), 'stories/s1/blocks/bobs')));
  });
  test('tư liệu không sửa được; chỉ chủ xóa được', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'stories/s1/sources/src1'), { text: 'x' }));
    await assertFails(deleteDoc(doc(as(env, 'bob'), 'stories/s1/sources/src1')));
    await assertSucceeds(deleteDoc(doc(as(env, 'alice'), 'stories/s1/sources/src1')));
  });
  test('cộng tác viên không tự mời thêm người, không đổi chủ', async () => {
    await assertFails(updateDoc(doc(as(env, 'bob'), 'stories/s1'), { collaboratorIds: ['alice', 'bob', 'carol'] }));
    await assertFails(updateDoc(doc(as(env, 'bob'), 'stories/s1'), { ownerId: 'bob' }));
  });
  test('chủ truyện chỉ mời bạn bè', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'stories/s1'), { collaboratorIds: ['alice', 'bob', 'carol'], updatedAt: serverTimestamp() }));
    await seed(env, friends('alice', 'carol'));
    await assertSucceeds(updateDoc(doc(as(env, 'alice'), 'stories/s1'), { collaboratorIds: ['alice', 'bob', 'carol'], updatedAt: serverTimestamp() }));
  });
  test('chủ truyện không gỡ chính mình; cộng tác viên tự rời được', async () => {
    await assertFails(updateDoc(doc(as(env, 'alice'), 'stories/s1'), { collaboratorIds: ['bob'], updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(as(env, 'bob'), 'stories/s1'), { collaboratorIds: ['alice'] }));
  });
});
