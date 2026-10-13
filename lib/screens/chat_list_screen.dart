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
  /// Từ chiều rộng này trở lên dùng bố cục 2 cột giống Zalo PC.
  static const double _wideBreakpoint = 900;
  static const double _listWidth = 340;

  final svc = ChatService.I;
  late final Stream<List<Chat>> _stream = svc.myChats();
  bool _searching = false; // chỉ dùng cho điện thoại
  String _q = '';
  String? _selected; // chat đang mở ở khung phải (máy tính)
  int _tab = 0; // 0 = tất cả, 1 = tin chờ (máy tính)

  bool get _wide => MediaQuery.of(context).size.width >= _wideBreakpoint;

  List<Chat> _sort(List<Chat> l, String me) => [
    ...l.where((c) => c.pinnedBy.contains(me)),
    ...l.where((c) => !c.pinnedBy.contains(me)),
  ];

  void _open(String chatId) {
    if (_wide) {
      setState(() => _selected = chatId);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chatId)));
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
    final me = svc.me;
    return StreamBuilder<List<Chat>>(
      stream: _stream,
      builder: (context, snap) {
        final all = (snap.data ?? []).where((c) => c.hasMessages || c.isGroup).toList();
        final requests = all
            .where((c) => !c.isGroup && !c.acceptedBy.contains(me) && c.lastSenderId != me)
            .toList();
        final main = _sort(all.where((c) => !requests.contains(c)).toList(), me);
        return _wide ? _desktop(snap, main, requests) : _mobile(snap, main, requests);
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
              textAlign: TextAlign.center),
        ),
      );
    }
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return child();
  }

  // ───────────── Điện thoại ─────────────
  Widget _mobile(AsyncSnapshot<List<Chat>> snap, List<Chat> main, List<Chat> requests) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Tìm cuộc trò chuyện…', border: InputBorder.none),
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
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                _q = '';
              }),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Tin nhắn'),
              Tab(text: requests.isEmpty ? 'Tin chờ' : 'Tin chờ (${requests.length})'),
            ],
          ),
        ),
        body: _state(
          snap,
              () => TabBarView(children: [
            Column(children: [
              if (!_searching) const FriendsStrip(),
              if (!_searching) const Divider(height: 1),
              Expanded(child: _list(main, 'Chưa có cuộc trò chuyện.\nBấm nút + để bắt đầu.')),
            ]),
            _list(requests, 'Không có tin nhắn chờ.'),
          ]),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _newChat(),
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }

  // ───────────── Máy tính: 2 cột kiểu Zalo ─────────────
  Widget _desktop(AsyncSnapshot<List<Chat>> snap, List<Chat> main, List<Chat> requests) {
    final list = _tab == 0 ? main : requests;
    return Scaffold(
      body: Row(children: [
        SizedBox(
          width: _listWidth,
          child: Column(children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
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
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _tab == 0,
                  onSelected: (_) => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(requests.isEmpty ? 'Tin chờ' : 'Tin chờ (${requests.length})'),
                  selected: _tab == 1,
                  onSelected: (_) => setState(() => _tab = 1),
                ),
              ]),
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
          ]),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _rightPane()),
      ]),
    );
  }

  Widget _rightPane() {
    final id = _selected;
    if (id == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text('Chào mừng đến với Tin nhắn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Chọn một cuộc trò chuyện bên trái để bắt đầu',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    // Navigator riêng: không có nút back, màn thông tin chat mở ngay trong khung phải.
    return Navigator(
      key: ValueKey(id),
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: id)),
    );
  }

  Widget _list(List<Chat> l, String empty) {
    if (l.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 48, left: 16, right: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(empty,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }
    return ListView.builder(
      itemCount: l.length,
      itemBuilder: (c, i) => _ChatTile(
        chat: l[i],
        query: _q,
        selected: _wide && l[i].id == _selected,
        onOpen: _open,
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final String query;
  final bool selected;
  final void Function(String chatId) onOpen;
  const _ChatTile({
    required this.chat,
    required this.query,
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

    return FutureBuilder<String>(
      future: svc.chatName(chat),
      builder: (context, s) {
        final name = s.data ?? '';
        if (query.isNotEmpty && !name.toLowerCase().contains(query.toLowerCase())) {
          return const SizedBox.shrink();
        }
        final preview =
            (chat.lastSenderId == me && chat.lastType != 'system' ? 'Bạn: ' : '') + chat.lastText;
        return ListTile(
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(.1),
          leading: ChatAvatar(chat),
          title: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(listTime(chat.lastMessageAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (pinned) const Icon(Icons.push_pin, size: 14, color: Colors.grey),
                if (muted) const Icon(Icons.notifications_off, size: 14, color: Colors.grey),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: muted ? Colors.grey : Colors.red,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
              ]),
            ],
          ),
          onTap: () => onOpen(chat.id),
          onLongPress: () => showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin),
                  title: Text(pinned ? 'Bỏ ghim' : 'Ghim lên đầu'),
                  onTap: () {
                    Navigator.pop(ctx);
                    svc.setPinned(chat, !pinned);
                  },
                ),
                ListTile(
                  leading: Icon(muted ? Icons.notifications : Icons.notifications_off),
                  title: Text(muted ? 'Bật thông báo' : 'Tắt thông báo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    svc.setMuted(chat, !muted);
                  },
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}