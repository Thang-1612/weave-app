import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/weave_activity.dart';
import 'l10n.dart';

/// Mở địa điểm trong Google Maps (ứng dụng hoặc trình duyệt).
/// Có tọa độ thì ghim đúng tọa độ, không thì tìm theo tên và địa chỉ.
Future<void> openInGoogleMaps(BuildContext context, WeavePlace p) async {
  final messenger = ScaffoldMessenger.of(context);
  final String query;
  if (p.lat != null && p.lng != null) {
    query = '${p.lat},${p.lng}';
  } else {
    query = [
      p.name,
      p.address ?? '',
    ].where((s) => s.trim().isNotEmpty).join(', ');
  }
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('launch failed');
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tr('Không mở được Google Maps.', 'Could not open Google Maps.'),
        ),
      ),
    );
  }
}
