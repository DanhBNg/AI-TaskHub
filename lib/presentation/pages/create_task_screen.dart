import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/task_entity.dart';
import '../state/task_bloc.dart';

class CreateTaskScreen extends StatefulWidget {
  final String projectId;
  const CreateTaskScreen({super.key, required this.projectId});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final newTask = TaskEntity(
      taskId: '', // Firestore sẽ tự tạo
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      createdAt: DateTime.now(),
    );
    context.read<TaskBloc>().add(CreateTask(newTask));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm Công Việc Mới')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tên Task *', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Mô tả chi tiết', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _submit, child: const Text('Thêm Task')),
            )
          ],
        ),
      ),
    );
  }
}