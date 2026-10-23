import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'l10n.dart';

const maxImageBytes = 160 * 1024;

class CompressedImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const CompressedImage(this.bytes, this.width, this.height);
}

// Chạy trong isolate (trên web chạy ngay trên luồng chính).
// Không dùng tr(...) ở đây vì isolate không biết ngôn ngữ đang chọn:
// hàm trả về mã lỗi, phần dịch nằm ở compressImage bên dưới.
Map<String, Object> _compressSync(Uint8List raw) {
  final decodedRaw = img.decodeImage(raw);
  if (decodedRaw == null) return {'error': 'decode'};
  final decoded = img.bakeOrientation(decodedRaw); // xoay đúng chiều ảnh chụp

  const sides = [1024, 900, 768, 640];
  const qualities = [72, 62, 55, 48];

  Uint8List? best;
  var bestW = 0;
  var bestH = 0;

  for (var i = 0; i < sides.length; i++) {
    final side = sides[i];
    final resized = (decoded.width > side || decoded.height > side)
        ? (decoded.width >= decoded.height
              ? img.copyResize(decoded, width: side)
              : img.copyResize(decoded, height: side))
        : decoded;
    final out = Uint8List.fromList(
      img.encodeJpg(resized, quality: qualities[i]),
    );
    best = out;
    bestW = resized.width;
    bestH = resized.height;
    if (out.length <= maxImageBytes) break;
  }

  if (best == null || best.length > maxImageBytes * 1.5) {
    return {'error': 'large'};
  }
  return {'bytes': best, 'w': bestW, 'h': bestH};
}

/// Thu nhỏ và nén ảnh để lưu gọn trong bài đăng.
Future<CompressedImage> compressImage(Uint8List raw) async {
  final m = await compute(_compressSync, raw);
  final err = m['error'];
  if (err == 'decode') {
    throw Exception(tr('Không đọc được ảnh này', 'Could not read this image'));
  }
  if (err == 'large') {
    throw Exception(
      tr(
        'Ảnh quá lớn, hãy chọn ảnh khác',
        'This image is too large, please pick another',
      ),
    );
  }
  return CompressedImage(m['bytes'] as Uint8List, m['w'] as int, m['h'] as int);
}
