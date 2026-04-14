import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/entities/task_entity.dart';
import '../../../domain/entities/message_entity.dart';
import '../../presentation/state/message_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../state/task_bloc.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskEntity task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _chatController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    context.read<MessageBloc>().add(LoadMessages(widget.task.taskId));
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty || currentUser == null) return;

    final newMessage = MessageEntity(
      messageId: '',
      taskId: widget.task.taskId,
      senderId: currentUser!.uid,
      senderName: currentUser!.displayName ?? currentUser!.email!.split('@')[0],
      senderAvatarUrl: currentUser!.photoURL,
      content: _chatController.text.trim(),
      timestamp: DateTime.now(),
    );

    context.read<MessageBloc>().add(SendMessage(newMessage));
    _chatController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null && currentUser != null) {
      // ĐỌC ẢNH DƯỚI DẠNG MẢNG BYTE
      final imageBytes = await pickedFile.readAsBytes();

      final newMessage = MessageEntity(
        messageId: '', taskId: widget.task.taskId,
        senderId: currentUser!.uid,
        senderName: currentUser!.displayName ?? currentUser!.email!.split('@')[0],
        senderAvatarUrl: currentUser!.photoURL,
        content: 'Đã gửi một hình ảnh', timestamp: DateTime.now(),
      );

      // Gửi event lên BLoC kèm theo Mảng Byte
      context.read<MessageBloc>().add(SendMessage(newMessage, imageBytes: imageBytes));
    }
  }

  void _deleteTask() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: const Text('Bạn có chắc chắn muốn xóa Task này không? Mọi dữ liệu (bao gồm cả chat) sẽ bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Gọi Event Xóa
              context.read<TaskBloc>().add(DeleteTask(widget.task.taskId));
              Navigator.pop(ctx); // Đóng Dialog
              Navigator.pop(context); // Thoát khỏi màn hình Detail về bảng Kanban
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditTaskModal() {
    final editTitleController = TextEditingController(text: widget.task.title);
    final editDescController = TextEditingController(text: widget.task.description);
    final validPriorities = ['Low', 'Medium', 'High'];
    String rawPriority = widget.task.priority.trim();

    if (rawPriority.isNotEmpty) {
      rawPriority = '${rawPriority[0].toUpperCase()}${rawPriority.substring(1).toLowerCase()}';
    }
    String selectedPriority = validPriorities.contains(rawPriority) ? rawPriority : 'Medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép bottom sheet bung to lên
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Không bị bàn phím che
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chỉnh sửa công việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: editTitleController, decoration: const InputDecoration(labelText: 'Tên Task')),
              const SizedBox(height: 16),
              TextField(controller: editDescController, decoration: const InputDecoration(labelText: 'Mô tả')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                items: ['Low', 'Medium', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => selectedPriority = val!,
                decoration: const InputDecoration(labelText: 'Độ ưu tiên'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Tạo một TaskEntity mới mang ID cũ nhưng nội dung mới
                    final updatedTask = TaskEntity(
                      taskId: widget.task.taskId,
                      projectId: widget.task.projectId,
                      title: editTitleController.text.trim(),
                      description: editDescController.text.trim(),
                      status: widget.task.status,
                      priority: selectedPriority,
                      dueDate: widget.task.dueDate,
                      assigneeId: widget.task.assigneeId,
                      assigneeName: widget.task.assigneeName,
                      assigneeAvatarUrl: widget.task.assigneeAvatarUrl,
                      createdAt: widget.task.createdAt,
                    );
                    context.read<TaskBloc>().add(UpdateTask(updatedTask));
                    Navigator.pop(context); // Đóng form
                    Navigator.pop(context); // Tạm thời pop về Kanban để nó load lại data mới
                  },
                  child: const Text('Lưu Thay Đổi'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bao bọc toàn bộ Scaffold bằng DefaultTabController
    return DefaultTabController(
      length: 3, // Khai báo có 3 Tab
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.task.title),
          // THANH ĐIỀU HƯỚNG TABS
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Chi tiết'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Thảo luận'),
              Tab(icon: Icon(Icons.attach_file), text: 'Đính kèm'),
            ],
          ),
        ),
        // NỘI DUNG TƯƠNG ỨNG CHO 3 TABS
        body: TabBarView(
          children: [
            _buildDetailsTab(),       // Tab 1
            _buildChatTab(),          // Tab 2
            _buildAttachmentsTab(),   // Tab 3
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: CHI TIẾT TASK =================
  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trạng thái và Ưu tiên
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(label: Text(widget.task.status, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.blueAccent),
              Chip(label: Text('Ưu tiên: ${widget.task.priority}')),
            ],
          ),
          const SizedBox(height: 16),

          // Mô tả
          const Text('Mô tả công việc:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text(widget.task.description.isEmpty ? 'Chưa có mô tả' : widget.task.description),
          ),
          const SizedBox(height: 24),

          // Thông tin người nhận và Deadline (Giao diện chuẩn bị sẵn cho DB mới)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('Người thực hiện'),
            subtitle: Text(widget.task.assigneeName ?? 'Chưa phân công'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.calendar_today, color: Colors.white)),
            title: const Text('Hạn chót (Deadline)'),
            subtitle: Text(widget.task.dueDate != null ? widget.task.dueDate.toString() : 'Chưa đặt ngày'),
          ),

          const Divider(height: 40),

          // Nút thao tác
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit, color: Colors.blue), label: const Text('Chỉnh sửa'),
                  onPressed: _showEditTaskModal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete, color: Colors.white), label: const Text('Xóa Task', style: TextStyle(color: Colors.white)),
                  onPressed: _deleteTask,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ================= TAB 2: THẢO LUẬN (CHAT) =================
  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<MessageBloc, MessageState>(
            builder: (context, state) {
              if (state is MessageLoading) return const Center(child: CircularProgressIndicator());

              // THÊM DÒNG NÀY ĐỂ BẮT LỖI
              if (state is MessageError) return Center(child: Text('Lỗi: ${state.error}', style: const TextStyle(color: Colors.red)));
              if (state is MessageLoaded) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final msg = state.messages[index];
                    final isMe = msg.senderId == currentUser?.uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // NẾU LÀ NGƯỜI KHÁC -> HIỆN AVATAR BÊN TRÁI
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              backgroundImage: msg.senderAvatarUrl != null ? NetworkImage(msg.senderAvatarUrl!) : null,
                              child: msg.senderAvatarUrl == null
                                  ? Text(msg.senderName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                          ],

                          // KHUNG TIN NHẮN (BONG BÓNG)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blueAccent : Colors.grey.shade200,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tên người gửi (Chỉ hiện nếu không phải là mình)
                                  if (!isMe) ...[
                                    Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54)),
                                    const SizedBox(height: 4),
                                  ],

                                  // Nội dung: Ảnh hoặc Chữ
                                  if (msg.imageUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(msg.imageUrl!, width: 200, fit: BoxFit.cover),
                                    )
                                  else
                                    Text(
                                      msg.content,
                                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // hiện avt chính mình
                          // if (isMe) ...[
                          //   const SizedBox(width: 8),
                          //   CircleAvatar(
                          //     radius: 16,
                          //     backgroundColor: Colors.white,
                          //     backgroundImage: msg.senderAvatarUrl != null ? NetworkImage(msg.senderAvatarUrl!) : null,
                          //     child: msg.senderAvatarUrl == null
                          //         ? Text(msg.senderName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))
                          //         : null,
                          //   ),
                          // ],
                        ],
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ),
        // Khung nhập chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)]),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image, color: Colors.blue),
                onPressed: _pickAndSendImage,
              ),
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blueAccent),
                onPressed: _sendMessage,
              )
            ],
          ),
        )
      ],
    );
  }

  // ================= TAB 3: ĐÍNH KÈM FILE =================
  Widget _buildAttachmentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Chưa có tệp nào được đính kèm', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Tải tệp lên'),
            onPressed: () {
              // Xử lý up file document, pdf, v.v. (Tương tự up ảnh)
            },
          )
        ],
      ),
    );
  }
}