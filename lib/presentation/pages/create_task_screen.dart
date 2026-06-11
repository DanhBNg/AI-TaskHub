import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/task_entity.dart';
import '../state/task_bloc.dart';
import '../theme/app_theme.dart';

class CreateTaskScreen extends StatefulWidget {
  final String projectId;
  const CreateTaskScreen({super.key, required this.projectId});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _selectedDueDate;
  String _selectedPriority = 'Medium';
  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _selectedAssigneeIds = [];
  final List<String> _selectedAssigneeNames = [];
  final List<String> _selectedAssigneeAvatars = [];

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final newTaskId = FirebaseFirestore.instance.collection('TASKS').doc().id;
    final newTask = TaskEntity(
      taskId: newTaskId,
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      status: 'todo',
      priority: _selectedPriority,
      dueDate: _selectedDueDate,
      assigneeIds: _selectedAssigneeIds,
      assigneeNames: _selectedAssigneeNames,
      assigneeAvatarUrls: _selectedAssigneeAvatars,
      createdAt: DateTime.now(),
    );
    context.read<TaskBloc>().add(CreateTask(newTask));
    Navigator.pop(context);
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _showAssigneePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('PROJECTS')
              .doc(widget.projectId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            List<dynamic> memberIds = snapshot.data!.get('memberIds') ?? [];
            if (memberIds.isEmpty) {
              return const Center(child: Text('Dự án chưa có thành viên.'));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('USERS')
                  .where(FieldPath.documentId, whereIn: memberIds)
                  .snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StatefulBuilder(
                  builder: (context, setModalState) {
                    return SafeArea(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: userSnap.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = userSnap.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          String uid = doc.id;
                          String name = data['fullName'] ?? data['email'].split('@')[0];
                          String? avatar = data['avatarUrl'];

                          bool isSelected = _selectedAssigneeIds.contains(uid);

                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(name),
                            secondary: CircleAvatar(
                              backgroundImage:
                                  avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null
                                  ? Text(name[0].toUpperCase())
                                  : null,
                            ),
                            onChanged: (bool? checked) {
                              setModalState(() {
                                if (checked == true) {
                                  _selectedAssigneeIds.add(uid);
                                  _selectedAssigneeNames.add(name);
                                  _selectedAssigneeAvatars.add(avatar ?? '');
                                } else {
                                  int idx = _selectedAssigneeIds.indexOf(uid);
                                  _selectedAssigneeIds.removeAt(idx);
                                  _selectedAssigneeNames.removeAt(idx);
                                  _selectedAssigneeAvatars.removeAt(idx);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm công việc mới')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Chi tiết công việc',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Task mới sẽ bắt đầu ở cột Cần làm.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tên task *',
                          prefixIcon: Icon(Icons.task_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả chi tiết',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        readOnly: true,
                        onTap: () => _selectDueDate(context),
                        decoration: const InputDecoration(
                          labelText: 'Hạn chót (Deadline)',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        controller: TextEditingController(
                          text: _selectedDueDate == null
                              ? ''
                              : '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Độ ưu tiên',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: _priorities
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    color: p == 'High'
                                        ? AppColors.danger
                                        : (p == 'Medium'
                                            ? AppColors.warning
                                            : AppColors.success),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _selectedPriority = val!),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        tileColor: AppColors.surface,
                        leading: const Icon(
                          Icons.group_add_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Người thực hiện',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          _selectedAssigneeNames.isEmpty
                              ? 'Chưa phân công'
                              : _selectedAssigneeNames.join(', '),
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _showAssigneePicker,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.add_task),
                          label: const Text('Thêm task'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
