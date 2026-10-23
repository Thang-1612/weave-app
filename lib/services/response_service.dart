import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post.dart';

/// Một loại phản hồi gắn với chủ đề.
/// [keywords] rỗng = tùy chọn cốt lõi, lúc nào cũng phù hợp.
/// [keywords] có giá trị = chỉ hiện khi bài viết nhắc đến một trong các từ này
/// (viết không dấu, chữ thường).
class ResponseType {
  final String
  id; // ghi vào Firestore, đừng đổi sau khi đã có dữ liệu (tối đa 20 ký tự)
  final String emoji;
  final String vi;
  final String en;
  final List<String> keywords;
  const ResponseType(
    this.id,
    this.emoji,
    this.vi,
    this.en, [
    this.keywords = const [],
  ]);
}

const Map<String, List<ResponseType>> responsePools = {
  'cooking': [
    // Cốt lõi
    ResponseType('cooked', '🍳', 'Mình đã nấu thử', 'I cooked it'),
    ResponseType('tasty', '😋', 'Trông rất ngon', 'Looks delicious'),
    ResponseType('tweak', '🧂', 'Mình có mẹo chỉnh vị', 'I have a tweak'),
    // Theo ngữ cảnh
    ResponseType('saved', '📌', 'Lưu lại nấu sau', 'Saving for later', [
      'cong thuc',
      'cach lam',
      'nguyen lieu',
      'buoc',
    ]),
    ResponseType('easy', '👌', 'Dễ làm quá', 'So easy', [
      'de lam',
      'nhanh',
      'don gian',
      'phut',
    ]),
    ResponseType('family', '🍽️', 'Cả nhà ăn được', 'Good for the family', [
      'gia dinh',
      'ca nha',
      'bua com',
      'bua toi',
      'bua trua',
    ]),
    ResponseType('healthy', '🥗', 'Hợp ăn lành mạnh', 'Healthy choice', [
      'rau',
      'salad',
      'it dau',
      'healthy',
      'lanh manh',
      'giam can',
      'eat clean',
    ]),
    ResponseType('budget', '💸', 'Tiết kiệm chi phí', 'Budget friendly', [
      're',
      'tiet kiem',
      'gia',
      'tien',
      'cho ',
    ]),
    ResponseType(
      'swap',
      '🔄',
      'Mình đã thay nguyên liệu',
      'I swapped an ingredient',
      ['thay', 'nguyen lieu', 'thay the'],
    ),
    ResponseType(
      'photogenic',
      '📸',
      'Lên hình rất đẹp',
      'Looks great on camera',
      ['dep', 'bay', 'trang tri', 'mau sac', 'anh'],
    ),
  ],
  'study': [
    ResponseType('clear', '💡', 'Giải thích rất rõ', 'Very clear'),
    ResponseType(
      'confused',
      '🤔',
      'Mình vẫn chưa hiểu chỗ này',
      'Still confused',
    ),
    ResponseType('useful', '📌', 'Hữu ích để ôn tập', 'Useful for review'),
    ResponseType('example', '🧩', 'Cần thêm ví dụ', 'Needs more examples', [
      'vi du',
      'bai tap',
      'cong thuc',
      'dinh ly',
      'quy tac',
    ]),
    ResponseType('memo', '🧠', 'Dễ nhớ', 'Easy to remember', [
      'nho',
      'thuoc',
      'meo',
      'tu vung',
      'ghi chu',
    ]),
    ResponseType('deeper', '📚', 'Muốn học sâu hơn', 'Want to go deeper', [
      'nang cao',
      'chuyen sau',
      'tim hieu',
      'nghien cuu',
      'ly thuyet',
    ]),
    ResponseType('practiced', '✍️', 'Mình đã làm bài tập', 'I practiced it', [
      'bai tap',
      'luyen',
      'de thi',
      'thuc hanh',
    ]),
    ResponseType(
      'shared',
      '🤝',
      'Mình sẽ gửi cho bạn học',
      'Sharing with a friend',
      ['nhom', 'lop', 'thi', 'ban hoc'],
    ),
    ResponseType('fixme', '🔍', 'Có chỗ cần sửa', 'Something needs fixing', [
      'sai',
      'nham',
      'loi',
      'dinh chinh',
    ]),
    ResponseType('goal', '🎯', 'Đúng thứ mình cần', 'Exactly what I needed', [
      'thi',
      'muc tieu',
      'ke hoach',
      'on tap',
      'lo trinh',
    ]),
  ],
  'travel': [
    ResponseType('been', '📍', 'Mình đã đến đây', "I've been here"),
    ResponseType('want', '🧳', 'Muốn đi', 'Want to go'),
    ResponseType('tip', '🗺️', 'Mình có mẹo cho nơi này', 'I have a tip'),
    ResponseType('cheap', '💰', 'Hợp túi tiền', 'Budget friendly', [
      'gia',
      'tien',
      've ',
      'chi phi',
      're ',
      'tiet kiem',
      'combo',
    ]),
    ResponseType('crowded', '👥', 'Nơi này khá đông', 'It gets crowded', [
      'dong nguoi',
      'dong duc',
      'chen',
      'xep hang',
      'le ',
      'tet',
    ]),
    ResponseType('season', '🌤️', 'Nên đi mùa nào nhỉ?', 'Best season to go?', [
      'mua',
      'nang',
      'thoi tiet',
      'thang',
      'lanh',
      'nong',
    ]),
    ResponseType('foodie', '🍜', 'Ăn ngon ở đây', 'Great food here', [
      'an ',
      'mon ',
      'quan',
      'pho',
      'bun',
      'banh',
      'hai san',
      'dac san',
      'food',
    ]),
    ResponseType('photo', '📷', 'Chụp ảnh rất đẹp', 'Great for photos', [
      'anh',
      'chup',
      'view',
      'canh',
      'bien',
      'nui',
      'dep',
      'hoang hon',
      'binh minh',
    ]),
    ResponseType('kids', '🧒', 'Hợp đi cùng gia đình', 'Good for families', [
      'gia dinh',
      'tre em',
      'con nho',
      'be ',
      'cho tre',
    ]),
    ResponseType('hidden', '💎', 'Chỗ ít người biết', 'Hidden gem', [
      'it nguoi',
      'bi mat',
      'hoang so',
      'yen tinh',
      'vang ve',
    ]),
  ],
  'maker': [
    ResponseType('built', '🛠️', 'Mình đã làm thử', 'I built it'),
    ResponseType('improve', '🔧', 'Có cách cải tiến', 'I can improve it'),
    ResponseType('want', '🙋', 'Mình cũng cần cái này', 'I need this too'),
    ResponseType('tools', '🧰', 'Mình có đủ dụng cụ', 'I have the tools', [
      'dung cu',
      'may ',
      'khoan',
      'cua',
      'bua',
      'tool',
      'do nghe',
    ]),
    ResponseType('cost', '💸', 'Chi phí hợp lý', 'Reasonable cost', [
      'chi phi',
      'gia',
      'tien',
      're ',
      'tiet kiem',
    ]),
    ResponseType('safety', '⚠️', 'Cần lưu ý an toàn', 'Mind the safety', [
      'dien',
      'cua',
      'dao',
      'han ',
      'nguy hiem',
      'an toan',
      'lua',
      'sac',
    ]),
    ResponseType('hard', '😅', 'Hơi khó làm', 'Looks tricky', [
      'kho',
      'phuc tap',
      'ti mi',
      'tinh xao',
    ]),
    ResponseType('clever', '💡', 'Ý tưởng hay', 'Clever idea', [
      'y tuong',
      'sang tao',
      'moi ',
      'tu che',
      'che tao',
      'doc dao',
    ]),
    ResponseType(
      'materials',
      '📦',
      'Hỏi về vật liệu',
      'Question about materials',
      ['go ', 'nhua', 'sat', 'vat lieu', 'thep', 'keo', 'vai', 'nhom'],
    ),
    ResponseType(
      'weekend',
      '📅',
      'Sẽ làm cuối tuần này',
      'Doing it this weekend',
      ['cuoi tuan', 'du an', 'lam thu', 'huong dan'],
    ),
  ],
};

// ---- Bỏ dấu tiếng Việt để so khớp từ khóa ----
final Map<String, String> _plainMap = () {
  final m = <String, String>{};
  void add(String chars, String to) {
    for (final r in chars.runes) {
      m[String.fromCharCode(r)] = to;
    }
  }

  add('àáạảãâầấậẩẫăằắặẳẵ', 'a');
  add('èéẹẻẽêềếệểễ', 'e');
  add('ìíịỉĩ', 'i');
  add('òóọỏõôồốộổỗơờớợởỡ', 'o');
  add('ùúụủũưừứựửữ', 'u');
  add('ỳýỵỷỹ', 'y');
  add('đ', 'd');
  return m;
}();

String _plain(String s) {
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    buf.write(_plainMap[c] ?? c);
  }
  return buf.toString();
}

/// Chữ của bài (phần chữ + tiêu đề liên kết), không dấu, có đệm khoảng trắng
/// hai đầu để các từ khóa có dấu cách (như "an ") khớp được ở mép câu.
String _postText(Post p) {
  final parts = <String>[p.text];
  for (final b in p.blocks) {
    if (b['type'] == 'link') parts.add(b['title'] as String? ?? '');
  }
  return ' ${_plain(parts.join(' '))} ';
}

/// Băm chuỗi thành số ổn định giữa các thiết bị (kể cả web).
int _seed(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return h;
}

/// Các tùy chọn hiện trên một bài: chỉ lấy loại cốt lõi và loại có từ khóa
/// khớp nội dung, rồi chọn ngẫu nhiên nhưng cố định theo id bài.
/// Bài gốc hiện 3, bài rẽ nhánh hiện 2 cho gọn.
List<ResponseType>? responsesFor(Post p) {
  final pool = responsePools[p.spaceId];
  if (pool == null) return null;

  final text = _postText(p);
  final eligible = pool.where((r) {
    if (r.keywords.isEmpty) return true;
    return r.keywords.any((k) => text.contains(k));
  }).toList();

  final n = p.forkedFrom != null ? 2 : 3;
  eligible.shuffle(Random(_seed(p.id)));
  return eligible.take(n).toList();
}

class ResponseService {
  static CollectionReference<Map<String, dynamic>> _col(Post p) =>
      FirebaseFirestore.instance
          .collection(p.collection)
          .doc(p.id)
          .collection('responses');

  /// Phản hồi hiện tại của tôi (null nếu chưa có).
  static Stream<String?> watchMine(Post p) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _col(p)
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['type'] as String?);
  }

  /// Bấm cùng loại thì bỏ, bấm loại khác thì đổi.
  static Future<void> toggle(Post p, String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _col(p).doc(uid);
    final cur = (await ref.get()).data()?['type'];
    if (cur == type) {
      await ref.delete();
    } else {
      await ref.set({
        'type': type,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<Map<String, int>> counts(Post p, List<String> types) async {
    final out = <String, int>{};
    await Future.wait(
      types.map((t) async {
        final agg = await _col(p).where('type', isEqualTo: t).count().get();
        out[t] = agg.count ?? 0;
      }),
    );
    return out;
  }
}
