import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/task_entity.dart';
import '../state/task_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<String> _selectedAssigneeIds = [];
  List<String> _selectedAssigneeNames = [];
  List<String> _selectedAssigneeAvatars = [];

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final newTaskId = FirebaseFirestore.instance.collection('TASKS').doc().id;
    final newTask = TaskEntity(
      taskId: newTaskId,
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      status: 'todo', // Trạng thái mặc định
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
          future: FirebaseFirestore.instance.collection('PROJECTS').doc(widget.projectId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            List<dynamic> memberIds = snapshot.data!.get('memberIds') ?? [];
            if (memberIds.isEmpty) return const Center(child: Text('Dự án chưa có thành viên.'));

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('USERS').where(FieldPath.documentId, whereIn: memberIds).snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

                // Dùng StatefulBuilder để Checkbox có thể update UI ngay trong BottomSheet
                return StatefulBuilder(
                    builder: (context, setModalState) {
                      return ListView.builder(
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
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null ? Text(name[0].toUpperCase()) : null,
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
                              setState(() {}); // Cập nhật màn hình chính
                            },
                          );
                        },
                      );
                    }
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
      appBar: AppBar(title: const Text('Thêm Công Việc Mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tên Task *', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Mô tả chi tiết', border: OutlineInputBorder())),
            const SizedBox(height: 16),

            TextFormField(
              readOnly: true,
              onTap: () => _selectDueDate(context),
              decoration: const InputDecoration(
                labelText: 'Hạn chót (Deadline)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, color: Colors.blue),
              ),
              controller: TextEditingController(
                text: _selectedDueDate == null ? '' : '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}',
              ),
            ),
            const SizedBox(height: 16),

            // ĐỘ ƯU TIÊN
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(labelText: 'Độ ưu tiên', border: OutlineInputBorder()),
              items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(color: p == 'High' ? Colors.red : (p == 'Medium' ? Colors.orange : Colors.green))))).toList(),
              onChanged: (val) => setState(() => _selectedPriority = val!),
            ),
            const SizedBox(height: 16),

            // CHỌN NHIỀU THÀNH VIÊN
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade400)),
              leading: const Icon(Icons.group_add, color: Colors.blue),
              title: const Text('Người thực hiện'),
              subtitle: Text(_selectedAssigneeNames.isEmpty ? 'Chưa phân công' : _selectedAssigneeNames.join(', ')),
              trailing: const Icon(Icons.edit),
              onTap: _showAssigneePicker,
            ),
            const SizedBox(height: 32),

            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submit, child: const Text('Thêm Task', style: TextStyle(fontSize: 16)))),
          ],
        ),
      ),
    );
  }
}