import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ai_chat_message_entity.dart';
import '../state/ai_assistant_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';

class AiAssistantScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> initialContext;

  const AiAssistantScreen({
    super.key,
    this.projectId = '',
    this.initialContext = const {},
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? message]) async {
    final content = (message ?? _messageController.text).trim();
    if (content.isEmpty) return;

    Map<String, dynamic> finalContext = Map.from(widget.initialContext);

    
    if (finalContext.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Lấy danh sách các Dự án
        final projectsSnap = await FirebaseFirestore.instance
            .collection('PROJECTS')
            .where('memberIds', arrayContains: user.uid)
            .get();

        final projectsData = projectsSnap.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'description': doc['description'],
        }).toList();

        List<String> projectIds = projectsSnap.docs.map((doc) => doc.id).toList();
        List<Map<String, dynamic>> tasksData = [];

        if (projectIds.isNotEmpty) {
          final tasksSnap = await FirebaseFirestore.instance
              .collection('TASKS')
              .where('projectId', whereIn: projectIds.take(10).toList())
              .get();

          tasksData = tasksSnap.docs.map((doc) {
            final data = doc.data();
            final pName = projectsData.firstWhere(
              (p) => p['id'] == data['projectId'], 
              orElse: () => {'name': 'Dự án khác'}
            )['name'];

            return {
              'taskName': data['title'] ?? 'Chưa có tên',
              'projectName': pName,
              'status': data['status'] ?? 'Unknown',
              'priority': data['priority'] ?? 'Medium',
              'dueDate': data['dueDate'] != null 
                  ? (data['dueDate'] as Timestamp).toDate().toIso8601String() 
                  : 'Chưa có hạn chót',
              'assigneeNames': data['assigneeNames'] ?? [],
            };
          }).toList();
        }

        // 3. Đóng gói lại toàn bộ gửi cho AI
        finalContext = {
          'user_role': 'Người dùng quản lý dự án',
          'projects_list': projectsData,
          'all_tasks_list': tasksData, // Đã bơm thêm Task vào đây!
        };
      }
    }

    context.read<AiAssistantBloc>().add(
          SendMessageEvent(
            message: content,
            projectId: widget.projectId,
            context: finalContext, // Gửi context đã được làm giàu dữ liệu
          ),
        );
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // Dịch các action từ API sang tiếng Việt chuẩn
  String _actionLabel(String action) {
    switch (action) {
      case 'CREATE_TASK': return 'Tạo công việc mới';
      case 'SUMMARIZE': return 'Tóm tắt nội dung';
      case 'FIND_TASK': return 'Tìm kiếm Task';
      case 'PRIORITIZE': return 'Sắp xếp ưu tiên';
      default: return action.replaceAll('_', ' ');
    }
  }

  void _handleAction(String action) {
    switch (action) {
      case 'SUMMARIZE':
        _sendMessage('Hãy tóm tắt ngữ cảnh hiện tại.');
        break;
      case 'CREATE_TASK':
        _sendMessage('Hãy phân rã các công việc cần làm dựa trên ngữ cảnh này.');
        break;
      default:
        _sendMessage('Hãy thực hiện hành động: $action');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Text('Trợ lý AI TaskHub'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      drawer: const AppDrawer(currentIndex: 2),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<AiAssistantBloc, AiAssistantState>(
                listener: (context, state) {
                  if (state is AiAssistantError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.error), backgroundColor: Colors.redAccent),
                    );
                  }
                  _scrollToBottom();
                },
                builder: (context, state) {
                  final messages = state.messages;
                  
                  // Màn hình chào mừng khi chưa có tin nhắn
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.smart_toy, size: 64, color: Colors.purple),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Xin chào!\nTôi là Trợ lý AI của bạn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Bạn có thể yêu cầu tôi chia nhỏ công việc, tóm tắt tiến độ dự án, hoặc phân tích hạn chót (deadline).',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (state is AiAssistantLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _TypingBubble(),
                          ),
                        );
                      }
                      return _MessageBubble(
                        message: messages[index],
                        onActionPressed: _handleAction,
                        actionLabelBuilder: _actionLabel,
                      );
                    },
                  );
                },
              ),
            ),
            _InputBar(
              controller: _messageController,
              onSend: () => _sendMessage(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessageEntity message;
  final ValueChanged<String> onActionPressed;
  final String Function(String action) actionLabelBuilder;

  const _MessageBubble({
    required this.message,
    required this.onActionPressed,
    required this.actionLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser ? Colors.purple : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: isUser ? null : Border.all(color: Colors.grey.shade200),
            boxShadow: isUser ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
              bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hiển thị Icon AI cho tin nhắn của máy
              if (!isUser) ...[
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: Colors.purple),
                    SizedBox(width: 6),
                    Text('Trợ lý AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message.content,
                style: TextStyle(color: textColor, height: 1.4, fontSize: 15),
              ),
              
              // Giao diện Action Chips gợi ý từ AI
              if (!isUser && message.suggestedActions.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.suggestedActions.map((action) {
                    return ActionChip(
                      backgroundColor: Colors.purple.shade50,
                      side: BorderSide(color: Colors.purple.shade100),
                      labelStyle: const TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold),
                      label: Text(actionLabelBuilder(action)),
                      avatar: const Icon(Icons.bolt, size: 16, color: Colors.purple),
                      onPressed: () => onActionPressed(action),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
          ),
          SizedBox(width: 12),
          Text('AI đang suy nghĩ...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1, maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Nhắn với Trợ lý AI...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}