# TaskHub AI 🚀

TaskHub AI là một ứng dụng quản lý dự án và công việc đa nền tảng (Mobile & Web), được thiết kế để tối ưu hóa hiệu suất làm việc nhóm thông qua bảng Kanban trực quan và sức mạnh của Trí tuệ nhân tạo (Google Gemini).

🔗 **Live Demo:** [https://ai-project-manager-12d8d.web.app/]

## ✨ Tính năng nổi bật

### 🧠 Tích hợp AI (Google Gemini)
* **AI Task Generator:** Tự động phân tích yêu cầu (prompt) và chia nhỏ thành các thẻ công việc (Task) chi tiết.
* **Smart Chat Summarize:** Tóm tắt nhanh tin nhắn thảo luận trong Task chỉ với 1 click, giúp nắm bắt ngữ cảnh tức thì.

### 📊 Quản lý công việc (Kanban Board)
* Giao diện Kanban trực quan với 4 cột trạng thái chuẩn Agile: `Cần làm`, `Đang làm`, `Chờ duyệt`, `Hoàn thành`.
* Tính năng Kéo - Thả (Drag & Drop) mượt mà tích hợp thuật toán tự động cuộn (Auto-scroll) khi thẻ chạm mép màn hình.
* Quản lý chi tiết công việc: Deadline, Độ ưu tiên, và Phân công người thực hiện.

### 👥 Thảo luận & Cộng tác (Real-time)
* Khung chat thời gian thực (Real-time) ngay bên trong từng Task.
* Hỗ trợ gửi tin nhắn văn bản và hình ảnh.
* Đính kèm, xem trước và tải xuống các tệp tài liệu (PDF, Word, Excel...) an toàn qua Firebase Storage.

### 🛡️ Phân quyền bảo mật (RBAC)
* Hệ thống phân quyền chặt chẽ với 3 cấp độ: Chủ dự án (Owner), Quản trị viên (Admin), và Thành viên (Member).

## 🛠️ Công nghệ sử dụng

**Frontend (Client):**
* Framework: [Flutter](https://flutter.dev/) (Hỗ trợ Android, iOS & Web)
* Ngôn ngữ: Dart
* State Management: BLoC Pattern (flutter_bloc)

**Backend (API Server):**
* Runtime: [Node.js](https://nodejs.org/)
* Framework: Express.js
* AI Integration: Google Gemini API (genai-sdk)

**Database & Dịch vụ đám mây:**
* Cơ sở dữ liệu: Firebase Firestore (NoSQL)
* Lưu trữ tệp: Firebase Storage
* Xác thực: Firebase Authentication
* Hosting (Frontend): Firebase Hosting
* Hosting (Backend): Render.com

👨‍💻 Tác giả
Nguyễn Bảo Danh - [https://github.com/DanhBNg]
