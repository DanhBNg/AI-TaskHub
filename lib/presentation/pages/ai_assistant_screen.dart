import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ai_chat_message_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../state/ai_assistant_bloc.dart';
import '../state/task_bloc.dart';
import '../theme/app_theme.dart';
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
  String? _selectedProjectId;
  String? _selectedProjectName;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _resolveContext() async {
    Map<String, dynamic> finalContext = Map.from(widget.initialContext);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return finalContext;

    String fullName = user.displayName ?? user.email?.split('@').first ?? '';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('USERS')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final storedName = (userData?['fullName'] ?? '').toString().trim();
      if (storedName.isNotEmpty) fullName = storedName;
    } catch (_) {
      // Auth data is enough for AI context if the profile document cannot load.
    }

    finalContext['current_user'] = {
      'id': user.uid,
      'email': user.email ?? '',
      'fullName': fullName,
    };
    finalContext['current_date'] = DateTime.now().toIso8601String();

    if (widget.initialContext.isNotEmpty) return finalContext;

    final projectsSnap = await FirebaseFirestore.instance
        .collection('PROJECTS')
        .where('memberIds', arrayContains: user.uid)
        .get();

    final projectsData = projectsSnap.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'description': doc['description'],
        }).toList();

    final projectIds = projectsSnap.docs.map((doc) => doc.id).toList();
    List<Map<String, dynamic>> tasksData = [];

    if (projectIds.isNotEmpty) {
      final tasksSnap = await FirebaseFirestore.instance
          .collection('TASKS')
          .where('projectId', whereIn: projectIds.take(10).toList())
          .get();

      tasksData = tasksSnap.docs.map((doc) {
        final data = doc.data();
        final projectName = projectsData.firstWhere(
          (project) => project['id'] == data['projectId'],
          orElse: () => {'name': 'Dự án khác'},
        )['name'];

        return {
          'taskId': doc.id,
          'projectId': data['projectId'] ?? '',
          'taskName': data['title'] ?? 'Chưa có tên',
          'description': data['description'] ?? '',
          'projectName': projectName,
          'status': data['status'] ?? 'Unknown',
          'priority': data['priority'] ?? 'Medium',
          'dueDate': data['dueDate'] != null
              ? (data['dueDate'] as Timestamp).toDate().toIso8601String()
              : 'Chưa có hạn chót',
          'assigneeIds': data['assigneeIds'] ?? [],
          'assigneeNames': data['assigneeNames'] ?? [],
        };
      }).toList();
    }

    return {
      ...finalContext,
      'user_role': 'Người dùng quản lý dự án',
      'projects_list': projectsData,
      'all_tasks_list': tasksData,
    };
  }

  void _sendMessage([String? message]) async {
    final content = (message ?? _messageController.text).trim();
    if (content.isEmpty) return;

    final finalContext = await _resolveContext();
    if (!mounted) return;

    context.read<AiAssistantBloc>().add(
          SendMessageEvent(
            message: content,
            projectId: widget.projectId,
            context: finalContext,
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

  String _actionLabel(String action) {
    switch (action) {
      case 'CREATE_TASK':
        return 'Tạo công việc mới';
      case 'SUMMARIZE':
        return 'Tóm tắt nội dung';
      case 'FIND_TASK':
        return 'Tìm kiếm task';
      case 'PRIORITIZE':
        return 'Sắp xếp ưu tiên';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  void _handleAction(
    String action, {
    bool ignoreConversationHistory = false,
  }) async {
    switch (action) {
      case 'SUMMARIZE':
      case 'CREATE_TASK':
      case 'FIND_TASK':
      case 'PRIORITIZE':
        final finalContext = await _resolveContext();
        if (!mounted) return;

        var targetProjectId = widget.projectId;
        var targetContext = finalContext;
        if (action == 'FIND_TASK') {
          final criteria = await _showFindTaskCriteriaDialog();
          if (!mounted || criteria == null || criteria.trim().isEmpty) {
            return;
          }
          targetContext = {
            ...finalContext,
            'user_search_criteria': criteria.trim(),
          };
        }

        if (action == 'CREATE_TASK') {
          final selectedProjectId = await _resolveTargetProjectId(finalContext);
          if (!mounted || selectedProjectId == null || selectedProjectId.isEmpty) {
            return;
          }
          targetProjectId = selectedProjectId;
          targetContext = _contextForProject(finalContext, selectedProjectId);
        }

        context.read<AiAssistantBloc>().add(
              RunAssistantActionEvent(
                action: action,
                projectId: targetProjectId,
                context: targetContext,
                ignoreConversationHistory: ignoreConversationHistory,
              ),
            );
        break;
      default:
        _sendMessage('Hãy thực hiện hành động: $action');
    }
  }

  Future<String?> _showFindTaskCriteriaDialog() async {
    final criteriaController = TextEditingController();

    final criteria = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bạn muốn tìm task nào?'),
        content: TextField(
          controller: criteriaController,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: task quá hạn, task ưu tiên cao, task của Nguyễn Văn...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop(criteriaController.text);
            },
            icon: const Icon(Icons.search),
            label: const Text('Tìm'),
          ),
        ],
      ),
    );

    criteriaController.dispose();
    return criteria;
  }

  Future<String?> _resolveTargetProjectId(
    Map<String, dynamic> contextData,
  ) async {
    if (widget.projectId.isNotEmpty) return widget.projectId;
    if (_selectedProjectId != null && _selectedProjectId!.isNotEmpty) {
      return _selectedProjectId;
    }

    final projects = _readProjects(contextData);
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần có ít nhất một dự án để tạo task.')),
      );
      return null;
    }

    if (projects.length == 1) {
      _selectedProjectId = projects.first['id']?.toString();
      _selectedProjectName = projects.first['name']?.toString();
      return _selectedProjectId;
    }

    return _showProjectPicker(projects);
  }

  List<Map<String, dynamic>> _readProjects(Map<String, dynamic> contextData) {
    final rawProjects = contextData['projects_list'];
    if (rawProjects is! List) return [];
    return rawProjects
        .whereType<Map>()
        .map((project) => Map<String, dynamic>.from(project))
        .where((project) => (project['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  Future<String?> _showProjectPicker(List<Map<String, dynamic>> projects) async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chọn dự án để tạo task'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: projects.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final project = projects[index];
              final name = (project['name'] ?? 'Dự án chưa đặt tên').toString();
              final description = (project['description'] ?? '').toString();
              return ListTile(
                leading: const Icon(Icons.folder_outlined, color: AppColors.ai),
                title: Text(name),
                subtitle: description.isEmpty ? null : Text(description),
                onTap: () => Navigator.of(dialogContext).pop(project),
              );
            },
          ),
        ),
      ),
    );

    if (selected == null) return null;
    _selectedProjectId = selected['id']?.toString();
    _selectedProjectName = selected['name']?.toString();
    return _selectedProjectId;
  }

  Map<String, dynamic> _contextForProject(
    Map<String, dynamic> contextData,
    String projectId,
  ) {
    final scopedContext = Map<String, dynamic>.from(contextData);
    final projects = _readProjects(contextData);
    Map<String, dynamic>? selectedProject;
    for (final project in projects) {
      if (project['id']?.toString() == projectId) {
        selectedProject = project;
        break;
      }
    }

    final rawTasks = contextData['all_tasks_list'];
    final tasks = rawTasks is List
        ? rawTasks
            .whereType<Map>()
            .map((task) => Map<String, dynamic>.from(task))
            .where((task) => task['projectId']?.toString() == projectId)
            .toList()
        : <Map<String, dynamic>>[];

    if (selectedProject != null) {
      scopedContext['current_project'] = selectedProject;
    }
    scopedContext['all_tasks_list'] = tasks;
    scopedContext['target_project_id'] = projectId;
    scopedContext['target_project_name'] =
        selectedProject?['name']?.toString() ?? _selectedProjectName ?? '';
    return scopedContext;
  }

  Future<void> _showCreateTasksPreview(Map<String, dynamic> payload) async {
    final rawTasks = payload['tasks'];
    final tasks = rawTasks is List
        ? rawTasks
            .whereType<Map>()
            .map((task) => Map<String, dynamic>.from(task))
            .toList()
        : <Map<String, dynamic>>[];

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI chưa đề xuất được task nào từ dữ liệu hiện tại.'),
        ),
      );
      return;
    }

    final selectedIndexes = List<bool>.filled(tasks.length, true);
    final selectedTasks = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final checkedCount = selectedIndexes
                .where((checked) => checked)
                .length;

            return AlertDialog(
              title: const Text('Task AI đề xuất'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(tasks.length, (index) {
                      final task = tasks[index];
                      final priority =
                          (task['priority'] ?? 'Medium').toString();
                      final description =
                          (task['description'] ?? '').toString().trim();

                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selectedIndexes[index],
                        activeColor: AppColors.ai,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedIndexes[index] = value ?? false;
                          });
                        },
                        title: Text((task['title'] ?? 'Task mới').toString()),
                        subtitle: Text(
                          [
                            if (description.isNotEmpty) description,
                            'Ưu tiên: $priority',
                          ].join('\n'),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Hủy'),
                ),
                ElevatedButton.icon(
                  onPressed: checkedCount == 0
                      ? null
                      : () {
                          final pickedTasks = <Map<String, dynamic>>[];
                          for (var index = 0; index < tasks.length; index++) {
                            if (selectedIndexes[index]) {
                              pickedTasks.add(tasks[index]);
                            }
                          }
                          Navigator.of(dialogContext).pop(pickedTasks);
                        },
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text('Tạo $checkedCount task'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedTasks == null || selectedTasks.isEmpty || !mounted) return;

    final targetProjectId = (payload['projectId'] ?? widget.projectId).toString();
    if (targetProjectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa xác định được dự án để tạo task.')),
      );
      return;
    }

    for (final task in selectedTasks) {
      final newTaskId = FirebaseFirestore.instance.collection('TASKS').doc().id;
      final newTask = TaskEntity(
        taskId: newTaskId,
        projectId: targetProjectId,
        title: (task['title'] ?? 'Task mới').toString().trim(),
        description: (task['description'] ?? '').toString().trim(),
        status: 'todo',
        priority: (task['priority'] ?? 'Medium').toString(),
        dueDate: null,
        assigneeIds: const [],
        assigneeNames: const [],
        assigneeAvatarUrls: const [],
        createdAt: DateTime.now(),
      );
      context.read<TaskBloc>().add(CreateTask(newTask));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã tạo ${selectedTasks.length} task từ gợi ý AI.')),
    );
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
            Icon(Icons.auto_awesome, color: AppColors.ai),
            SizedBox(width: 8),
            Text('Trợ lý AI TaskHub'),
          ],
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      drawer: const AppDrawer(currentIndex: 2),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<AiAssistantBloc, AiAssistantState>(
                listener: (context, state) {
                  if (state is AiAssistantError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.error),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }

                  if (state is AiAssistantActionReady &&
                      state.action == 'CREATE_TASK') {
                    _showCreateTasksPreview(state.payload);
                  }

                  _scrollToBottom();
                },
                builder: (context, state) {
                  final messages = state.messages;

                  if (messages.isEmpty) {
                    final isLoading = state is AiAssistantLoading;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.aiSoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.smart_toy,
                                size: 64,
                                color: AppColors.ai,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Xin chào!\nTôi là Trợ lý AI của bạn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Bạn có thể yêu cầu tôi chia nhỏ công việc, tóm tắt tiến độ dự án, hoặc phân tích hạn chót.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _QuickStartChips(
                              enabled: !isLoading,
                              onActionPressed: _handleAction,
                              onPromptPressed: _sendMessage,
                            ),
                            if (isLoading) ...[
                              const SizedBox(height: 18),
                              const _TypingBubble(),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        messages.length + (state is AiAssistantLoading ? 1 : 0),
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
            BlocBuilder<AiAssistantBloc, AiAssistantState>(
              builder: (context, state) {
                return _InputBar(
                  controller: _messageController,
                  actionsEnabled: state is! AiAssistantLoading,
                  onActionSelected: (action) => _handleAction(
                    action,
                    ignoreConversationHistory: true,
                  ),
                  onSend: () => _sendMessage(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStartChips extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onActionPressed;
  final ValueChanged<String> onPromptPressed;

  const _QuickStartChips({
    this.enabled = true,
    required this.onActionPressed,
    required this.onPromptPressed,
  });

  @override
  Widget build(BuildContext context) {
    final prompts = [
      (
        icon: Icons.summarize_outlined,
        label: 'Tóm tắt dữ liệu',
        onPressed: () => onActionPressed('SUMMARIZE'),
      ),
      (
        icon: Icons.search_outlined,
        label: 'Tìm task liên quan',
        onPressed: () => onActionPressed('FIND_TASK'),
      ),
      (
        icon: Icons.flag_outlined,
        label: 'Task quan trọng cần làm',
        onPressed: () => onActionPressed('PRIORITIZE'),
      ),
      (
        icon: Icons.add_task_outlined,
        label: 'Gợi ý task mới',
        onPressed: () => onActionPressed('CREATE_TASK'),
      ),
      (
        icon: Icons.lightbulb_outline,
        label: 'Tôi nên làm gì tiếp?',
        onPressed: () => onPromptPressed('Dựa trên dữ liệu hiện tại, tôi nên làm gì tiếp theo?'),
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: prompts.map((prompt) {
        return ActionChip(
          avatar: Icon(prompt.icon, size: 18, color: AppColors.ai),
          label: Text(prompt.label),
          labelStyle: const TextStyle(
            color: AppColors.ai,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor: AppColors.aiSoft,
          side: const BorderSide(color: Color(0xFFE9D5FF)),
          onPressed: enabled ? prompt.onPressed : null,
        );
      }).toList(),
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
    final bubbleColor = isUser ? AppColors.ai : AppColors.surface;
    final textColor = isUser ? Colors.white : AppColors.text;

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
            border: isUser ? null : Border.all(color: AppColors.border),
            boxShadow: isUser
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft:
                  isUser ? const Radius.circular(20) : const Radius.circular(4),
              bottomRight:
                  isUser ? const Radius.circular(4) : const Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppColors.ai),
                    SizedBox(width: 6),
                    Text(
                      'Trợ lý AI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.ai,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message.content,
                style: TextStyle(color: textColor, height: 1.4, fontSize: 15),
              ),
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
                      backgroundColor: AppColors.aiSoft,
                      side: const BorderSide(color: Color(0xFFE9D5FF)),
                      labelStyle: const TextStyle(
                        color: AppColors.ai,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      label: Text(actionLabelBuilder(action)),
                      avatar:
                          const Icon(Icons.bolt, size: 16, color: AppColors.ai),
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.ai,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'AI đang suy nghĩ...',
            style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool actionsEnabled;
  final ValueChanged<String> onActionSelected;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.actionsEnabled,
    required this.onActionSelected,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ActionMenuButton(
            enabled: actionsEnabled,
            onActionSelected: onActionSelected,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Nhắn với Trợ lý AI...',
                hintStyle: const TextStyle(color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration:
                const BoxDecoration(color: AppColors.ai, shape: BoxShape.circle),
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

class _ActionMenuButton extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onActionSelected;

  const _ActionMenuButton({
    required this.enabled,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        value: 'SUMMARIZE',
        icon: Icons.summarize_outlined,
        label: 'Tóm tắt dữ liệu',
      ),
      (
        value: 'CREATE_TASK',
        icon: Icons.add_task_outlined,
        label: 'Tạo công việc mới',
      ),
      (
        value: 'FIND_TASK',
        icon: Icons.search_outlined,
        label: 'Tìm kiếm task',
      ),
      (
        value: 'PRIORITIZE',
        icon: Icons.flag_outlined,
        label: 'Task quan trọng cần làm',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: enabled ? AppColors.aiSoft : AppColors.surfaceAlt,
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        enabled: enabled,
        tooltip: 'Mở menu công cụ AI',
        icon: Icon(
          Icons.menu_rounded,
          color: enabled ? AppColors.ai : AppColors.muted,
        ),
        offset: const Offset(0, -8),
        onSelected: onActionSelected,
        itemBuilder: (context) => actions.map((action) {
          return PopupMenuItem<String>(
            value: action.value,
            child: Row(
              children: [
                Icon(action.icon, size: 20, color: AppColors.ai),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    action.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
