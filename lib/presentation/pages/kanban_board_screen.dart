import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/task_entity.dart';
import '../state/task_bloc.dart';
import 'create_task_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const KanbanBoardScreen({super.key, required this.projectId, required this.projectName});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasks(widget.projectId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.projectName)),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          if (state is TaskLoading) return const Center(child: CircularProgressIndicator());
          if (state is TaskError) return Center(child: Text('Lỗi: ${state.message}'));
          if (state is TaskLoaded) {
            return SingleChildScrollView(
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
    );
  }

  // --- LOGIC KÉO THẢ NẰM Ở ĐÂY ---
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
                      child: Card(
                        child: ListTile(
                          title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis),
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