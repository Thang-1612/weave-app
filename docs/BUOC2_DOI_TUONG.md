# Bước 2 — Mô hình đối tượng chia sẻ ("ai được xem")

## Đính chính giả thuyết ở bước trước
Tôi từng nghi `closeFriends`, `groups` và Spaces là các hệ thống đối tượng chạy song song với Layers. Sau khi đọc mã:

| Thành phần | Thực chất | Kết luận |
|---|---|---|
| `closeFriends` | Đối tượng loại `close` của Layers | Không trùng lặp |
| `groups` | Đối tượng loại `group` của Layers (và nền của Together) | Không trùng lặp |
| Spaces (`space.dart`) | **Chủ đề** của bài (học tập, ngoại ngữ...), không liên quan quyền xem | Tôi đã nhầm, bỏ khỏi phạm vi |

## Sự trùng lặp thật sự
Có **hai cách tính quyền xem** cho cùng một khái niệm:

| | Bài viết (`posts` / `friend_posts`) | Lớp (`posts/{id}/layers`) |
|---|---|---|
| Mức đối tượng | public, friends, me (3 mức) | public, friends, close, group, me (5 mức) |
| Cách tính | **Ảnh chụp**: mảng `audience` (≤ 500 uid) lưu trong bài | **Trực tiếp**: rules kiểm tra `friendships`, `closeFriends`, `groups` lúc đọc |
| Giao diện chọn | `audience_picker.dart` | `layer_audience_picker.dart` |
| Cập nhật khi quan hệ đổi | `FriendPostSync` ghi lại **mọi** bài khi danh sách bạn đổi, chỉ chạy khi app của tác giả đang mở | Tự đúng |

Hộp thời gian (`capsules`) cũng dùng ảnh chụp `audience`, bất biến sau khi tạo.

## Lỗi thật tìm thấy: quyền xem không bị thu hồi ngay khi hủy kết bạn
Bài `friend_posts` cho đọc nếu uid nằm trong `audience`. Khi A hủy kết bạn với B, B vẫn nằm trong `audience` các bài chỉ-bạn-bè của A **cho tới khi app của A chạy `FriendPostSync` lần kế tiếp**. Nếu B là người hủy thì khoảng hở còn dài hơn, vì máy của A không biết gì. Trong lúc đó B vẫn đọc được bài riêng của A.

Không thể sửa bằng cách kiểm tra bạn bè lúc đọc, vì truy vấn feed
(`where audience array-contains`) không cho rules gọi `get()` theo dữ liệu từng
bài. Cách khả thi trên gói Spark (không Cloud Functions):

**Bước 2a — đã làm trong gói này**
- Rules: người xem được **tự rút mình** khỏi `audience` (chỉ bỏ đúng chính mình, không thêm ai, không đổi trường khác).
- `FriendService.remove()`: khi hủy một quan hệ bạn bè đã `accepted`, ngay trong thao tác đó gỡ hai bên khỏi `audience` bài của nhau. Dùng hai truy vấn chỉ mục đơn trường (`authorId ==`, `audience array-contains`), lọc phần còn lại ở client, nên không cần tạo chỉ mục mới.
- Chặn người dùng (`UserPrefs.block`) gọi `remove()` nên được bảo vệ luôn.
- `FriendPostSync` giữ vai trò lưới an toàn nếu thao tác trên bị ngắt giữa chừng.

Giới hạn: vẫn do client thực hiện. Nếu mất mạng đúng lúc hủy kết bạn, khoảng hở quay lại cho tới lần đồng bộ sau. Chặn hẳn cần Cloud Functions (gói Blaze).

## Kế hoạch tiếp theo
**2b — Một "Audience" duy nhất ở tầng mã (không đổi dữ liệu)**
- Một lớp `Audience` (type + groupId) dùng chung cho bài, lớp, hộp thời gian; nhãn, biểu tượng, mô tả nằm một chỗ.
- `audience_picker` trở thành vỏ mỏng gọi `layer_audience_picker` (cho phép chọn bạn thân/nhóm ngay lúc đăng bài, thay vì chỉ 3 mức).
- Việc này chạm UI nhiều nơi: cần xem `create_post_screen.dart` và nơi gọi `showAudiencePicker` trước khi sửa.

**2c — Có nên chuyển bài chỉ-bạn-bè sang tính trực tiếp?**
Không khả thi trên Spark vì giới hạn truy vấn nói trên. Khuyến nghị giữ ảnh chụp +
thu hồi chủ động (2a), và chỉ chuyển sang Cloud Functions khi nâng lên Blaze.

## File trong gói (chép đè, giữ đường dẫn)
- `firestore.rules` (dựa trên bản bước 1b)
- `lib/services/friend_service.dart` (dựa trên bản bước 1b)
- `rules_test/friend_posts_revoke.test.js` (mới)

## Kiểm tra
1. `npm run test:rules` và `flutter analyze`.
2. Thử tay: A đăng bài "Bạn bè", B xem được → A (hoặc B) hủy kết bạn → B hết xem được ngay, không cần mở lại app của A.
