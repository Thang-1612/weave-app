import 'dart:async';

import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/weave_error_view.dart';
import '../widgets/weave_state_views.dart';

/// Màn tạo cuộc trò chuyện: tab "Nhắn tin" (1-1) và tab "Tạo nhóm".
/// Khi xong sẽ `Navigator.pop(context, chatId)` để nơi gọi mở chat đó.
class NewChatScreen extends StatefulWidget {
  final bool startOnGroup;

  /// Chế độ chọn người (thêm thành viên vào nhóm): không tạo chat,
  /// chỉ trả về `List<String>` uid đã chọn qua Navigator.pop.
  final bool pickOnly;

  /// Các uid không hiển thị (ví dụ thành viên đã có trong nhóm).
  final Iterable<String> exclude;

  const NewChatScreen({
    super.key,
    this.startOnGroup = false,
    this.pickOnly = false,
    this.exclude = const [],
  });
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final svc = ChatService.I;
  final _search = TextEditingController();
  final _name = TextEditingController();
  final Set<String> _picked = {};
  late final Set<String> _ex = widget.exclude.toSet();
  // Không để final: nút Thử lại gán stream mới để tải lại thật.
  late Stream<List<String>> _friends = svc.friendIds();
  Timer? _deb;
  List<ChatUser>? _results; // null = chưa tìm, hiện danh sách bạn bè
  bool _busy = false;

  @override
  void dispose() {
    _deb?.cancel();
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  void _err(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  void _onQuery(String v) {
    final q = v.trim();
    _deb?.cancel();
    if (q.isEmpty) {
      setState(() => _results = null);
      return;
    }
    _deb = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await svc.searchUsers(q);
        if (mounted && _search.text.trim() == q) setState(() => _results = r);
      } catch (e) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  void _toggle(String uid) => setState(() {
    if (!_picked.remove(uid)) _picked.add(uid);
  });

  Future<void> _startDirect(String uid) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await svc.ensureDirect(uid);
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      _err('Không mở được chat: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canCreate =>
      !_busy && _name.text.trim().isNotEmpty && _picked.length >= 2;

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _busy = true);
    try {
      final id = await svc.createGroup(_name.text.trim(), _picked.toList());
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      _err('Không tạo được nhóm: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  // Ô tìm kiếm: nền Background, bo 12, không viền; viền Brand Indigo khi focus.
  // (Theme có viền cho mọi ô nhập nên phải đặt rõ enabledBorder / focusedBorder.)
  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: _search,
        onChanged: _onQuery,
        decoration: InputDecoration(
          hintText: 'Tìm người theo tên',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WeaveRadius.control),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WeaveRadius.control),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(WeaveRadius.control),
            borderSide: const BorderSide(color: AppColors.brand),
          ),
        ),
      ),
    );
  }

  Widget _row(String uid, bool multi) {
    return FutureBuilder<ChatUser>(
      future: svc.user(uid),
      initialData: svc.cached(uid),
      builder: (c, s) => ListTile(
        leading: UserAvatar(uid),
        title: Text(
          s.data?.name ?? '…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: multi
            ? Checkbox(
          value: _picked.contains(uid),
          onChanged: (_) => _toggle(uid),
        )
            : null,
        onTap: multi ? () => _toggle(uid) : () => _startDirect(uid),
      ),
    );
  }

  Widget _people(bool multi) {
    final res = _results?.where((u) => !_ex.contains(u.uid)).toList();
    if (res != null) {
      if (res.isEmpty) {
        return const WeaveEmptyView(
          icon: Icons.search_off,
          title: 'Không tìm thấy ai',
        );
      }
      return ListView(children: [for (final u in res) _row(u.uid, multi)]);
    }
    return StreamBuilder<List<String>>(
      stream: _friends,
      builder: (c, s) {
        if (s.hasError) {
          debugPrint('NewChatScreen friends error: ${s.error}');
          return WeaveErrorView(
            message: 'Không tải được danh sách bạn bè.',
            onRetry: () => setState(() => _friends = svc.friendIds()),
          );
        }
        if (!s.hasData) {
          return const WeaveLoadingView();
        }
        final ids = s.data!.where((u) => !_ex.contains(u)).toList();
        if (ids.isEmpty) {
          return const WeaveEmptyView(
            icon: Icons.people_outline,
            title: 'Chưa có bạn bè.',
            description: 'Hãy gõ tên ở ô trên để tìm người.',
          );
        }
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Bạn bè',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            for (final id in ids) _row(id, multi),
          ],
        );
      },
    );
  }

  Widget _groupTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _name,
            maxLength: 50,
            onChanged: (_) => setState(() {}),
            // Viền, bo góc và màu focus lấy từ theme
            decoration: const InputDecoration(
              labelText: 'Tên nhóm',
              prefixIcon: Icon(Icons.groups_outlined),
              counterText: '',
              isDense: true,
            ),
          ),
        ),
        if (_picked.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final u in _picked)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border),
                      label: Text(svc.cached(u)?.name ?? '…'),
                      onDeleted: () => _toggle(u),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(child: _people(true)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canCreate ? _create : null,
                child: _busy
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  _picked.length < 2
                      ? 'Chọn ít nhất 2 người'
                      : 'Tạo nhóm (${_picked.length})',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Chế độ chọn người để thêm vào nhóm
  Widget _pickScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm thành viên')),
      body: Column(
        children: [
          _searchField(),
          Expanded(child: _people(true)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _picked.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_picked.toList()),
                  child: Text(
                    _picked.isEmpty
                        ? 'Chọn người để thêm'
                        : 'Thêm (${_picked.length})',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pickOnly) return _pickScaffold();
    return DefaultTabController(
      length: 2,
      initialIndex: widget.startOnGroup ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuộc trò chuyện mới'),
          // AppBar nền sáng: tab dùng màu thương hiệu (trước đây là chữ trắng)
          bottom: const TabBar(
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.brand,
            tabs: [
              Tab(text: 'Nhắn tin'),
              Tab(text: 'Tạo nhóm'),
            ],
          ),
        ),
        body: Column(
          children: [
            _searchField(),
            Expanded(
              child: TabBarView(children: [_people(false), _groupTab()]),
            ),
          ],
        ),
      ),
    );
  }
}