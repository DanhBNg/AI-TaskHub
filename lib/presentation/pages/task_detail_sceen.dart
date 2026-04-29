import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/entities/task_entity.dart';
import '../../../domain/entities/message_entity.dart';
import '../../presentation/state/message_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../state/task_bloc.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskEntity task;
  final int initialTabIndex;
  const TaskDetailScreen({super.key, required this.task, this.initialTabIndex = 0,});

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
    final content = _chatController.text.trim();
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
    FirebaseFirestore.instance.collection('TASKS').doc(widget.task.taskId).update({
      'lastMessage': content,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }).catchError((e) => print(e));
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
      FirebaseFirestore.instance.collection('TASKS').doc(widget.task.taskId).update({
        'lastMessage': 'Đã gửi một hình ảnh',
        'lastMessageTime': FieldValue.serverTimestamp(),
      }).catchError((e) => print(e));
    }
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
        return 'Cần làm';
      case 'in_progress':
        return 'Đang làm';
      case 'review':
        return 'Chờ duyệt';
      case 'done':
        return 'Hoàn thành';
      default:
        return status;
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

    String rawPriority = widget.task.priority.trim();
    if (rawPriority.isNotEmpty) rawPriority = '${rawPriority[0].toUpperCase()}${rawPriority.substring(1).toLowerCase()}';
    String selectedPriority = ['Low', 'Medium', 'High'].contains(rawPriority) ? rawPriority : 'Medium';

    // Copy dữ liệu cũ để người dùng sửa đổi
    DateTime? editDueDate = widget.task.dueDate;
    List<String> editAssigneeIds = List.from(widget.task.assigneeIds);
    List<String> editAssigneeNames = List.from(widget.task.assigneeNames);
    List<String> editAssigneeAvatars = List.from(widget.task.assigneeAvatarUrls);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // StatefulBuilder giúp form cập nhật được Ngày và Người ngay lập tức khi chọn
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Chỉnh sửa công việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(controller: editTitleController, decoration: const InputDecoration(labelText: 'Tên Task', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextField(controller: editDescController, maxLines: 2, decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder())),
                      const SizedBox(height: 16),

                      // Sửa Deadline
                      TextFormField(
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: editDueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2030));
                          if (picked != null) setModalState(() => editDueDate = picked);
                        },
                        decoration: const InputDecoration(labelText: 'Deadline', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                        controller: TextEditingController(text: editDueDate == null ? '' : '${editDueDate!.day}/${editDueDate!.month}/${editDueDate!.year}'),
                      ),
                      const SizedBox(height: 16),

                      // Sửa Độ ưu tiên
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: const InputDecoration(labelText: 'Độ ưu tiên', border: OutlineInputBorder()),
                        items: ['Low', 'Medium', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (val) => setModalState(() => selectedPriority = val!),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Người thực hiện:', style: TextStyle(fontWeight: FontWeight.bold))
                      ),
                      const SizedBox(height: 8),
                      // Gọi hàm vẽ Checkbox chọn người
                      _buildMemberSelector(editAssigneeIds, editAssigneeNames, editAssigneeAvatars, setModalState),
                      const SizedBox(height: 24),
                      // Nút Lưu thay đổi
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            final updatedTask = TaskEntity(
                              taskId: widget.task.taskId,
                              projectId: widget.task.projectId,
                              title: editTitleController.text.trim(),
                              description: editDescController.text.trim(),
                              status: widget.task.status,
                              priority: selectedPriority,
                              dueDate: editDueDate,
                              assigneeIds: editAssigneeIds,
                              assigneeNames: editAssigneeNames,
                              assigneeAvatarUrls: editAssigneeAvatars,
                              createdAt: widget.task.createdAt,
                            );
                            context.read<TaskBloc>().add(UpdateTask(updatedTask));
                            Navigator.pop(context); // Đóng form
                            Navigator.pop(context); // Quay về bảng Kanban
                          },
                          child: const Text('Lưu Thay Đổi', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  bool _isSummarizing = false;

  Future<void> _summarizeChat(List<MessageEntity> messages) async {
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có tin nhắn nào để tóm tắt')));
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      // Nhặt tên người gửi và nội dung để ném cho Node.js
      final chatData = messages.map((m) => {
        'sender': m.senderName,
        'content': m.content
      }).toList();

      final response = await http.post(
        Uri.parse('https://taskhub-backend-ords.onrender.com/api/summarize-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': chatData}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showSummaryDialog(data['summary']);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Lỗi không xác định từ Server');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi gọi AI: $e')));
      }
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  void _showSummaryDialog(String summary) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple),
              SizedBox(width: 8),
              Text('Tóm tắt Chat', style: TextStyle(color: Colors.purple)),
            ],
          ),
          // Dùng SingleChildScrollView để đoạn tóm tắt dài không bị tràn màn hình
          content: SingleChildScrollView(child: Text(summary, style: const TextStyle(fontSize: 15, height: 1.5))),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  Future<void> _deleteFile(Map<String, dynamic> fileData) async {
    try {
      final String fileUrl = fileData['url'];
      final String fileName = fileData['name'];

      // 1. Xóa file khỏi Firebase Storage
      final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
      await storageRef.delete();

      // 2. Xóa thông tin file khỏi mảng 'attachments' trong Firestore
      await FirebaseFirestore.instance.collection('TASKS').doc(widget.task.taskId).update({
        'attachments': FieldValue.arrayRemove([fileData])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa tệp: $fileName'), backgroundColor: Colors.orange)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa tệp: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bao bọc toàn bộ Scaffold bằng DefaultTabController
    return DefaultTabController(
      initialIndex: widget.initialTabIndex,
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
              Chip(label: Text(_translateStatus(widget.task.status), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.blueAccent),
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
            subtitle: Text(widget.task.assigneeNames.join(', ')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.calendar_today, color: Colors.white)),
            title: const Text('Hạn chót (Deadline)'),
            subtitle: Text(widget.task.dueDate != null ? widget.task.dueDate.toString() : 'Chưa đặt ngày'),
          ),

          const Divider(height: 40),

          // Nút thao tác
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('PROJECTS').doc(widget.task.projectId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final String ownerId = data['ownerId'] ?? '';
              final Map<String, dynamic> roles = data['roles'] ?? {};
              final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

              // Kiểm tra quyền (Owner hoặc Admin)
              final bool hasPermission = (currentUid == ownerId) || (roles[currentUid] == 'Admin');

              if (!hasPermission) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200)
                  ),
                  child: const Text(
                    '🔒 Chỉ Chủ dự án và Quản trị viên mới có quyền Sửa hoặc Xóa công việc này.',
                    style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      label: const Text('Chỉnh sửa'),
                      onPressed: _showEditTaskModal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Xóa Task', style: TextStyle(color: Colors.white)),
                      onPressed: _deleteTask,
                    ),
                  ),
                ],
              );
            },
          )
        ],
      ),
    );
  }

  // ================= TAB 2: THẢO LUẬN (CHAT) =================
  Widget _buildChatTab() {
    return Column(
      children: [
        BlocBuilder<MessageBloc, MessageState>(
            builder: (context, state) {
              List<MessageEntity> currentMessages = [];
              if (state is MessageLoaded) {
                currentMessages = state.messages;
              }

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      elevation: 0,
                      side: BorderSide(color: Colors.purple.shade200),
                    ),
                    icon: _isSummarizing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple))
                        : const Icon(Icons.auto_awesome, color: Colors.purple),
                    label: Text(
                        _isSummarizing ? 'AI đang đọc tin nhắn...' : 'Tóm tắt nội dung Chat',
                        style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)
                    ),
                    onPressed: _isSummarizing ? null : () => _summarizeChat(currentMessages),
                  ),
                ),
              );
            }
        ),
        Expanded(
          child: BlocBuilder<MessageBloc, MessageState>(
            builder: (context, state) {
              if (state is MessageLoading) return const Center(child: CircularProgressIndicator());

              // THÊM DÒNG NÀY ĐỂ BẮT LỖI
              if (state is MessageError) return Center(child: Text('Lỗi: ${state.error}', style: const TextStyle(color: Colors.red)));
              if (state is MessageLoaded) {
                // 1. Đảo ngược danh sách tin nhắn để cái mới nhất nằm ở vị trí đầu tiên
                final reversedMessages = state.messages.reversed.toList();

                return ListView.builder(
                  reverse: true, // 2. QUAN TRỌNG: Lật ngược danh sách từ dưới lên trên
                  padding: const EdgeInsets.all(16),
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, index) {
                    // 3. Sử dụng danh sách đã đảo ngược
                    final msg = reversedMessages[index];
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
                                  // Tên người gửi
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

  // Hàm xử lý upload file
  Future<void> _uploadFile() async {
    // 1. Dùng withData: true để Web có thể đọc được fileBytes
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    final fileName = result.files.first.name;

    if (fileBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể đọc dữ liệu tệp!')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang tải "$fileName" lên...')));
    }

    try {
      // 2. Upload lên Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('task_attachments/${widget.task.taskId}/$fileName');

      // Khai báo ContentType rỗng để Firebase tự động nhận diện (Word, Excel, PDF...)
      await storageRef.putData(fileBytes, SettableMetadata(contentType: 'application/octet-stream'));
      final downloadUrl = await storageRef.getDownloadURL();

      // 3. Cập nhật thẳng vào mảng 'attachments' của Task trên Firestore
      await FirebaseFirestore.instance.collection('TASKS').doc(widget.task.taskId).update({
        'attachments': FieldValue.arrayUnion([
          {'name': fileName, 'url': downloadUrl}
        ])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải tệp thành công!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải tệp: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ================= TAB 3: ĐÍNH KÈM FILE =================
  // ================= TAB 3: ĐÍNH KÈM FILE =================
  Widget _buildAttachmentsTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            // Đọc real-time Document của Task này để lấy mảng file
            stream: FirebaseFirestore.instance.collection('TASKS').doc(widget.task.taskId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final List<dynamic> attachments = data['attachments'] ?? [];

              if (attachments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.folder_open, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Chưa có tệp nào được đính kèm', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              // Vẽ danh sách file
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  final file = attachments[index] as Map<String, dynamic>;
                  final urlString = file['url'];

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        if (urlString == null || urlString.isEmpty) return;
                        final Uri url = Uri.parse(urlString);

                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, webOnlyWindowName: '_blank');
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở tệp')));
                        }
                      },
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file, color: Colors.blueAccent, size: 32),
                        title: Text(file['name'] ?? 'Tệp không tên', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Nhấn để xem tệp ở tab mới'),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Tải xuống',
                              icon: const Icon(Icons.download, color: Colors.blue),
                              onPressed: () async {
                                if (urlString == null || urlString.isEmpty) return;
                                final Uri url = Uri.parse(urlString);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),

                            // Nút Xóa
                            IconButton(
                              tooltip: 'Xóa tệp',
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Xác nhận xóa'),
                                    content: Text('Bạn có chắc chắn muốn xóa tệp "${file['name']}" không?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteFile(file); // Gọi hàm xóa mà chúng ta đã viết trước đó
                                        },
                                        child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Nút Tải lên
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: const Icon(Icons.upload_file),
            label: const Text('Tải tệp mới lên', style: TextStyle(fontSize: 16)),
            onPressed: _uploadFile,
          ),
        )
      ],
    );
  }

  // Hàm hiển thị danh sách chọn người trong Modal
  Widget _buildMemberSelector(List<String> ids, List<String> names, List<String> avatars, StateSetter setModalState) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('PROJECTS').doc(widget.task.projectId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        List<dynamic> memberIds = snapshot.data!.get('memberIds') ?? [];
        if (memberIds.isEmpty) return const Text('Dự án chưa có thành viên.');

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('USERS').where(FieldPath.documentId, whereIn: memberIds).snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) return const SizedBox();

            return Column(
              children: userSnap.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final uid = doc.id;
                final name = data['fullName'] ?? data['email'].split('@')[0];
                final avatar = data['avatarUrl'];
                final isSelected = ids.contains(uid);

                return CheckboxListTile(
                  value: isSelected,
                  title: Text(name),
                  secondary: CircleAvatar(
                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null ? Text(name[0].toUpperCase()) : null,
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      if (val == true) {
                        ids.add(uid); names.add(name); avatars.add(avatar ?? '');
                      } else {
                        int i = ids.indexOf(uid);
                        ids.removeAt(i); names.removeAt(i); avatars.removeAt(i);
                      }
                    });
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}