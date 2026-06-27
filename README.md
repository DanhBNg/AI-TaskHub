# TaskHub AI

TaskHub AI là ứng dụng quản lý dự án công nghệ được phát triển bằng Flutter, hỗ trợ làm việc nhóm thông qua bảng Kanban, thảo luận theo từng công việc và trợ lý AI tích hợp. Ứng dụng hướng đến việc gom các thao tác quản lý dự án, trao đổi công việc, lưu trữ tài liệu và phân tích bằng AI vào cùng một không gian làm việc.

Live demo: https://ai-project-manager-12d8d.web.app/

## Tính Năng Chính

### Quản Lý Dự Án

- Tạo, cập nhật và xóa dự án.
- Mời thành viên tham gia dự án bằng email.
- Phân quyền thành viên theo vai trò `Owner`, `Leader`, `Member`.
- Theo dõi danh sách dự án mà người dùng đang sở hữu hoặc tham gia.

### Bảng Kanban

- Quản lý công việc theo các trạng thái Kanban: `todo`, `in_progress`, `review`, `done`.
- Hỗ trợ kéo thả task giữa các cột để cập nhật trạng thái.
- Mỗi cột có màu nền nhẹ giúp dễ phân biệt trạng thái công việc.
- Tạo, sửa, xóa task và cập nhật thông tin như tiêu đề, mô tả, độ ưu tiên, hạn chót, người được giao.

### Chi Tiết Task Và Cộng Tác

- Xem đầy đủ thông tin chi tiết của từng công việc.
- Thảo luận theo từng task bằng tin nhắn thời gian thực.
- Gửi tin nhắn văn bản và hình ảnh.
- Tải lên, tải xuống và xóa tệp đính kèm qua Firebase Storage.
- Tóm tắt nội dung trao đổi trong task bằng AI.

### Trợ Lý AI

- Trò chuyện với trợ lý AI dựa trên ngữ cảnh dự án và danh sách task hiện có.
- Tóm tắt dữ liệu dự án/task.
- Tìm kiếm task theo tiêu chí như trạng thái, độ ưu tiên, hạn chót hoặc người được giao.
- Sắp xếp các task quan trọng cần ưu tiên xử lý.
- Sinh danh sách task mới bằng AI và cho phép người dùng chọn các task muốn tạo.
- Menu công cụ AI cố định cạnh thanh nhập để truy cập nhanh các hành động thường dùng.

### Xác Thực Và Lưu Phiên

- Đăng ký, đăng nhập bằng Firebase Authentication.
- Lưu phiên đăng nhập để người dùng không phải đăng nhập lại sau khi mở lại ứng dụng.
- Quản lý hồ sơ cá nhân gồm họ tên và ảnh đại diện.

## Công Nghệ Sử Dụng

### Ứng Dụng Người Dùng

- Flutter
- Dart
- BLoC / flutter_bloc
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Hosting cho bản Web

### Backend AI Liên Quan

Ứng dụng Flutter gọi backend Node.js/Express để xử lý các chức năng AI. Backend chịu trách nhiệm bảo vệ API key, xây dựng prompt, gọi Gemini API và chuẩn hóa dữ liệu trước khi trả về ứng dụng.

Repo backend AI: https://github.com/DanhBNg/taskhub-backend

### Web Admin Liên Quan

Hệ thống có thêm giao diện Web Admin dùng để theo dõi dữ liệu tổng quan và hỗ trợ quản trị ở mức hệ thống.

Repo Web Admin: https://github.com/DanhBNg/taskhub-admin

## Cấu Hình Backend AI

Ứng dụng đọc URL backend AI từ biến build-time `AI_BACKEND_URL`.

Chạy local với backend mặc định:

```bash
flutter run -d chrome
```

Chạy local và trỏ đến backend cụ thể:

```bash
flutter run -d chrome --dart-define=AI_BACKEND_URL=http://localhost:3000
```

Build Web với backend deploy:

```bash
flutter build web --release --dart-define=AI_BACKEND_URL=https://your-backend-url.onrender.com
```

## Chạy Dự Án

Cài dependencies:

```bash
flutter pub get
```

Chạy bản Web:

```bash
flutter run -d chrome
```

Chạy kiểm tra static analysis:

```bash
flutter analyze
```

Build bản Web:

```bash
flutter build web --release
```

Deploy Firebase Hosting:

```bash
firebase deploy --only hosting
```

## Cấu Trúc Chính

```text
lib/
  core/
    config/
  data/
    datasources/
    models/
    repositories/
  domain/
    entities/
    repositories/
  presentation/
    pages/
    state/
    theme/
    widgets/
```

Ứng dụng được tổ chức theo hướng tách biệt tầng giao diện, tầng xử lý trạng thái/nghiệp vụ và tầng dữ liệu. Các luồng chính trong giao diện được điều phối qua BLoC, repository và data source để giảm việc gọi trực tiếp Firebase hoặc backend từ UI.


## Tác Giả

Nguyễn Bảo Danh

GitHub: https://github.com/DanhBNg
