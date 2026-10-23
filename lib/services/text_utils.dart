// Bỏ dấu tiếng Việt để tìm kiếm không phân biệt dấu và hoa thường.
const _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _viMap = {
  for (final e in _groups.entries)
    for (final c in e.value.split('')) c: e.key,
};

/// "Nguyễn Văn Ân" -> "nguyen van an"
String normalizeVi(String input) {
  final lower = input.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(_viMap[ch] ?? ch);
  }
  return b.toString();
}

/// Danh sách tiền tố của từng từ trong tên, dùng để tìm kiếm theo chữ đầu.
/// "An Bình" -> [a, an, b, bi, bin, binh]
List<String> searchTokensOf(String name) {
  final tokens = <String>{};
  for (final w in normalizeVi(name).split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    final max = w.length > 20 ? 20 : w.length;
    for (var i = 1; i <= max; i++) {
      tokens.add(w.substring(0, i));
    }
  }
  return tokens.toList();
}
