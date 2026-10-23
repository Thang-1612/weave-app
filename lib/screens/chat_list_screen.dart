import '../theme/app_theme.dart';

import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/chat_friends.dart';
import 'chat_room_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  /// Từ bề rộng KHUNG CHỨA này trở lên dùng bố cục 2 cột: danh sách | phòng chat.
  /// (Đo bằng LayoutBuilder chứ không phải cả cửa sổ, vì khung điều hướng
  /// desktop đã chiếm một phần chiều ngang bằng sidebar.)
  /// 800 = 340 cho danh sách + tối thiểu 460 cho phòng chat.
  static const double _wideBreakpoint = 800;

  /// Chiều rộng cột danh sách hội thoại trên desktop (quy chuẩn 300–340).
  static const double _listWidth = 340;

  /// Chừa chỗ cuối danh sách trên điện thoại để nút + không che hội thoại cuối.
  static const double _fabClearance = 88;

  final svc = ChatService.I;
  late final Stream<List<Chat>> _stream = svc.myChats();
  bool _searching = false; // chỉ dùng cho điện thoại
  String _q = '';
  String? _selected; // chat đang mở ở khung phải (máy tính)
  int _tab = 0; // 0 = tất cả, 1 = tin chờ (máy tính)

  // Được cập nhật trong LayoutBuilder của build()
  bool _wide = false;

  /// uid đã yêu cầu tải tên: mỗi uid chỉ tải một lần.
  final Set<String> _nameRequested = {};

  /// Tải trước tên người đối thoại còn thiếu trong cache, xong thì vẽ lại.
  void _prefetchNames(List<Chat> l) {
    for (final c in l) {
      if (c.isGroup) continue;
      final uid = c.otherId(svc.me);
      if (svc.cached(uid) != null || !_nameRequested.add(uid)) continue;
      svc.user(uid).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  List<Chat> _sort(List<Chat> l, String me) => [
    ...l.where((c) => c.pinnedBy.contains(me)),
    ...l.where((c) => !c.pinnedBy.contains(me)),
  ];

  void _open(String chatId) {
    if (_wide) {
      setState(() => _selected = chatId);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chatId)));
    }
  }

  Future<void> _newChat({bool group = false}) async {
    final String? id;
    if (_wide) {
      id = await showDialog<String>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 480,
            height: 620,
            child: NewChatScreen(startOnGroup: group),
          ),
        ),
      );
    } else {
      id = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => NewChatScreen(startOnGroup: group)),
      );
    }
    if (id != null && mounted) _open(id);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _wide =
            constraints.maxWidth.isFinite &&
            constraints.maxWidth >= _wideBreakpoint;
        final me = svc.me;
        return StreamBuilder<List<Chat>>(
          stream: _stream,
          builder: (context, snap) {
            final all = (snap.data ?? [])
                .where((c) => c.hasMessages || c.isGroup)
                .toList();
            final requests = all
                .where(
                  (c) =>
                      !c.isGroup &&
                      !c.acceptedBy.contains(me) &&
                      c.lastSenderId != me,
                )
                .toList();
            final main = _sort(
              all.where((c) => !requests.contains(c)).toList(),
              me,
            );
            return _wide
                ? _desktop(snap, main, requests)
                : _mobile(snap, main, requests);
          },
        );
      },
    );
  }

  // Lỗi / đang tải dùng chung cho cả hai bố cục
  Widget _state(AsyncSnapshot<List<Chat>> snap, Widget Function() child) {
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Không tải được danh sách chat.\nCó thể thiếu chỉ mục Firestore – mở log để lấy liên kết tạo chỉ mục.\n${snap.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return child();
  }

  // Chip kiểu Weave: nền trắng, viền mảnh; đang chọn = Soft Indigo.
  Widget _withChipTheme(Widget child) {
    return ChipTheme(
      data: ChipTheme.of(context).copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.soft,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      child: child,
    );
  }

  // ───────────── Điện thoại ─────────────
  Widget _mobile(
    AsyncSnapshot<List<Chat>> snap,
    List<Chat> main,
    List<Chat> requests,
  ) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Tìm cuộc trò chuyện…',
                    // Ô tìm trong AppBar: không nền, không viền (theme mặc định có viền)
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _q = v),
                )
              : const Text('Tin nhắn'),
          actions: [
            IconButton(
              tooltip: 'Tạo nhóm',
              icon: const Icon(Icons.group_add_outlined),
              onPressed: () => _newChat(group: true),
            ),
            IconButton(
              tooltip: _searching ? 'Đóng tìm kiếm' : 'Tìm kiếm',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                _q = '';
              }),
            ),
          ],
          // AppBar nền sáng nên tab dùng màu thương hiệu (trước đây là chữ trắng)
          bottom: TabBar(
            labelColor: AppColors.brand,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.brand,
            tabs: [
              // "Tất cả" (giống desktop), tránh trùng với tiêu đề "Tin nhắn"
              const Tab(text: 'Tất cả'),
              Tab(
                text: requests.isEmpty
                    ? 'Tin chờ'
                    : 'Tin chờ (${requests.length})',
              ),
            ],
          ),
        ),
        body: _state(
          snap,
          () => TabBarView(
            children: [
              Column(
                children: [
                  if (!_searching) const FriendsStrip(),
                  if (!_searching) const Divider(height: 1),
                  Expanded(
                    child: _list(
                      main,
                      'Chưa có cuộc trò chuyện.\nBấm nút + để bắt đầu.',
                    ),
                  ),
                ],
              ),
              _list(requests, 'Không có tin nhắn chờ.'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Tạo cuộc trò chuyện',
          onPressed: () => _newChat(),
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }

  // ───────────── Máy tính: 2 cột (danh sách | phòng chat) ─────────────
  Widget _desktop(
    AsyncSnapshot<List<Chat>> snap,
    List<Chat> main,
    List<Chat> requests,
  ) {
    final list = _tab == 0 ? main : requests;
    // Chỉ hiện nút Quay lại khi màn này thật sự được đẩy lên từ một màn khác;
    // nếu nó là một mục gốc của khung điều hướng thì không có gì để quay về.
    final canGoBack = Navigator.of(context).canPop();
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: _listWidth,
            // Material (không phải ColoredBox) để ListTile vẽ được màu mục chọn
            child: Material(
              color: AppColors.surface,
              child: Column(
                children: [
                  // Cao bằng AppBar của phòng chat bên phải, có viền dưới để hai
                  // bên thẳng hàng.
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            canGoBack ? 4 : 12,
                            0,
                            4,
                            0,
                          ),
                          child: Row(
                            children: [
                              if (canGoBack)
                                IconButton(
                                  tooltip: 'Quay lại',
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                ),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Tìm kiếm',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                    ),
                                    isDense: true,
                                    filled: true,
                                    fillColor: AppColors.background,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WeaveRadius.control,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WeaveRadius.control,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WeaveRadius.control,
                                      ),
                                      borderSide: const BorderSide(
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) => setState(() => _q = v),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Tạo cuộc trò chuyện',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _newChat(),
                              ),
                              IconButton(
                                tooltip: 'Tạo nhóm',
                                icon: const Icon(Icons.group_add_outlined),
                                onPressed: () => _newChat(group: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: _withChipTheme(
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: _tab == 0,
                            onSelected: (_) => setState(() => _tab = 0),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              requests.isEmpty
                                  ? 'Tin chờ'
                                  : 'Tin chờ (${requests.length})',
                            ),
                            selected: _tab == 1,
                            onSelected: (_) => setState(() => _tab = 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_tab == 0 && _q.isEmpty) FriendsStrip(onOpen: _open),
                  const Divider(height: 1),
                  Expanded(
                    child: _state(
                      snap,
                      () => _list(
                        list,
                        _tab == 0
                            ? 'Chưa có cuộc trò chuyện.\nChọn một người bạn ở trên để bắt đầu.'
                            : 'Không có tin nhắn chờ.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _rightPane()),
        ],
      ),
    );
  }

  Widget _rightPane() {
    final id = _selected;
    if (id == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'Chào mừng đến với Tin nhắn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Chọn một cuộc trò chuyện bên trái để bắt đầu',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    // Navigator riêng: không có nút back, màn thông tin chat mở ngay trong khung phải.
    return Navigator(
      key: ValueKey(id),
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: id)),
    );
  }

  Widget _list(List<Chat> l, String empty) {
    _prefetchNames(l);
    final q = _q.trim().toLowerCase();
    // Chat chưa biết tên thì tạm giữ lại, có tên rồi mới lọc.
    final shown = q.isEmpty
        ? l
        : l.where((c) {
            final n = svc.chatNameSync(c);
            return n == null || n.toLowerCase().contains(q);
          }).toList();

    if (shown.isEmpty) {
      final msg = q.isEmpty ? empty : 'Không tìm thấy "${_q.trim()}".';
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 48, left: 16, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                q.isEmpty ? Icons.chat_bubble_outline : Icons.search_off,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      // Điện thoại có nút + nổi: chừa chỗ để không che hội thoại cuối
      padding: EdgeInsets.only(bottom: _wide ? 0 : _fabClearance),
      itemCount: shown.length,
      itemBuilder: (c, i) => _ChatTile(
        key: ValueKey(shown[i].id),
        chat: shown[i],
        name: svc.chatNameSync(shown[i]) ?? '',
        selected: _wide && shown[i].id == _selected,
        onOpen: _open,
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final String name;
  final bool selected;
  final void Function(String chatId) onOpen;
  const _ChatTile({
    super.key,
    required this.chat,
    required this.name,
    required this.selected,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final svc = ChatService.I;
    final me = svc.me;
    final unread = chat.unreadFor(me);
    final muted = chat.mutedBy.contains(me);
    final pinned = chat.pinnedBy.contains(me);
    final preview =
        (chat.lastSenderId == me && chat.lastType != 'system' ? 'Bạn: ' : '') +
        chat.lastText;

    return ListTile(
      // Màu mục đang chọn lấy từ listTileTheme (Soft Indigo + chữ Brand Indigo)
      selected: selected,
      leading: ChatAvatar(chat),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            listTime(chat.lastMessageAt),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pinned)
                const Icon(
                  Icons.push_pin,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              if (muted)
                const Icon(
                  Icons.notifications_off,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: muted ? AppColors.textSecondary : AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
      onTap: () => onOpen(chat.id),
      onLongPress: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  pinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(pinned ? 'Bỏ ghim' : 'Ghim lên đầu'),
                onTap: () {
                  Navigator.pop(ctx);
                  svc.setPinned(chat, !pinned);
                },
              ),
              ListTile(
                leading: Icon(
                  muted ? Icons.notifications : Icons.notifications_off,
                ),
                title: Text(muted ? 'Bật thông báo' : 'Tắt thông báo'),
                onTap: () {
                  Navigator.pop(ctx);
                  svc.setMuted(chat, !muted);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
