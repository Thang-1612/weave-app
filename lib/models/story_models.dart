import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tâm trạng AI được phép chọn (dùng để gợi ý nhạc).
const kStoryMoods = [
  'calm',
  'joyful',
  'adventurous',
  'reflective',
  'nostalgic',
  'energetic',
];

/// Bố cục AI được phép gợi ý.
const kStoryLayouts = ['timeline', 'chapters', 'highlight'];

enum StoryKind { week, trip, learning }

StoryKind storyKindFrom(String? s) => StoryKind.values.firstWhere(
      (k) => k.name == s,
  orElse: () => StoryKind.week,
);

/// voice: lưu bản chép lời (text), không lưu file âm thanh (gói Spark).
enum SourceType { photo, note, voice }

SourceType sourceTypeFrom(String? s) => SourceType.values.firstWhere(
      (k) => k.name == s,
  orElse: () => SourceType.note,
);

/// Một tư liệu gốc người dùng chọn. Đây là "nguồn" để kiểm tra lời AI.
class StorySource {
  final String id; // ví dụ s1, s2 (cũng là doc id)
  final SourceType type;
  final String text; // ghi chú hoặc bản chép lời
  final String? imageB64; // ảnh đã nén, base64
  final DateTime date;

  const StorySource({
    required this.id,
    required this.type,
    this.text = '',
    this.imageB64,
    required this.date,
  });

  Uint8List? get imageBytes =>
      imageB64 == null ? null : base64Decode(imageB64!);

  StorySource copyWith({DateTime? date}) => StorySource(
    id: id,
    type: type,
    text: text,
    imageB64: imageB64,
    date: date ?? this.date,
  );

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'text': text,
    'image': imageB64,
    'date': Timestamp.fromDate(date),
  };

  factory StorySource.fromMap(String id, Map<String, dynamic> m) =>
      StorySource(
        id: id,
        type: sourceTypeFrom(m['type'] as String?),
        text: (m['text'] ?? '') as String,
        imageB64: m['image'] as String?,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

const kBlockNarration = 'narration';
const kBlockMedia = 'media';
const kBlockQuote = 'quote';

/// Một khối của câu chuyện. Khối AI viết luôn có sourceIds.
class StoryBlock {
  final String id;
  final String type; // narration | media | quote
  final String text;
  final List<String> sourceIds;
  final bool aiGenerated;
  final String? lastEditedBy;
  final int order;

  const StoryBlock({
    required this.id,
    required this.type,
    required this.text,
    required this.sourceIds,
    required this.aiGenerated,
    this.lastEditedBy,
    required this.order,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'text': text,
    'sourceIds': sourceIds,
    'aiGenerated': aiGenerated,
    'lastEditedBy': lastEditedBy,
    'order': order,
  };

  factory StoryBlock.fromMap(String id, Map<String, dynamic> m) => StoryBlock(
    id: id,
    type: (m['type'] ?? kBlockNarration) as String,
    text: (m['text'] ?? '') as String,
    sourceIds: List<String>.from(m['sourceIds'] ?? const []),
    aiGenerated: (m['aiGenerated'] ?? false) as bool,
    lastEditedBy: m['lastEditedBy'] as String?,
    order: (m['order'] ?? 0) as int,
  );
}

class Story {
  final String id;
  final String ownerId;
  final String title;
  final StoryKind kind;
  final String mood;
  final String layout;
  final List<String> collaboratorIds;
  final List<String> missing; // câu hỏi AI cần người dùng bổ sung
  final int droppedCount; // số đoạn AI bị loại vì không có nguồn
  final DateTime updatedAt;

  const Story({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.kind,
    required this.mood,
    required this.layout,
    required this.collaboratorIds,
    required this.missing,
    required this.droppedCount,
    required this.updatedAt,
  });

  factory Story.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return Story(
      id: d.id,
      ownerId: (m['ownerId'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      kind: storyKindFrom(m['kind'] as String?),
      mood: (m['mood'] ?? 'calm') as String,
      layout: (m['layout'] ?? 'timeline') as String,
      collaboratorIds: List<String>.from(m['collaboratorIds'] ?? const []),
      missing: List<String>.from(m['missing'] ?? const []),
      droppedCount: (m['droppedCount'] ?? 0) as int,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Kết quả AI sau khi đã kiểm tra nguồn.
class StoryDraft {
  final String title;
  final String mood;
  final String layout;
  final List<StoryBlock> blocks;
  final List<String> missing;
  final int dropped;

  const StoryDraft({
    required this.title,
    required this.mood,
    required this.layout,
    required this.blocks,
    required this.missing,
    required this.dropped,
  });
}