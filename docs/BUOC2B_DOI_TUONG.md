# Bước 2b — Một nguồn duy nhất cho "ai được xem" (tầng giao diện)

## Đã làm
- `lib/widgets/audience_meta.dart` (mới): nhãn, biểu tượng, mô tả của cả 5 loại
  đối tượng (public, friends, close, group, me) và **một** bảng chọn dùng chung
  `showAudienceTypeSheet`.
- `audience_picker.dart`: còn ~20 dòng, gọi bảng chọn chung với 3 mức dành cho
  bài viết. Vẫn xuất `audienceIcon / audienceLabel / audienceHint`, nên các file
  đang import nó không phải sửa.
- `layer_audience_picker.dart`: dùng cùng bảng chọn với 5 mức; bỏ bản sao nhãn/mô tả.
- `layer_tab_bar.dart`: `layerAudienceIcon/Label` thành bí danh một dòng.

Hành vi giữ nguyên. Khác biệt duy nhất người dùng có thể thấy: mô tả ngắn của
"Bạn bè", "Chỉ mình tôi", "Công khai" trong bảng chọn **lớp** nay dùng cùng câu chữ
với bảng chọn **bài viết**.

## Cố ý không làm: cho bài viết chọn "Bạn thân" / "Nhóm" làm đối tượng gốc
Bài `friend_posts` lưu ảnh chụp `audience`. Thêm hai loại này nghĩa là phải giữ
ảnh chụp đồng bộ khi danh sách bạn thân hoặc thành viên nhóm đổi, tức mở thêm hai
khoảng hở thu hồi quyền như đã sửa ở bước 2a, trên gói Spark chưa có cách chặn
tận gốc. Hiện người dùng đã đạt cùng kết quả bằng Layers: bài gốc "Chỉ mình tôi"
cộng một lớp "Bạn thân" hoặc "Nhóm riêng", và các lớp được rules kiểm tra trực
tiếp. Việc cần làm ở UI là giúp người dùng thấy lối này (gợi ý trong màn đăng bài),
để bước sau xem xét cùng màn hình đăng bài.

## File (chép đè, giữ đường dẫn)
- `lib/widgets/audience_meta.dart` (mới)
- `lib/widgets/audience_picker.dart`
- `lib/widgets/layer_audience_picker.dart`
- `lib/widgets/layer_tab_bar.dart`

## Kiểm tra
`flutter analyze`, rồi mở thử: bảng chọn đối tượng khi đăng bài (3 mức), khi đổi
đối tượng bài, khi đăng từ Story, và khi chọn đối tượng cho một lớp (5 mức, chọn
"Nhóm riêng" mở tiếp bảng chọn nhóm).
