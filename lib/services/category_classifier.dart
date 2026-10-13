import 'text_utils.dart';

class CategoryGuess {
  final String? spaceId;
  final bool confident;
  final Map<String, double> scores;

  const CategoryGuess(this.spaceId, this.confident, this.scores);
}

// Từ khóa đã bỏ dấu, viết thường. Cụm từ nhiều chữ được tính điểm cao hơn.
const _keywords = <String, List<String>>{
  'study': [
    'hoc', 'hoc tap', 'on thi', 'bai tap', 'bai giang', 'bai kiem tra',
    'ky thi', 'thi cu', 'diem thi', 'bai thi', 'giao vien', 'thay co',
    'truong hoc', 'sinh vien', 'hoc sinh', 'dai hoc', 'hoc bong', 'tu vung',
    'ngu phap', 'tieng anh', 'ielts', 'toeic', 'luan van', 'de cuong',
    'sach giao khoa', 'khoa hoc', 'pomodoro', 'mon toan', 'vat ly',
    'hoa hoc', 'lich su', 'study', 'exam', 'homework', 'lecture', 'thesis',
    'course', 'tutorial', 'vocabulary', 'grammar', 'university', 'school',
    'learn', 'learning', 'quiz', 'flashcard',
  ],
  'cooking': [
    'nau an', 'mon an', 'cong thuc', 'nguyen lieu', 'gia vi', 'nuoc dung',
    'bua sang', 'bua trua', 'bua toi', 'an vat', 'quan an', 'nha hang',
    'tra sua', 'lo nuong', 'nuong', 'xao', 'bun bo', 'bun cha', 'pho bo',
    'pho ga', 'banh mi', 'banh', 'com tam', 'thit', 'goi cuon', 'nem ran',
    'bep', 'nau', 'ngon', 'food', 'recipe', 'cook', 'cooking', 'bake',
    'baking', 'kitchen', 'delicious', 'breakfast', 'lunch', 'dinner',
    'dessert', 'cake', 'soup', 'noodle', 'restaurant', 'coffee',
  ],
  'travel': [
    'du lich', 'di choi', 'chuyen di', 'kham pha', 'di phuot', 'phuot',
    'check in', 'khach san', 'homestay', 'resort', 've may bay', 'may bay',
    'san bay', 'ho chieu', 'visa', 'tour', 'bai bien', 'di bien', 'leo nui',
    'thac nuoc', 'da lat', 'sa pa', 'sapa', 'phu quoc', 'da nang', 'hoi an',
    'ha noi', 'sai gon', 'nha trang', 'vung tau', 'ha long', 'cao nguyen',
    'cam trai', 'trekking', 'camping', 'hanh trinh', 'travel', 'trip',
    'vacation', 'holiday', 'beach', 'mountain', 'hotel', 'flight', 'airport',
    'tourist', 'sightseeing', 'itinerary', 'passport', 'road trip',
  ],
  'maker': [
    'che tao', 'tu lam', 'tu che', 'diy', 'handmade', 'thu cong', 'lap rap',
    'mach dien', 'arduino', 'raspberry', 'esp32', 'cam bien', 'dong co',
    'robot', 'in 3d', 'may in 3d', 'cnc', 'han thiec', 'linh kien',
    'dien tu', 'pcb', 'laser', 'dung cu', 'mo hinh', 'sua chua', 'gia do',
    'do go', 'workshop', 'maker', 'soldering', 'prototype', 'drone',
    'hardware', 'motor', 'sensor', 'circuit', '3d print', 'woodworking',
    'build',
  ],
};

// Địa chỉ trang web đặc trưng của từng chủ đề (cộng điểm cho liên kết).
const _domains = <String, List<String>>{
  'travel': ['tripadvisor', 'booking.com', 'agoda', 'traveloka', 'airbnb', 'klook'],
  'cooking': ['cookpad', 'tasty.co', 'allrecipes', 'monngonmoingay', 'cooky.vn', 'foodnetwork'],
  'study': ['coursera', 'udemy', 'khanacademy', 'duolingo', 'edx.org', 'quizlet', 'ted.com'],
  'maker': ['instructables', 'thingiverse', 'hackaday', 'printables', 'arduino.cc', 'adafruit', 'sparkfun'],
};

class CategoryClassifier {
  /// Đoán chủ đề từ chữ và liên kết. [confident] chỉ true khi một chủ đề
  /// vượt trội rõ rệt so với chủ đề còn lại.
  static CategoryGuess guess({
    required String text,
    List<String> urls = const [],
  }) {
    final padded =
        ' ${normalizeVi(text).replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';

    final scores = <String, double>{};
    _keywords.forEach((id, words) {
      var score = 0.0;
      for (final w in words) {
        if (padded.contains(' $w ')) score += w.contains(' ') ? 2 : 1;
      }
      scores[id] = score;
    });

    final lowerUrls = urls.map((u) => u.toLowerCase()).toList();
    _domains.forEach((id, hosts) {
      for (final h in hosts) {
        if (lowerUrls.any((u) => u.contains(h))) {
          scores[id] = (scores[id] ?? 0) + 3;
        }
      }
    });

    final ranked = scores.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) return CategoryGuess(null, false, scores);

    final top = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    final confident =
        top.value >= 2 && (second == 0 || top.value >= second * 1.7);
    return CategoryGuess(top.key, confident, scores);
  }
}