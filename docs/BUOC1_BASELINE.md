# Weave — Bước 1: Nền tảng kiểm thử và dọn repo

## Cách chạy bộ test rules
Cần Node 20+ và Java 11+ (Emulator chạy bằng Java).

    npm install
    npm run test:rules

Lần đầu `firebase-tools` sẽ tải Firestore Emulator, nên máy cần có mạng.
Lệnh dùng project giả `demo-weave`, không chạm vào dữ liệu thật.

**Trạng thái:** các test này CHƯA được chạy ở môi trường soạn (không có mạng để
tải Emulator). Cú pháp đã kiểm tra, logic đối chiếu thủ công với `firestore.rules`.
Lần chạy đầu có thể có test đỏ: mỗi test đỏ là một trong hai khả năng, test
viết sai hoặc rules có lỗi. Hãy gửi lại kết quả để phân loại.

## Cách áp dụng vào repo
1. Chép `package.json`, `jest.config.js`, `storage.rules`, thư mục `rules_test/`
   và `tools/` vào thư mục gốc dự án.
2. `firebase.json`: bản kèm theo giữ nguyên cấu hình cũ, chỉ thêm `storage` và
   `emulators`. Nên so sánh với bản của bạn trước khi ghi đè.
   Nếu dự án chưa bật Storage trên Console, bỏ khối `"storage"` đi hoặc bật
   Storage trước khi `firebase deploy`.
3. Thêm nội dung `gitignore_additions.txt` vào `.gitignore`, rồi chạy
   `tools/cleanup_repo.sh` (chỉ gỡ khỏi git, không xóa file trên đĩa).
4. Đổi package Android khỏi `com.example.social_app` (làm riêng, cần kiểm tra
   `google-services.json` và cấu hình Firebase đi kèm).

## Phát hiện từ việc đọc rules và mã nguồn

**Đính chính:** tôi từng nói thiếu `storage.rules` làm quyền ảnh không được quản
lý. Thực tế `firebase_storage` không được dùng trong `lib/`. Ảnh được lưu dạng
chuỗi base64 trong Firestore (moments và sources đều giới hạn 400.000 ký tự).
`storage.rules` kèm theo chỉ chặn mọi truy cập vào bucket mặc định.

| # | Phát hiện | Mức | Trạng thái |
|---|---|---|---|
| 1 | `users/{uid}/public/edges` (danh sách bạn) đọc được bởi mọi tài khoản đăng nhập. Constellation dựa vào đây | Cao | Có test `KNOWN GAP` |
| 2 | `mutedUsers`, `favoriteUsers`, `favoriteSpaces`, `restrictedSpaces` nằm trong `users/{uid}`, mà hồ sơ này ai đăng nhập cũng đọc được | Cao | Có test `KNOWN GAP` |
| 3 | Chặn người dùng chỉ có ở phía client: rules không kiểm tra `blocked` khi gửi lời mời kết bạn, đọc bài công khai hay bình luận | Trung bình | Cần quyết định thiết kế |
| 4 | Bộ đếm reactions/comments do client cập nhật (rules chỉ giới hạn ±1) | Thấp | Chấp nhận tạm, chuyển Cloud Functions sau |
| 5 | Bình luận AI (`authorId == 'ai'`) do client gửi nên có thể bị giả | Thấp | Chấp nhận tạm |
| 6 | `friend_posts.audience` và `capsules.audience` là danh sách uid do client gửi, rules không kiểm tra đó là bạn bè | Thấp | Cần quyết định thiết kế |
| 7 | Ảnh base64 trong Firestore: tốn băng thông, khó kiểm soát quyền, trái nguyên tắc Storymaker tham chiếu nguồn | Trung bình | Xử lý ở bước 4 |

Điểm tốt đã xác nhận qua rules: hộp thời gian khóa đúng theo `openAt`, nhóm và
hoạt động chặn thêm người ngoài nhóm, hoạt động đã kết thúc không mở lại,
hồ sơ không tự nâng quyền, liệt kê người dùng bắt buộc `limit ≤ 30`.

## Việc tiếp theo (bước 1b → 2)
- Bạn chạy test và gửi kết quả, mình sửa test hoặc rules cho đến khi xanh.
- Sửa #1 và #2: chuyển các mảng cá nhân sang `users/{uid}/private`, hạn chế
  `public/edges` cho chủ và bạn bè. Việc này cần file `user_prefs.dart`,
  `constellation_service.dart` (đã có trong zip, mình sẽ tự đọc).
- Sau đó sang bước 2: hợp nhất mô hình đối tượng chia sẻ về Layers.
