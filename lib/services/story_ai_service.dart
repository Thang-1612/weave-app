import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/story_models.dart';

class StoryAiException implements Exception {
  final String message;
  StoryAiException(this.message);
  @override
  String toString() => message;
}

/// Dựng câu chuyện từ tư liệu thật. Chống bịa bằng 2 lớp:
/// 1) Prompt + schema ép mỗi đoạn phải kèm sourceIds.
/// 2) Phía app kiểm tra lại: đoạn không có nguồn hợp lệ sẽ bị loại,
///    trích dẫn phải xuất hiện nguyên văn trong ghi chú được dẫn.
class StoryAiService {
  // Đổi cho khớp model và cách khởi tạo trong ai_classifier.dart của bạn.
  static const _modelName = 'gemini-2.5-flash';

  static const _system = '''
You turn a person's real material (photos, notes, voice transcripts) into a structured personal story.

STRICT RULES
- Use ONLY information that appears in the sources. Never invent names, places, dates, feelings, causes or events.
- For photos, describe only what is clearly visible. Do not guess locations or who people are.
- Every "narration" and "quote" block MUST list the ids of the sources that directly support it in sourceIds. Use only ids that exist in the input.
- "quote": text must be copied word for word from a note or transcript, and sourceIds must point to it.
- "media": sourceIds must contain exactly one photo id. text is a short caption based only on that photo or on notes of the same day (may be empty).
- Write narration in the first person, in the same language as the notes (Vietnamese if unclear), warm but plain.
- Order blocks by the sources' dates. Produce between 4 and 12 blocks.
- If important context is missing (who, where, when, why), do NOT guess. Add a short question in the user's language to "missing" (max 4).
- mood and layout must be chosen from the allowed values.
- Story types: week = a recap of highlights day by day; trip = places and moments in order; learning = what was studied, what was hard, what progressed.
''';

  static final _schema = Schema.object(properties: {
    'title': Schema.string(),
    'mood': Schema.enumString(enumValues: kStoryMoods),
    'layout': Schema.enumString(enumValues: kStoryLayouts),
    'blocks': Schema.array(
      items: Schema.object(properties: {
        'type': Schema.enumString(
          enumValues: [kBlockNarration, kBlockMedia, kBlockQuote],
        ),
        'text': Schema.string(),
        'sourceIds': Schema.array(items: Schema.string()),
      }),
    ),
    'missing': Schema.array(items: Schema.string()),
  });

  static GenerativeModel? _model;
  static GenerativeModel get _m => _model ??= FirebaseAI.googleAI()
      .generativeModel(
    model: _modelName,
    systemInstruction: Content.system(_system),
    generationConfig: GenerationConfig(
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: _schema,
    ),
  );

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<StoryDraft> generate({
    required StoryKind kind,
    String userTitle = '',
    required List<StorySource> sources,
  }) async {
    if (sources.isEmpty) throw StoryAiException('Chưa có tư liệu nào.');

    final ordered = [...sources]..sort((a, b) => a.date.compareTo(b.date));
    final parts = <Part>[
      TextPart(
        'Story type: ${kind.name}.'
            '${userTitle.trim().isEmpty ? '' : ' Working title from the user: ${userTitle.trim()}.'}'
            '\nSources follow. Each one starts with a [SOURCE ...] header.',
      ),
    ];
    for (final s in ordered) {
      parts.add(TextPart(
        '[SOURCE id=${s.id} type=${s.type.name} date=${_ymd(s.date)}]',
      ));
      final bytes = s.imageBytes;
      if (s.type == SourceType.photo && bytes != null) {
        parts.add(InlineDataPart('image/jpeg', bytes));
      } else {
        parts.add(TextPart(s.text));
      }
    }

    final res = await _m.generateContent([Content.multi(parts)]);
    var raw = (res.text ?? '').trim();
    if (raw.isEmpty) throw StoryAiException('AI không trả về nội dung.');
    raw = raw.replaceAll(RegExp(r'^```(?:json)?|```$', multiLine: true), '').trim();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw StoryAiException('Không đọc được kết quả của AI. Hãy thử lại.');
    }
    return _validate(json, sources);
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static StoryDraft _validate(
      Map<String, dynamic> json,
      List<StorySource> sources,
      ) {
    final byId = {for (final s in sources) s.id: s};
    final blocks = <StoryBlock>[];
    var dropped = 0;

    for (final b in (json['blocks'] as List? ?? const [])) {
      if (b is! Map) {
        dropped++;
        continue;
      }
      final type = '${b['type']}';
      final text = '${b['text'] ?? ''}'.trim();
      final rawIds = [for (final x in (b['sourceIds'] as List? ?? const [])) '$x'];
      // Có id không tồn tại nghĩa là AI dẫn nguồn bịa: loại luôn khối này.
      var ids = rawIds;
      var ok = rawIds.isNotEmpty && rawIds.every(byId.containsKey);

      if (ok) {
        switch (type) {
          case kBlockMedia:
            final photos = ids
                .where((id) => byId[id]!.type == SourceType.photo)
                .toList();
            ok = photos.isNotEmpty;
            if (ok) ids = [photos.first];
            break;
          case kBlockQuote:
            ok = text.isNotEmpty &&
                ids.any((id) {
                  final s = byId[id]!;
                  return s.type != SourceType.photo &&
                      _norm(s.text).contains(_norm(text));
                });
            break;
          case kBlockNarration:
            ok = text.isNotEmpty;
            break;
          default:
            ok = false;
        }
      }

      if (!ok) {
        dropped++;
        continue;
      }
      blocks.add(StoryBlock(
        id: '',
        type: type,
        text: text,
        sourceIds: ids,
        aiGenerated: true,
        order: blocks.length * 1000,
      ));
    }

    if (blocks.isEmpty) {
      throw StoryAiException(
        'AI không tạo được đoạn nào có nguồn rõ ràng. Hãy thêm ghi chú hoặc ảnh rồi thử lại.',
      );
    }

    final mood = '${json['mood']}';
    final layout = '${json['layout']}';
    final title = '${json['title'] ?? ''}'.trim();
    return StoryDraft(
      title: title.isEmpty ? 'Câu chuyện của tôi' : title,
      mood: kStoryMoods.contains(mood) ? mood : 'calm',
      layout: kStoryLayouts.contains(layout) ? layout : 'timeline',
      blocks: blocks,
      missing: [
        for (final x in (json['missing'] as List? ?? const []).take(4)) '$x',
      ],
      dropped: dropped,
    );
  }

  /// Chép lời bản ghi âm ngắn thành văn bản (dùng khi thêm nút ghi âm).
  static Future<String> transcribe(List<int> bytes, String mimeType) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(temperature: 0),
    );
    final res = await model.generateContent([
      Content.multi([
        TextPart(
          'Transcribe this audio exactly as spoken, in its original language. '
              'Output only the transcript, no commentary.',
        ),
        InlineDataPart(mimeType, Uint8List.fromList(bytes)),
      ]),
    ]);
    return (res.text ?? '').trim();
  }
}