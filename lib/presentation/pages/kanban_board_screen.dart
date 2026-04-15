import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskhub_ai/presentation/pages/task_detail_sceen.dart';
import '../../domain/entities/task_entity.dart';
import '../state/project_bloc.dart';
import '../state/task_bloc.dart';
import 'create_task_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class KanbanBoardScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const KanbanBoardScreen({super.key, required this.projectId, required this.projectName});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  final ScrollController _boardScrollController = ScrollController();
  Timer? _autoScrollTimer;
  final double _scrollZoneWidth = 60.0; // Khoảng cách từ mép màn hình để bắt đầu cuộn
  final double _scrollSpeed = 8.0;
  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasks(widget.projectId));
  }
  void _showMembersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('PROJECTS').doc(widget.projectId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            List<dynamic> memberIds = snapshot.data!.get('memberIds') ?? [];
            if (memberIds.isEmpty) return const Center(child: Text('Dự án chưa có thành viên.'));

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Thành viên dự án', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('USERS').where(FieldPath.documentId, whereIn: memberIds).snapshots(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
                      return ListView.builder(
                        itemCount: userSnap.data!.docs.length,
                        itemBuilder: (context, index) {
                          var data = userSnap.data!.docs[index].data() as Map<String, dynamic>;
                          String name = data['fullName'] ?? data['email'].split('@')[0];
                          String? avatar = data['avatarUrl'];
                          return ListTile(
                            leading: CircleAvatar(backgroundImage: avatar != null ? NetworkImage(avatar) : null, child: avatar == null ? Text(name[0].toUpperCase()) : null),
                            title: Text(name),
                            subtitle: Text(data['email'] ?? ''),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProjectModal(BuildContext context) {
    final nameController = TextEditingController(text: widget.projectName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên dự án'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên dự án mới', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              // Gọi trực tiếp Firebase để update cho nhanh (hoặc dùng ProjectBloc nếu bạn đã định nghĩa UpdateProject Event)
              await FirebaseFirestore.instance.collection('PROJECTS').doc(widget.projectId).update({
                'name': nameController.text.trim()
              });
              Navigator.pop(ctx);
              Navigator.pop(context); // Bắt buộc quay về Dashboard để reload lại tên
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
        content: const Text('Bạn có chắc chắn muốn xóa dự án này? Mọi Task và dữ liệu bên trong sẽ bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Gọi BLoC để xóa (Đảm bảo ProjectBloc của bạn đã có DeleteProject)
              // context.read<ProjectBloc>().add(DeleteProject(widget.projectId));

              // Hoặc gọi thẳng Firebase nếu bạn muốn xử lý nhanh:
              await FirebaseFirestore.instance.collection('PROJECTS').doc(widget.projectId).delete();

              Navigator.pop(ctx); // Đóng hộp thoại
              Navigator.pop(context); // Quay về Dashboard
            },
            child: const Text('Xóa vĩnh viễn', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  bool _isAILoading = false;

  void _showAIGeneratorModal() {
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('AI Chia Việc Thông Minh'),
                ],
              ),
              content: _isAILoading
                  ? const SizedBox(
                  height: 100,
                  child: Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [CircularProgressIndicator(), SizedBox(height: 16), Text('AI đang suy nghĩ...')]
                  ))
              )
                  : TextField(
                controller: promptController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'VD: Làm tính năng đăng nhập bằng Google và Facebook...',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: _isAILoading
                  ? []
                  : [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  onPressed: () async {
                    if (promptController.text.trim().isEmpty) return;

                    setDialogState(() => _isAILoading = true); // Hiện xoay xoay

                    try {
                      // Đổi localhost thành IP máy bạn nếu chạy máy ảo (VD: 10.0.2.2 cho Android Emulator)
                      // Nếu dùng Chrome Web thì cứ để localhost
                      final response = await http.post(
                        Uri.parse('http://localhost:3000/api/generate-tasks'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({'prompt': promptController.text.trim()}),
                      );

                      if (response.statusCode == 200) {
                        final data = jsonDecode(response.body);
                        final List<dynamic> generatedTasks = data['tasks'];

                        // Lưu từng task AI tạo ra vào Firebase
                        for (var t in generatedTasks) {
                          final newTask = TaskEntity(
                            taskId: FirebaseFirestore.instance.collection('TASKS').doc().id,
                            projectId: widget.projectId,
                            title: t['title'] ?? 'Task mới',
                            description: t['description'] ?? '',
                            priority: t['priority'] ?? 'Medium',
                            status: 'todo', // Ném hết vào cột To Do
                            assigneeIds: [], assigneeNames: [], assigneeAvatarUrls: [],
                            createdAt: DateTime.now(),
                          );
                          // Gọi Bloc để tạo Task (như cách bạn vẫn làm)
                          context.read<TaskBloc>().add(CreateTask(newTask));
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI đã tạo task thành công!'), backgroundColor: Colors.green));
                        }
                      } else {
                        throw Exception('Server trả về lỗi');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi gọi AI: $e'), backgroundColor: Colors.red));
                      }
                    } finally {
                      setDialogState(() => _isAILoading = false);
                    }
                  },
                  child: const Text('Tạo Việc', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProjectBloc, ProjectState>(
        listener: (context, state) {
          if (state is ProjectActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state is ProjectError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
    child:  Scaffold(
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
              if (value == 'members') _showMembersModal(context);
              if (value == 'edit') _showEditProjectModal(context);
              if (value == 'delete') _deleteProject(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'members', child: ListTile(leading: Icon(Icons.people, color: Colors.blue), title: Text('Thành viên'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.orange), title: Text('Sửa dự án'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Xóa dự án', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
            ],
          )
        ],
      ),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          if (state is TaskLoading) return const Center(child: CircularProgressIndicator());
          if (state is TaskError) return Center(child: Text('Lỗi: ${state.message}'));
          if (state is TaskLoaded) {
            return SingleChildScrollView(
              controller: _boardScrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKanbanColumn('todo', 'Cần làm', Colors.grey.shade200, state.tasks),
                  _buildKanbanColumn('in_progress', 'Đang làm', Colors.blue.shade50, state.tasks),
                  _buildKanbanColumn('review', 'Chờ duyệt', Colors.orange.shade50, state.tasks),
                  _buildKanbanColumn('done', 'Hoàn thành', Colors.green.shade50, state.tasks),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateTaskScreen(projectId: widget.projectId))
        ),
        child: const Icon(Icons.add),
      ),
    )
    );
  }

  // 1. Kiểm tra xem ngón tay có đang ở sát mép màn hình không
  void _checkAutoScroll(Offset globalPosition) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (globalPosition.dx < _scrollZoneWidth) {
      // Ngón tay ở sát mép Trái -> Cuộn sang trái (giảm offset)
      _startAutoScroll(-_scrollSpeed);
    } else if (globalPosition.dx > screenWidth - _scrollZoneWidth) {
      // Ngón tay ở sát mép Phải -> Cuộn sang phải (tăng offset)
      _startAutoScroll(_scrollSpeed);
    } else {
      // Ngón tay ở giữa màn hình -> Dừng cuộn
      _stopAutoScroll();
    }
  }

  // 2. Kích hoạt động cơ cuộn liên tục bằng Timer
  void _startAutoScroll(double direction) {
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (!_boardScrollController.hasClients) return;

      final currentOffset = _boardScrollController.offset;
      final maxExtent = _boardScrollController.position.maxScrollExtent;
      final newOffset = currentOffset + direction;

      // Chặn lại nếu đã cuộn kịch kim 2 đầu
      if (newOffset < 0) {
        _boardScrollController.jumpTo(0);
        return;
      } else if (newOffset > maxExtent) {
        _boardScrollController.jumpTo(maxExtent);
        return;
      }

      // Nhảy pixel tạo cảm giác cuộn mượt mà
      _boardScrollController.jumpTo(newOffset);
    });
  }

  // 3. Phanh lại khi thả tay
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  // dọn bộ nh khi out màn
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
                  // Gửi sự kiện cho BLoC xử lý
                  context.read<ProjectBloc>().add(
                      AddMember(widget.projectId, emailController.text.trim())
                  );
                  Navigator.pop(dialogContext); // Đóng hộp thoại
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  // kéo th
  Widget _buildKanbanColumn(String status, String title, Color bgColor, List<TaskEntity> allTasks) {
    final columnTasks = allTasks.where((t) => t.status == status).toList();

    return DragTarget<TaskEntity>(
      onAcceptWithDetails: (details) {
        final task = details.data;
        if (task.status != status) {
          context.read<TaskBloc>().add(UpdateTaskStatus(task.taskId, status));
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 300,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('$title (${columnTasks.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: columnTasks.length,
                  itemBuilder: (context, index) {
                    final task = columnTasks[index];
                    return Draggable<TaskEntity>(
                      data: task,
                      onDragUpdate: (details) => _checkAutoScroll(details.globalPosition),
                      onDragEnd: (details) => _stopAutoScroll(),
                      onDraggableCanceled: (velocity, offset) => _stopAutoScroll(),
                      feedback: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 280, padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: Card(child: ListTile(title: Text(task.title))),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(task: task),
                            ),
                          );
                        },
                        child: Card(
                          child: ListTile(
                            title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }
}