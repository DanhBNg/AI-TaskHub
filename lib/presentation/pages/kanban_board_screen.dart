import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskhub_ai/presentation/pages/task_detail_sceen.dart';

import '../../domain/entities/project_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../state/ai_assistant_bloc.dart';
import '../state/project_bloc.dart';
import '../state/task_bloc.dart';
import '../theme/app_theme.dart';
import 'create_task_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const KanbanBoardScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  final ScrollController _boardScrollController = ScrollController();
  Timer? _autoScrollTimer;
  final double _scrollZoneWidth = 60.0;
  final double _scrollSpeed = 8.0;

  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasks(widget.projectId));
  }

  Future<bool> _dispatchProjectAction(ProjectEvent event) async {
    final bloc = context.read<ProjectBloc>();
    final resultFuture = bloc.stream.firstWhere(
      (state) => state is ProjectActionSuccess || state is ProjectError,
    );
    bloc.add(event);
    final result = await resultFuture;
    return result is ProjectActionSuccess;
  }

  void _showMembersManagementModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Danh sách thành viên',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('PROJECTS')
                        .doc(widget.projectId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      final memberIds = List<dynamic>.from(
                        data['memberIds'] ?? const [],
                      );
                      final roles = Map<String, dynamic>.from(
                        data['roles'] ?? const {},
                      );
                      final ownerId = data['ownerId'] ?? '';
                      final isOwner =
                          FirebaseAuth.instance.currentUser?.uid == ownerId;

                      return ListView.builder(
                        itemCount: memberIds.length,
                        itemBuilder: (context, index) {
                          final uid = memberIds[index];
                          final roleName = uid == ownerId
                              ? 'Chủ dự án'
                              : (roles[uid] == 'Admin'
                                    ? 'Quản trị viên'
                                    : 'Thành viên');

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('USERS')
                                .doc(uid)
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData) {
                                return const SizedBox();
                              }
                              final userData =
                                  userSnap.data!.data() as Map<String, dynamic>;
                              final name = userData['fullName'] ?? 'Người dùng';
                              final avatar = userData['avatarUrl'];

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: avatar != null
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: avatar == null
                                      ? Text(name[0].toUpperCase())
                                      : null,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Vai trò: $roleName',
                                  style: TextStyle(
                                    color: uid == ownerId
                                        ? Colors.red
                                        : Colors.blueAccent,
                                  ),
                                ),
                                trailing: (isOwner && uid != ownerId)
                                    ? PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'delete') {
                                            _removeMember(uid, name);
                                          } else {
                                            _updateMemberRole(uid, value);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'Admin',
                                            child: Text('Gán quyền Admin'),
                                          ),
                                          PopupMenuItem(
                                            value: 'Member',
                                            child: Text('Gán quyền Member'),
                                          ),
                                          PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Xóa khỏi dự án',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : (uid == ownerId
                                          ? const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                            )
                                          : null),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateMemberRole(String uid, String newRole) async {
    await _dispatchProjectAction(
      UpdateMemberRoleRequested(widget.projectId, uid, newRole),
    );
  }

  Future<void> _removeMember(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Xóa $name khỏi dự án?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dispatchProjectAction(
        RemoveMemberRequested(widget.projectId, uid),
      );
    }
  }

  void _showEditProjectModal(BuildContext context) async {
    final doc = await FirebaseFirestore.instance
        .collection('PROJECTS')
        .doc(widget.projectId)
        .get();
    if (!doc.exists) return;

    final data = doc.data() ?? <String, dynamic>{};
    final currentName = data['name'] ?? widget.projectName;
    final currentDesc = data['description'] ?? '';
    final ownerId = data['ownerId'] ?? '';
    final memberIds = List<String>.from(data['memberIds'] ?? const []);
    final roles = Map<String, dynamic>.from(data['roles'] ?? const {});
    final status = data['status'] ?? 'active';
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final nameController = TextEditingController(text: currentName);
    final descController = TextEditingController(text: currentDesc);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa dự án'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên dự án *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mô tả dự án',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final dialogNavigator = Navigator.of(ctx);
              final updatedProject = ProjectEntity(
                projectId: widget.projectId,
                name: nameController.text.trim(),
                description: descController.text.trim(),
                ownerId: ownerId,
                memberIds: memberIds,
                roles: roles,
                status: status,
                createdAt: createdAt,
              );

              final success = await _dispatchProjectAction(
                UpdateProjectRequested(updatedProject),
              );

              if (dialogNavigator.mounted) {
                dialogNavigator.pop();
              }
              if (!context.mounted) return;
              if (success) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _deleteProject(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa dự án rủi ro!'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa dự án này không? Mọi Task và dữ liệu bên trong sẽ bị mất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final dialogNavigator = Navigator.of(ctx);
              final success = await _dispatchProjectAction(
                DeleteProjectRequested(widget.projectId),
              );

              if (dialogNavigator.mounted) {
                dialogNavigator.pop();
              }
              if (!context.mounted) return;
              if (success) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'Xóa vĩnh viễn',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  bool _isAILoading = false;

  Future<AiAssistantState> _dispatchTaskGeneration(String prompt) async {
    final bloc = context.read<AiAssistantBloc>();
    final resultFuture = bloc.stream.firstWhere(
      (state) =>
          state is AiAssistantTasksGenerated || state is AiAssistantError,
    );
    bloc.add(GenerateTasksEvent(prompt: prompt));
    return await resultFuture;
  }

  void _showAIGeneratorModal() {
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'AI Chia Việc Thông Minh',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: _isAILoading
                ? const SizedBox(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('AI đang suy nghĩ...'),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    width: 320,
                    child: TextField(
                      controller: promptController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'VD: Làm tính năng đăng nhập bằng Google và Facebook...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
            actions: _isAILoading
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                      onPressed: () async {
                        final prompt = promptController.text.trim();
                        if (prompt.isEmpty) return;

                        final dialogNavigator = Navigator.of(ctx);
                        setDialogState(() => _isAILoading = true);

                        try {
                          final taskBloc = context.read<TaskBloc>();
                          final result = await _dispatchTaskGeneration(prompt);

                          if (result is AiAssistantTasksGenerated) {
                            for (final t in result.generatedTasks) {
                              final newTask = TaskEntity(
                                taskId: FirebaseFirestore.instance
                                    .collection('TASKS')
                                    .doc()
                                    .id,
                                projectId: widget.projectId,
                                title: (t['title'] ?? 'Task mới').toString(),
                                description: (t['description'] ?? '')
                                    .toString(),
                                priority: (t['priority'] ?? 'Medium')
                                    .toString(),
                                status: 'todo',
                                assigneeIds: const [],
                                assigneeNames: const [],
                                assigneeAvatarUrls: const [],
                                createdAt: DateTime.now(),
                              );
                              taskBloc.add(CreateTask(newTask));
                            }

                            if (!dialogContext.mounted) return;
                            if (dialogNavigator.mounted) {
                              dialogNavigator.pop();
                            }
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('AI đã tạo task thành công!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (result is AiAssistantError &&
                              dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(result.error),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => _isAILoading = false);
                          }
                        }
                      },
                      child: const Text(
                        'Tạo Việc',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProjectBloc, ProjectState>(
      listener: (context, state) {
        if (state is ProjectActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is ProjectError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.projectName),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.purple),
              tooltip: 'Tạo Task bằng AI',
              onPressed: () => _showAIGeneratorModal(),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Thêm thành viên',
              onPressed: () => _showAddMemberDialog(context),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'members') _showMembersManagementModal();
                if (value == 'edit') _showEditProjectModal(context);
                if (value == 'delete') _deleteProject(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'members',
                  child: ListTile(
                    leading: Icon(Icons.people, color: Colors.blue),
                    title: Text('Thành viên'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, color: Colors.orange),
                    title: Text('Sửa dự án'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text(
                      'Xóa dự án',
                      style: TextStyle(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: BlocBuilder<TaskBloc, TaskState>(
          builder: (context, state) {
            if (state is TaskLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is TaskError) {
              return Center(child: Text('Lỗi: ${state.message}'));
            }
            if (state is TaskLoaded) {
              return SingleChildScrollView(
                controller: _boardScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKanbanColumn(
                      'todo',
                      'Cần làm',
                      AppColors.muted,
                      state.tasks,
                    ),
                    _buildKanbanColumn(
                      'in_progress',
                      'Đang làm',
                      AppColors.primary,
                      state.tasks,
                    ),
                    _buildKanbanColumn(
                      'review',
                      'Chờ duyệt',
                      AppColors.warning,
                      state.tasks,
                    ),
                    _buildKanbanColumn(
                      'done',
                      'Hoàn thành',
                      AppColors.success,
                      state.tasks,
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final projectSnap = await FirebaseFirestore.instance
                .collection('PROJECTS')
                .doc(widget.projectId)
                .get();
            final data = projectSnap.data() as Map<String, dynamic>;
            final ownerId = data['ownerId'] ?? '';
            final roles = Map<String, dynamic>.from(data['roles'] ?? const {});
            final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

            final hasPermission =
                (currentUid == ownerId) || (roles[currentUid] == 'Admin');

            if (!context.mounted) return;

            if (!hasPermission) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '🔒 Chỉ Chủ dự án và Quản trị viên mới được tạo Task mới!',
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskScreen(projectId: widget.projectId),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _checkAutoScroll(Offset globalPosition) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (globalPosition.dx < _scrollZoneWidth) {
      _startAutoScroll(-_scrollSpeed);
    } else if (globalPosition.dx > screenWidth - _scrollZoneWidth) {
      _startAutoScroll(_scrollSpeed);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double direction) {
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 15), (
      timer,
    ) {
      if (!_boardScrollController.hasClients) return;

      final currentOffset = _boardScrollController.offset;
      final maxExtent = _boardScrollController.position.maxScrollExtent;
      final newOffset = currentOffset + direction;

      if (newOffset < 0) {
        _boardScrollController.jumpTo(0);
        return;
      } else if (newOffset > maxExtent) {
        _boardScrollController.jumpTo(maxExtent);
        return;
      }

      _boardScrollController.jumpTo(newOffset);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _boardScrollController.dispose();
    super.dispose();
  }

  void _showAddMemberDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mời thành viên'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Nhập Email của thành viên',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (emailController.text.trim().isNotEmpty) {
                  context.read<ProjectBloc>().add(
                    AddMember(widget.projectId, emailController.text.trim()),
                  );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKanbanColumn(
    String status,
    String title,
    Color accentColor,
    List<TaskEntity> allTasks,
  ) {
    final columnTasks = allTasks.where((t) => t.status == status).toList();

    return DragTarget<TaskEntity>(
      onAcceptWithDetails: (details) {
        final task = details.data;
        if (task.status != status) {
          context.read<TaskBloc>().add(UpdateTaskStatus(task.taskId, status));
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final baseTint = accentColor.withValues(alpha: 0.055);
        final hoverTint = accentColor.withValues(alpha: 0.11);
        return Container(
          width: 312,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isHovering ? hoverTint : baseTint,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: isHovering
                  ? accentColor
                  : accentColor.withValues(alpha: 0.18),
              width: isHovering ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        '${columnTasks.length}',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: columnTasks.isEmpty
                    ? const SizedBox.expand()
                    : ListView.builder(
                        itemCount: columnTasks.length,
                        itemBuilder: (context, index) {
                          final task = columnTasks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Draggable<TaskEntity>(
                              data: task,
                              onDragUpdate: (details) =>
                                  _checkAutoScroll(details.globalPosition),
                              onDragEnd: (details) => _stopAutoScroll(),
                              onDraggableCanceled: (velocity, offset) =>
                                  _stopAutoScroll(),
                              feedback: Material(
                                elevation: 8,
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                                child: SizedBox(
                                  width: 286,
                                  child: _TaskCard(
                                    task: task,
                                    accentColor: accentColor,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _TaskCard(
                                  task: task,
                                  accentColor: accentColor,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TaskDetailScreen(task: task),
                                    ),
                                  );
                                },
                                child: _TaskCard(
                                  task: task,
                                  accentColor: accentColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskEntity task;
  final Color accentColor;

  const _TaskCard({required this.task, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PriorityDot(priority: task.priority),
              ],
            ),
            if (task.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 16, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  task.priority,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (task.assigneeNames.isNotEmpty)
                  Flexible(
                    child: Text(
                      task.assigneeNames.length == 1
                          ? task.assigneeNames.first
                          : '${task.assigneeNames.length} người',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final String priority;

  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    final normalized = priority.toLowerCase();
    final color = normalized == 'high'
        ? AppColors.danger
        : normalized == 'medium'
        ? AppColors.warning
        : AppColors.success;

    return Tooltip(
      message: 'Ưu tiên: $priority',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
