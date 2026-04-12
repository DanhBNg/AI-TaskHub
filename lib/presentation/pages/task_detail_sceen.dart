import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/entities/task_entity.dart';
import '../../../domain/entities/message_entity.dart';
import '../../presentation/state/message_bloc.dart';
import 'package:image_picker/image_picker.dart';

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
    // Vừa vào màn hình là tải tin nhắn của task này ngay
    context.read<MessageBloc>().add(LoadMessages(widget.task.taskId));
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty || currentUser == null) return;

    final newMessage = MessageEntity(
      messageId: '',
      taskId: widget.task.taskId,
      senderId: currentUser!.uid,
      senderName: currentUser!.displayName ?? currentUser!.email!.split('@')[0],
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
        senderId: currentUser!.uid, senderName: currentUser!.displayName ?? 'User',
        content: 'Đã gửi một hình ảnh', timestamp: DateTime.now(),
      );

      // Gửi event lên BLoC kèm theo Mảng Byte
      context.read<MessageBloc>().add(SendMessage(newMessage, imageBytes: imageBytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: Column(
        children: [
          // Phần 1: Thông tin Task
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mô tả công việc:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.task.description.isEmpty ? 'Không có mô tả' : widget.task.description),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(label: Text(widget.task.status)),
                    const SizedBox(width: 8),
                    Chip(label: Text('Độ ưu tiên: ${widget.task.priority}')),
                  ],
                )
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Phần 2: Khu vực hiển thị tin nhắn Chat
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

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blueAccent : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 4),

                              if (msg.imageUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      msg.imageUrl!,
                                      width: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  msg.content,
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),

          // Phần 3: Khung nhập chat (Đã tích hợp Nút chọn ảnh)
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
      ),
    );
  }
}