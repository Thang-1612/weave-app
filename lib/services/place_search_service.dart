import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../models/weave_activity.dart';

/// Tìm địa điểm miễn phí, không cần API key.
/// - Tìm kiếm: Nominatim (OpenStreetMap); nếu ít kết quả thì gộp thêm Photon.
/// - Tra địa chỉ từ tọa độ: Nominatim.
/// Chỉ gọi khi người dùng chủ động bấm tìm hoặc chạm bản đồ, vì các dịch vụ
/// miễn phí giới hạn tần suất.
class PlaceSearchService {
  PlaceSearchService._();

  static const _nominatim = 'nominatim.openstreetmap.org';
  static const _timeout = Duration(seconds: 10);

  static Map<String, String> get _headers =>
      {if (!kIsWeb) 'User-Agent': 'WeaveApp/1.0 (com.example.social_app)'};

  static String _shortName(Map<String, dynamic> e) {
    final n = (e['name'] as String?)?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final d = (e['display_name'] as String?) ?? '';
    return d.split(',').first.trim();
  }

  static WeavePlace? _nominatimPlace(Map<String, dynamic> e) {
    final lat = double.tryParse('${e['lat']}');
    final lng = double.tryParse('${e['lon']}');
    if (lat == null || lng == null) return null;
    return WeavePlace(
      name: _shortName(e),
      address: e['display_name'] as String?,
      lat: lat,
      lng: lng,
    );
  }

  static Future<List<WeavePlace>> _searchNominatim(
      String q, int limit, bool vietnamOnly) async {
    final uri = Uri.https(_nominatim, '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '$limit',
      'accept-language': 'vi,en',
      if (vietnamOnly) 'countrycodes': 'vn',
    });
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Nominatim ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    final out = <WeavePlace>[];
    for (final e in list) {
      final p = _nominatimPlace(Map<String, dynamic>.from(e as Map));
      if (p != null) out.add(p);
    }
    return out;
  }

  static Future<List<WeavePlace>> _searchPhoton(
      String q, int limit, bool vietnamOnly,
      {double? biasLat, double? biasLng}) async {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      // Lấy dư rồi lọc theo quốc gia, vì khung tìm kiếm cũng phủ nước láng giềng.
      'limit': vietnamOnly ? '${limit * 3}' : '$limit',
      // Khung tọa độ bao quanh Việt Nam (kinh độ min, vĩ độ min, kinh độ max,
      // vĩ độ max).
      if (vietnamOnly) 'bbox': '102.0,6.5,118.0,23.5',
      if (biasLat != null && biasLng != null) ...{
        'lat': '$biasLat',
        'lon': '$biasLng',
      },
    });
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Photon ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final feats = (body['features'] as List?) ?? const [];
    final out = <WeavePlace>[];
    for (final f in feats) {
      final m = Map<String, dynamic>.from(f as Map);
      final coords = (m['geometry']?['coordinates'] as List?) ?? const [];
      if (coords.length < 2) continue;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final props = Map<String, dynamic>.from((m['properties'] as Map?) ?? {});
      if (vietnamOnly &&
          ((props['countrycode'] as String?) ?? '').toUpperCase() != 'VN') {
        continue;
      }

      String s(String k) => ((props[k] as String?) ?? '').trim();
      final street =
      [s('housenumber'), s('street')].where((x) => x.isNotEmpty).join(' ');
      final parts = <String>[];
      for (final x in [
        s('name'),
        street,
        s('district'),
        s('locality'),
        s('city'),
        s('state'),
        s('country'),
      ]) {
        if (x.isNotEmpty && !parts.contains(x)) parts.add(x);
      }
      if (parts.isEmpty) continue;
      out.add(WeavePlace(
        name: s('name').isNotEmpty ? s('name') : parts.first,
        address: parts.join(', '),
        lat: lat,
        lng: lng,
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  static bool _samePlace(WeavePlace a, WeavePlace b) {
    final close = a.lat != null &&
        a.lng != null &&
        b.lat != null &&
        b.lng != null &&
        (a.lat! - b.lat!).abs() < 0.0005 &&
        (a.lng! - b.lng!).abs() < 0.0005;
    return close || a.name.toLowerCase() == b.name.toLowerCase();
  }

  /// [vietnamOnly] = true: chỉ trả về địa điểm ở Việt Nam (mặc định).
  /// [biasLat]/[biasLng]: ưu tiên kết quả gần điểm này (tâm bản đồ).
  static Future<List<WeavePlace>> search(
      String query, {
        int limit = 6,
        bool vietnamOnly = true,
        double? biasLat,
        double? biasLng,
      }) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    var results = <WeavePlace>[];
    Object? firstError;
    try {
      results = await _searchNominatim(q, limit, vietnamOnly);
    } catch (e) {
      firstError = e;
      debugPrint('Place search (Nominatim) failed: $e');
    }
    if (results.length >= 3) return results;

    try {
      final more = await _searchPhoton(q, limit, vietnamOnly,
          biasLat: biasLat, biasLng: biasLng);
      for (final p in more) {
        if (!results.any((r) => _samePlace(r, p))) results.add(p);
      }
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('Place search (Photon) failed: $e');
      if (results.isNotEmpty || firstError == null) return results;
      throw Exception('$firstError; $e');
    }
  }

  /// Dán từ Google Maps: tọa độ ("21.0285, 105.8542") hoặc liên kết đầy đủ
  /// của một địa điểm. Không đọc được thì trả về null.
  static WeavePlace? parseMapsInput(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    bool ok(double? la, double? lo) =>
        la != null && lo != null && la.abs() <= 90 && lo.abs() <= 180;

    final plain = RegExp(r'^(-?\d{1,2}\.\d+)\s*[,;\s]\s*(-?\d{1,3}\.\d+)$')
        .firstMatch(s);
    if (plain != null) {
      final la = double.tryParse(plain.group(1)!);
      final lo = double.tryParse(plain.group(2)!);
      if (ok(la, lo)) return WeavePlace(name: '', lat: la, lng: lo);
    }

    if (!s.toLowerCase().startsWith('http')) return null;
    String text;
    try {
      text = Uri.decodeFull(s);
    } catch (_) {
      text = s;
    }

    final patterns = <RegExp>[
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'[?&](?:q|query|ll|center|destination)=(-?\d+\.\d+),\s*(-?\d+\.\d+)'),
    ];
    for (final re in patterns) {
      // Liên kết chỉ có @vĩ độ,kinh độ mà không phải trang một địa điểm là
      // tọa độ tâm khung nhìn bản đồ, không phải vị trí địa điểm: bỏ qua.
      if (re.pattern.startsWith('@') && !text.contains('/maps/place/')) {
        continue;
      }
      final m = re.firstMatch(text);
      if (m == null) continue;
      final la = double.tryParse(m.group(1)!);
      final lo = double.tryParse(m.group(2)!);
      if (!ok(la, lo)) continue;
      var name = '';
      final nm = RegExp(r'/maps/place/([^/@?]+)').firstMatch(text);
      if (nm != null) name = nm.group(1)!.replaceAll('+', ' ').trim();
      return WeavePlace(name: name, lat: la, lng: lo);
    }
    return null;
  }

  /// Liên kết nhưng không đọc được tọa độ (thường là liên kết rút gọn).
  static bool looksLikeLink(String input) {
    final s = input.trim().toLowerCase();
    return s.startsWith('http') || s.contains('goo.gl');
  }

  /// Tên và địa chỉ gần nhất với tọa độ. Trả về null nếu không tra được.
  static Future<WeavePlace?> reverse(double lat, double lng) async {
    try {
      final uri = Uri.https(_nominatim, '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'accept-language': 'vi,en',
      });
      final res = await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final e = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      if (e['error'] != null) return null;
      return WeavePlace(
        name: _shortName(e),
        address: e['display_name'] as String?,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
      return null;
    }
  }
}