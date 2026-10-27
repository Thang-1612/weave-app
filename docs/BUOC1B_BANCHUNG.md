# Bước 1b — Bạn chung và Constellation theo nguyên tắc "cả hai cùng đồng ý"

## Quyết định sản phẩm
- Có "bạn chung": thấy những người vừa là bạn của tôi vừa là bạn của người đang xem.
- Một người chỉ hiện làm bạn chung khi quan hệ giữa họ và người kia là **công khai
  ở cả hai phía** (`visibility = public` của cả hai). Bạn đặt riêng tư thì không
  bao giờ hiện. Mặc định vẫn là riêng tư.
- Constellation giữ độ sâu 2 (bạn của bạn) trên cùng cơ chế đồng thuận này.

## Thiết kế dữ liệu
Thay mảng `users/{uid}/public/edges` bằng **mỗi cạnh một tài liệu**:
`users/{uid}/public_edges/{friendUid}` = `{ friendUid, updatedAt }`.

Rules (`firestore.rules`) thực thi đồng thuận, không còn tin client:

| Thao tác | Điều kiện |
|---|---|
| Tạo/sửa cạnh | Chủ cạnh **hoặc** người bạn trong cạnh; `friendships` phải `accepted` và cả hai phía `public` (dùng `getAfter`, nên hợp lệ khi ghi chung batch với việc đổi visibility) |
| Đọc một cạnh | Kiểm tra lại đồng thuận **ngay lúc đọc** → cạnh sót lại tự vô hiệu khi một bên ẩn hoặc hủy kết bạn |
| Liệt kê cạnh của X | Chỉ X và bạn bè của X. Người lạ chỉ dò được từng cặp, không lấy được cả danh sách |
| Xóa cạnh | Chủ cạnh hoặc người bạn trong cạnh |

Nhờ vậy một thao tác của một bên (ẩn, hủy kết bạn) xóa được **cả hai chiều** trong
một batch, không phụ thuộc vào việc bên kia có mở app hay không. Đây là lỗi thật
của bản cũ: `remove()` chỉ đồng bộ danh sách của người hủy, danh sách của bên kia
vẫn còn tên người vừa hủy cho tới khi họ mở Constellation.

## Cách tính bạn chung (`MutualFriendsService`)
- X là bạn của tôi: một truy vấn liệt kê cạnh của X, giao với danh sách bạn của tôi.
- X là người lạ: kiểm tra từng bạn của tôi bằng `get users/X/public_edges/{bạn}`;
  tối đa 60 bạn, cache 10 phút. Mỗi lượt `get` tốn thêm một lượt đọc để kiểm tra
  đồng thuận, nên **với người lạ chi phí tỉ lệ với số bạn của tôi**.
  Nếu về sau tốn kém, chuyển sang Cloud Functions tính sẵn.
- Bạn bị tôi chặn không được tính.

## File trong gói (chép đè vào dự án, giữ nguyên đường dẫn)
- `firestore.rules`
- `lib/services/friend_service.dart` (`setVisibility`, `remove`, `syncPublicEdges` viết lại)
- `lib/services/constellation_service.dart` (đọc `public_edges`, kiểm tra hai chiều bằng `get`)
- `lib/services/mutual_friends_service.dart` (mới)
- `lib/widgets/mutual_friends_row.dart` (mới)
- `lib/screens/user_profile_page.dart` (thêm dòng "Bạn chung" trên hồ sơ người khác)
- `rules_test/public_edges.test.js` (mới), `rules_test/friends_users.test.js` (cập nhật)

## Việc cần làm theo thứ tự
1. Chép file, chạy `npm run test:rules`. Dự kiến mọi test xanh; test đỏ nào cũng
   gửi lại để phân loại.
2. Chạy `flutter analyze`. **Phần Dart chưa được biên dịch** (môi trường soạn không
   có Flutter SDK); tôi chỉ đối chiếu thủ công với mã hiện có.
3. Thử tay trên hai tài khoản trở lên: A–B bạn bè, cả hai bật "công khai" trong
   Constellation → hồ sơ của B hiện cạnh với bạn chung; B chuyển ẩn → biến mất
   ngay ở phía A; hủy kết bạn → cả hai chiều biến mất.
4. Triển khai rules sau khi app mới đã được cài. Dữ liệu cũ `public/edges` được
   app tự xóa khi mở Constellation; rules mới cho chủ đọc/xóa nhưng không ghi mới.

## Giới hạn còn lại
- Cạnh chỉ bị xóa chủ động bởi client; rules chặn *đọc* cạnh hết hiệu lực, nhưng
  truy vấn liệt kê của bạn bè vẫn có thể trả về tên cạnh sót lại (Constellation
  và bạn chung đều kiểm tra lại từng cạnh bằng `get` nên không hiển thị).
  Triệt để hơn cần Cloud Functions.
- Người lạ vẫn có thể hỏi riêng "A có công khai là bạn của B không" nếu đoán được
  uid của cả hai. Đó là thông tin cả hai đã đồng ý công khai.
