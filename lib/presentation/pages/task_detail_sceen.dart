import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/project_role_utils.dart';
import '../../../domain/entities/task_entity.dart';
import '../../../domain/entities/message_entity.dart';
import '../../presentation/state/ai_assistant_bloc.dart';
import '../../presentation/state/attachment_bloc.dart';
import '../../presentation/state/message_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../state/task_bloc.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_assistant_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskEntity task;
  final int initialTabIndex;
  const TaskDetailScreen({
    super.key,
    required this.task,
    this.initialTabIndex = 0,
  });

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
    context.read<AttachmentBloc>().add(LoadAttachments(widget.task.taskId));
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
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null && currentUser != null) {
      final imageBytes = await pickedFile.readAsBytes();

      final newMessage = MessageEntity(
        messageId: '',
        taskId: widget.task.taskId,
        senderId: currentUser!.uid,
        senderName:
            currentUser!.displayName ?? currentUser!.email!.split('@')[0],
        senderAvatarUrl: currentUser!.photoURL,
        content: 'Đã gửi một hình ảnh',
        timestamp: DateTime.now(),
      );

      final messageBloc = context.read<MessageBloc>();
      messageBloc.add(SendMessage(newMessage, imageBytes: imageBytes));
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

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  void _deleteTask() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa Task này không? Mọi dữ liệu (bao gồm cả chat) sẽ bị mất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<TaskBloc>().add(DeleteTask(widget.task.taskId));
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditTaskModal() {
    final editTitleController = TextEditingController(text: widget.task.title);
    final editDescController = TextEditingController(
      text: widget.task.description,
    );

    String rawPriority = widget.task.priority.trim();
    if (rawPriority.isNotEmpty)
      rawPriority =
          '${rawPriority[0].toUpperCase()}${rawPriority.substring(1).toLowerCase()}';
    String selectedPriority = ['Low', 'Medium', 'High'].contains(rawPriority)
        ? rawPriority
        : 'Medium';

    // Copy dữ liệu cũ để người dùng sửa đổi
    DateTime? editDueDate = widget.task.dueDate;
    List<String> editAssigneeIds = List.from(widget.task.assigneeIds);
    List<String> editAssigneeNames = List.from(widget.task.assigneeNames);
    List<String> editAssigneeAvatars = List.from(
      widget.task.assigneeAvatarUrls,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Chỉnh sửa công việc',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Tên Task',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editDescController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sửa Deadline
                      TextFormField(
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: editDueDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setModalState(() => editDueDate = picked);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Deadline',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: editDueDate == null
                              ? ''
                              : '${editDueDate!.day}/${editDueDate!.month}/${editDueDate!.year}',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sửa Độ ưu tiên
                      DropdownButtonFormField<String>(
                        initialValue: selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Độ ưu tiên',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Low', 'Medium', 'High']
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedPriority = val!),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Người thực hiện:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMemberSelector(
                        editAssigneeIds,
                        editAssigneeNames,
                        editAssigneeAvatars,
                        setModalState,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
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
                            context.read<TaskBloc>().add(
                              UpdateTask(updatedTask),
                            );
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Lưu Thay Đổi',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAssistantWithTaskContext(List<MessageEntity> messages) {
    final assistantContext = {
      'source': 'task_detail',
      'task': {
        'taskId': widget.task.taskId,
        'projectId': widget.task.projectId,
        'title': widget.task.title,
        'description': widget.task.description,
        'status': widget.task.status,
        'priority': widget.task.priority,
        'dueDate': widget.task.dueDate?.toIso8601String(),
        'assigneeNames': widget.task.assigneeNames,
      },
      'messages': messages
          .map(
            (m) => {
              'sender': m.senderName,
              'content': m.content,
              'timestamp': m.timestamp.toIso8601String(),
            },
          )
          .toList(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiAssistantScreen(
          projectId: widget.task.projectId,
          initialContext: assistantContext,
        ),
      ),
    );
  }

  bool _isSummarizing = false;

  Future<AiAssistantState> _dispatchAiSummary(
    List<Map<String, String>> chatLog,
  ) async {
    final bloc = context.read<AiAssistantBloc>();
    final resultFuture = bloc.stream.firstWhere(
      (state) => state is AiAssistantSummaryReady || state is AiAssistantError,
    );
    bloc.add(SummarizeChatEvent(messages: chatLog));
    return await resultFuture;
  }

  Future<AttachmentState> _dispatchAttachmentAction(
    AttachmentEvent event,
  ) async {
    final bloc = context.read<AttachmentBloc>();
    final resultFuture = bloc.stream.firstWhere(
      (state) => state is AttachmentActionSuccess || state is AttachmentError,
    );
    bloc.add(event);
    return await resultFuture;
  }

  Future<void> _summarizeChat(List<MessageEntity> messages) async {
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có tin nhắn nào để tóm tắt.')),
      );
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      final chatLog = messages
          .map((m) => {'sender': m.senderName, 'content': m.content})
          .toList();

      final result = await _dispatchAiSummary(chatLog);
      if (!mounted) return;

      if (result is AiAssistantSummaryReady) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.orange),
                SizedBox(width: 8),
                Text('Tóm tắt hội thoại'),
              ],
            ),
            content: SingleChildScrollView(child: Text(result.summary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      } else if (result is AiAssistantError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> fileData) async {
    final fileName = (fileData['name'] ?? 'tệp').toString();

    final result = await _dispatchAttachmentAction(
      DeleteAttachmentRequested(taskId: widget.task.taskId, fileData: fileData),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result is AttachmentActionSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa tệp: $fileName'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (result is AttachmentError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xóa tệp: ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: widget.initialTabIndex,
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.task.title),
          // THANH ĐIỀU HƯỚNG TABS
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Chi tiết'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Thảo luận'),
              Tab(icon: Icon(Icons.attach_file), text: 'Đính kèm'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildDetailsTab(), // Tab 1
              _buildChatTab(), // Tab 2
              _buildAttachmentsTab(), // Tab 3
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: chi tiết task
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
              Chip(
                label: Text(
                  _translateStatus(widget.task.status),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: AppColors.primary,
                side: BorderSide.none,
              ),
              Chip(
                label: Text('Ưu tiên: ${widget.task.priority}'),
                backgroundColor: _priorityColor(
                  widget.task.priority,
                ).withValues(alpha: 0.12),
                side: BorderSide(
                  color: _priorityColor(
                    widget.task.priority,
                  ).withValues(alpha: 0.28),
                ),
                labelStyle: TextStyle(
                  color: _priorityColor(widget.task.priority),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mô tả
          const Text(
            'Mô tả công việc:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              widget.task.description.isEmpty
                  ? 'Chưa có mô tả'
                  : widget.task.description,
            ),
          ),
          const SizedBox(height: 24),

          // Thông tin người nhận và Deadline
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceAlt,
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            title: const Text('Người thực hiện'),
            subtitle: Text(widget.task.assigneeNames.join(', ')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.warning,
              child: Icon(Icons.calendar_today, color: Colors.white),
            ),
            title: const Text('Hạn chót (Deadline)'),
            subtitle: Text(
              widget.task.dueDate != null
                  ? widget.task.dueDate.toString()
                  : 'Chưa đặt ngày',
            ),
          ),

          const Divider(height: 40),

          // Nút thao tác
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('PROJECTS')
                .doc(widget.task.projectId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final String ownerId = data['ownerId'] ?? '';
              final Map<String, dynamic> roles = data['roles'] ?? {};
              final String currentUid =
                  FirebaseAuth.instance.currentUser?.uid ?? '';

              // Owner hoặc Trưởng nhóm được sửa/xóa task.
              final bool hasPermission = ProjectRoleUtils.canManageTasks(
                userId: currentUid,
                ownerId: ownerId,
                roles: roles,
              );

              if (!hasPermission) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Text(
                    'Chỉ Chủ dự án và Trưởng nhóm mới có quyền sửa hoặc xóa công việc này.',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      label: const Text('Chỉnh sửa'),
                      onPressed: _showEditTaskModal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        'Xóa Task',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: _deleteTask,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // TAB 2: Chat
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
              child: Row(
                children: [
                  // Nút Tóm tắt (Phím tắt cũ)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning.withValues(
                          alpha: 0.10,
                        ),
                        elevation: 0,
                        side: BorderSide(
                          color: AppColors.warning.withValues(alpha: 0.24),
                        ),
                      ),
                      icon: _isSummarizing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.warning,
                              ),
                            )
                          : const Icon(
                              Icons.summarize,
                              color: AppColors.warning,
                            ),
                      label: const Text(
                        'Tóm tắt',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isSummarizing
                          ? null
                          : () => _summarizeChat(currentMessages),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút gọi Trợ lý AI (Hub tập trung)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.aiSoft,
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFE9D5FF)),
                      ),
                      icon: const Icon(Icons.auto_awesome, color: AppColors.ai),
                      label: const Text(
                        'Hỏi Trợ lý',
                        style: TextStyle(
                          color: AppColors.ai,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () =>
                          _openAssistantWithTaskContext(currentMessages),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: BlocBuilder<MessageBloc, MessageState>(
            builder: (context, state) {
              if (state is MessageLoading)
                return const Center(child: CircularProgressIndicator());
              if (state is MessageError)
                return Center(
                  child: Text(
                    'Lỗi: ${state.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              if (state is MessageLoaded) {
                // 1. Đảo ngược danh sách tin nhắn để cái mới nhất lên
                final reversedMessages = state.messages.reversed.toList();

                return ListView.builder(
                  reverse: true, //Lật ngược danh sách từ dưới lên trên
                  padding: const EdgeInsets.all(16),
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, index) {
                    final msg = reversedMessages[index];
                    final isMe = msg.senderId == currentUser?.uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // ng khaccs thì hiện avt bên trái
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              backgroundImage: msg.senderAvatarUrl != null
                                  ? NetworkImage(msg.senderAvatarUrl!)
                                  : null,
                              child: msg.senderAvatarUrl == null
                                  ? Text(
                                      msg.senderName[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                          ],

                          //khung chat
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primary
                                    : AppColors.surface,
                                border: isMe
                                    ? null
                                    : Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottomRight: isMe
                                      ? Radius.zero
                                      : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tên người gửi
                                  if (!isMe) ...[
                                    Text(
                                      msg.senderName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],

                                  // Nội dung: Ảnh hoặc Chữ
                                  if (msg.imageUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        msg.imageUrl!,
                                        width: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Text(
                                      msg.content,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
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
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.image_outlined,
                  color: AppColors.primary,
                ),
                onPressed: _pickAndSendImage,
              ),
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Hàm xử lý upload file
  Future<void> _uploadFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    final fileName = result.files.first.name;

    if (fileBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể đọc dữ liệu tệp!')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Đang tải "$fileName" lên...')),
        );
    }

    final actionResult = await _dispatchAttachmentAction(
      UploadAttachmentRequested(
        taskId: widget.task.taskId,
        fileName: fileName,
        fileBytes: fileBytes,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (actionResult is AttachmentActionSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tải tệp "$fileName" thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (actionResult is AttachmentError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải tệp: ${actionResult.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // TAB 3: file
  Widget _buildAttachmentsTab() {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<AttachmentBloc, AttachmentState>(
            builder: (context, state) {
              if (state is AttachmentLoading &&
                  state.taskId == widget.task.taskId) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is AttachmentError &&
                  state.taskId == widget.task.taskId) {
                return Center(child: Text('Lỗi: ${state.message}'));
              }

              if (state is AttachmentLoaded &&
                  state.taskId == widget.task.taskId) {
                final attachments = state.attachments;

                if (attachments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.folder_open,
                          size: 80,
                          color: AppColors.muted,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có tệp nào được đính kèm',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final file = attachments[index];
                    final urlString = (file['url'] ?? '').toString();

                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          if (urlString.isEmpty) return;
                          final url = Uri.parse(urlString);

                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, webOnlyWindowName: '_blank');
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Không thể mở tệp')),
                            );
                          }
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.insert_drive_file,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          title: Text(
                            (file['name'] ?? 'Tệp không tên').toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Nhấn để xem tệp trong tab mới'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Tải xuống',
                                icon: const Icon(
                                  Icons.download,
                                  color: AppColors.primary,
                                ),
                                onPressed: () async {
                                  if (urlString.isEmpty) return;
                                  final url = Uri.parse(urlString);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Xóa tệp',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Xác nhận xóa'),
                                      content: Text(
                                        'Bạn có chắc chắn muốn xóa tệp "${file['name']}" không?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Hủy'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteFile(file);
                                          },
                                          child: const Text(
                                            'Xóa',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
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
              }

              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.upload_file),
            label: const Text(
              'Tải tệp mới lên',
              style: TextStyle(fontSize: 16),
            ),
            onPressed: _uploadFile,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSelector(
    List<String> ids,
    List<String> names,
    List<String> avatars,
    StateSetter setModalState,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('PROJECTS')
          .doc(widget.task.projectId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        List<dynamic> memberIds = snapshot.data!.get('memberIds') ?? [];
        if (memberIds.isEmpty) return const Text('Dự án chưa có thành viên.');

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('USERS')
              .where(FieldPath.documentId, whereIn: memberIds)
              .snapshots(),
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
                    backgroundImage: avatar != null
                        ? NetworkImage(avatar)
                        : null,
                    child: avatar == null ? Text(name[0].toUpperCase()) : null,
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      if (val == true) {
                        ids.add(uid);
                        names.add(name);
                        avatars.add(avatar ?? '');
                      } else {
                        int i = ids.indexOf(uid);
                        ids.removeAt(i);
                        names.removeAt(i);
                        avatars.removeAt(i);
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
