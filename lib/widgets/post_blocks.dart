import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';

/// Hiển thị nội dung theo từng khối.
///
/// - `PostBlocks(post: p)`: nội dung bài đăng (lớp gốc), dùng như cũ.
/// - `PostBlocks.layer(blocks: l.blocks)`: nội dung một lớp của Weave.
class PostBlocks extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;

  /// Bài cũ chưa có khối: hiện phần chữ này.
  final String fallbackText;

  PostBlocks({super.key, required Post post})
      : blocks = post.blocks,
        fallbackText = post.text;

  const PostBlocks.layer({super.key, required this.blocks})
      : fallbackText = '';

  static const _textStyle = TextStyle(fontSize: 15, height: 1.4);

  Widget? _buildBlock(Map<String, dynamic> b) {
    switch (b['type']) {
      case 'text':
        final t = (b['text'] as String? ?? '').trim();
        return t.isEmpty ? null : Text(t, style: _textStyle);
      case 'image':
        final data = b['data'] as String? ?? '';
        if (data.isEmpty) return null;
        return _Base64Image(
          data: data,
          width: (b['w'] as num?)?.toDouble() ?? 4,
          height: (b['h'] as num?)?.toDouble() ?? 3,
        );
      case 'link':
        final url = b['url'] as String? ?? '';
        if (url.isEmpty) return null;
        return LinkCard(url: url, title: b['title'] as String? ?? '');
      case 'emoji':
        final v = b['value'] as String? ?? '';
        return v.isEmpty ? null : Text(v, style: const TextStyle(fontSize: 64));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chưa có khối: hiện phần chữ (nếu có)
    if (blocks.isEmpty) {
      return fallbackText.isEmpty
          ? const SizedBox.shrink()
          : Text(fallbackText, style: _textStyle);
    }

    final children = <Widget>[];
    final inline = StringBuffer(); // chữ và emoji liền nhau gom thành một đoạn
    var lastKind = ''; // '', 'text' hoặc 'emoji'

    void flush() {
      final t = inline.toString().trim();
      inline.clear();
      lastKind = '';
      if (t.isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(Text(t, style: _textStyle));
    }

    for (final b in blocks) {
      final type = b['type'];
      if (type == 'text') {
        final t = (b['text'] as String? ?? '').trim();
        if (t.isEmpty) continue;
        if (lastKind == 'text') inline.write('\n');
        if (lastKind == 'emoji') inline.write(' ');
        inline.write(t);
        lastKind = 'text';
      } else if (type == 'emoji') {
        final v = b['value'] as String? ?? '';
        if (v.isEmpty) continue;
        if (lastKind == 'text') inline.write(' ');
        inline.write(v);
        lastKind = 'emoji';
      } else {
        // Ảnh hoặc liên kết: kết thúc đoạn chữ trước đó rồi hiện khối riêng
        flush();
        final w = _buildBlock(b);
        if (w != null) {
          if (children.isNotEmpty) children.add(const SizedBox(height: 10));
          children.add(w);
        }
      }
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _Base64Image extends StatefulWidget {
  final String data;
  final double width;
  final double height;

  const _Base64Image({
    required this.data,
    required this.width,
    required this.height,
  });

  @override
  State<_Base64Image> createState() => _Base64ImageState();
}

class _Base64ImageState extends State<_Base64Image> {
  late final Uint8List _bytes = base64Decode(widget.data);

  @override
  Widget build(BuildContext context) {
    final ratio = (widget.width / widget.height).clamp(0.7, 1.8).toDouble();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _ImageViewer(bytes: _bytes)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Image.memory(
            _bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final Uint8List bytes;

  const _ImageViewer({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

String _hostOf(String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Thẻ liên kết: bấm để mở trong trình duyệt.
class LinkCard extends StatelessWidget {
  final String url;
  final String title;

  const LinkCard({super.key, required this.url, this.title = ''});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = SnackBar(
      content: Text(tr('Không mở được liên kết', 'Could not open the link')),
    );
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) messenger.showSnackBar(failed);
    } catch (_) {
      messenger.showSnackBar(failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _hostOf(url);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.link, color: AppColors.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    title.isNotEmpty ? '$host · $url' : url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}