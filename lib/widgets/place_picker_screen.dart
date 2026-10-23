import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/weave_activity.dart';
import '../services/l10n.dart';
import '../services/maps_launcher.dart';
import '../services/place_search_service.dart';
import '../theme/app_theme.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _appPackage = 'com.example.social_app';

/// Mở màn hình chọn địa điểm: tìm theo tên (bản đồ nhảy tới kết quả đầu tiên),
/// hoặc chạm bản đồ để ghim, rồi bấm "Lưu địa điểm".
/// Trả về địa điểm đã chọn (có tọa độ), hoặc null nếu hủy.
Future<WeavePlace?> pickWeavePlace(
  BuildContext context, {
  WeavePlace? initial,
  String initialName = '',
}) => Navigator.of(context).push<WeavePlace>(
  MaterialPageRoute(
    builder: (_) =>
        PlacePickerScreen(initial: initial, initialName: initialName),
  ),
);

class PlacePickerScreen extends StatefulWidget {
  final WeavePlace? initial;
  final String initialName;
  const PlacePickerScreen({super.key, this.initial, this.initialName = ''});

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  // Mặc định hiển thị Hà Nội khi chưa có địa điểm nào.
  static const _defaultCenter = LatLng(21.0285, 105.8542);

  final _map = MapController();
  final _search = TextEditingController();
  final _name = TextEditingController();

  LatLng? _pin;
  String? _address;
  bool _nameEdited = false;
  bool _searching = false;
  bool _resolving = false;
  bool _vnOnly = true; // chỉ tìm trong Việt Nam
  List<WeavePlace> _results = const [];
  int? _selected;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null && i.lat != null && i.lng != null) {
      _pin = LatLng(i.lat!, i.lng!);
      _address = i.address;
      _name.text = i.name;
      _nameEdited = true;
    } else if (widget.initialName.isNotEmpty) {
      _name.text = widget.initialName;
      _search.text = widget.initialName;
      _nameEdited = true;
    }
  }

  @override
  void dispose() {
    _map.dispose();
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  LatLng? _center() {
    try {
      return _map.camera.center;
    } catch (_) {
      return _pin;
    }
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();

    // Dán tọa độ hoặc liên kết Google Maps đầy đủ thì ghim luôn.
    final parsed = PlaceSearchService.parseMapsInput(q);
    if (parsed != null) {
      final point = LatLng(parsed.lat!, parsed.lng!);
      _map.move(point, 16);
      if (parsed.name.isNotEmpty) {
        setState(() {
          _results = const [];
          _selected = null;
          _pin = point;
          _address = null;
          _name.text = parsed.name;
          _nameEdited = false;
        });
        final r = await PlaceSearchService.reverse(
          point.latitude,
          point.longitude,
        );
        if (mounted && r != null && _pin == point) {
          setState(() => _address = r.address);
        }
      } else {
        await _onTap(point);
      }
      return;
    }
    if (PlaceSearchService.looksLikeLink(q)) {
      _toast(
        tr(
          'Không đọc được liên kết rút gọn. Mở liên kết trong trình duyệt, rồi sao chép đường dẫn đầy đủ trên thanh địa chỉ.',
          'Cannot read short links. Open the link in a browser and copy the full address from the address bar.',
        ),
      );
      return;
    }
    if (q.length < 3) {
      _toast(tr('Nhập ít nhất 3 ký tự để tìm.', 'Type at least 3 characters.'));
      return;
    }

    setState(() => _searching = true);
    try {
      final c = _center();
      final r = await PlaceSearchService.search(
        q,
        vietnamOnly: _vnOnly,
        biasLat: c?.latitude,
        biasLng: c?.longitude,
      );
      if (!mounted) return;
      setState(() => _results = r);
      if (r.isEmpty) {
        _toast(
          _vnOnly
              ? tr(
                  'Không tìm thấy ở Việt Nam. Thử từ khóa khác, tắt "Chỉ ở Việt Nam", hoặc chạm bản đồ để ghim.',
                  'Nothing found in Vietnam. Try other words, turn off "Vietnam only", or tap the map.',
                )
              : tr(
                  'Không tìm thấy. Hãy thử từ khóa khác hoặc chạm bản đồ để ghim.',
                  'Nothing found. Try other words or tap the map.',
                ),
        );
      } else {
        _choose(r.first, 0); // bản đồ nhảy tới kết quả đầu tiên
      }
    } catch (e) {
      if (mounted) {
        _toast(tr('Không tìm được địa điểm: $e', 'Search failed: $e'));
      }
    }
    if (mounted) setState(() => _searching = false);
  }

  void _choose(WeavePlace p, int index) {
    final point = LatLng(p.lat!, p.lng!);
    setState(() {
      _selected = index;
      _pin = point;
      _address = p.address;
      _name.text = p.name;
      _nameEdited = false;
    });
    _map.move(point, 16);
    FocusScope.of(context).unfocus();
  }

  Future<void> _onTap(LatLng point) async {
    setState(() {
      _pin = point;
      _address = null;
      _selected = null;
      _resolving = true;
    });
    final r = await PlaceSearchService.reverse(point.latitude, point.longitude);
    if (!mounted || _pin != point) return;
    setState(() {
      _resolving = false;
      _address = r?.address;
      if (!_nameEdited || _name.text.trim().isEmpty) {
        _name.text = r?.name.isNotEmpty == true
            ? r!.name
            : tr('Vị trí đã ghim', 'Pinned location');
        _nameEdited = false;
      }
    });
  }

  void _save() {
    final p = _pin;
    final name = _name.text.trim();
    if (p == null || name.isEmpty) return;
    Navigator.of(context).pop(
      WeavePlace(
        name: name,
        address: _address,
        lat: p.latitude,
        lng: p.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _pin != null && _name.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Chọn địa điểm', 'Choose a place'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            // Viền, bo góc và màu focus của ô nhập lấy từ theme
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: tr(
                  'Tìm địa điểm, hoặc dán liên kết / tọa độ Google Maps',
                  'Search a place, or paste a Google Maps link / coordinates',
                ),
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _runSearch,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(tr('Chỉ ở Việt Nam', 'Vietnam only')),
                selected: _vnOnly,
                onSelected: (v) {
                  setState(() => _vnOnly = v);
                  if (_search.text.trim().length >= 3) _runSearch();
                },
              ),
            ),
          ),
          if (_results.length > 1)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < _results.length; i++)
                    ListTile(
                      dense: true,
                      selected: _selected == i,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        _results[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _results[i].address ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _choose(_results[i], i),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _pin ?? _defaultCenter,
                    initialZoom: _pin != null ? 16 : 13,
                    onTap: (_, point) => _onTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _tileUrl,
                      userAgentPackageName: _appPackage,
                    ),
                    if (_pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pin!,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on,
                              size: 44,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: Colors.white70,
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                if (_pin == null)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tr(
                            'Tìm địa điểm hoặc chạm vào bản đồ để ghim',
                            'Search a place or tap the map to drop a pin',
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 100,
                    onChanged: (_) => setState(() => _nameEdited = true),
                    decoration: InputDecoration(
                      labelText: tr('Tên địa điểm', 'Place name'),
                      isDense: true,
                    ),
                  ),
                  if (_resolving)
                    Text(
                      tr('Đang tra địa chỉ…', 'Looking up address…'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  else if ((_address ?? '').isNotEmpty)
                    Text(
                      _address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_pin != null)
                        TextButton.icon(
                          onPressed: () => openInGoogleMaps(
                            context,
                            WeavePlace(
                              name: _name.text.trim(),
                              lat: _pin!.latitude,
                              lng: _pin!.longitude,
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: Text(
                            tr('Xem trên Google Maps', 'View in Google Maps'),
                          ),
                        ),
                      const Spacer(),
                      // Nút chính duy nhất của màn hình: màu theo theme
                      FilledButton.icon(
                        onPressed: canSave ? _save : null,
                        icon: const Icon(Icons.check),
                        label: Text(tr('Lưu địa điểm', 'Save place')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bản đồ nhỏ chỉ để xem vị trí đã ghim; chạm để mở Google Maps.
class WeaveMapPreview extends StatelessWidget {
  final WeavePlace place;
  final double height;
  const WeaveMapPreview({super.key, required this.place, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final lat = place.lat, lng = place.lng;
    if (lat == null || lng == null) return const SizedBox.shrink();
    final point = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(WeaveRadius.control),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('$lat,$lng'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
                onTap: (_, _) => openInGoogleMaps(context, place),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: _appPackage,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 6,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                color: Colors.white70,
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
