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
  String? _selectedAssigneeId;
  String? _selectedAssigneeName;
  String? _selectedAssigneeAvatar;
  String _selectedPriority = 'Medium';
  final List<String> _priorities = ['Low', 'Medium', 'High'];

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final newTask = TaskEntity(
      taskId: '', // ID sẽ do Firebase tự tạo
      projectId: widget.projectId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      status: 'To Do', // Trạng thái mặc định
      priority: _selectedPriority,
      dueDate: _selectedDueDate,
      assigneeId: _selectedAssigneeId,
      assigneeName: _selectedAssigneeName,
      assigneeAvatarUrl: _selectedAssigneeAvatar,
      createdAt: DateTime.now(),
    );
    context.read<TaskBloc>().add(CreateTask(newTask));
    Navigator.pop(context);
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)), // Mặc định ngày mai
      firstDate: DateTime.now(), // Không cho chọn ngày trong quá khứ
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _showAssigneePicker(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          // Lấy thông tin dự án để xem ai đang là thành viên
          future: FirebaseFirestore.instance.collection('PROJECTS').doc(widget.projectId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            List<dynamic> memberIds = snapshot.data!.get('memberIds') ?? [];
            if (memberIds.isEmpty) return const Center(child: Text('Dự án chưa có thành viên nào.'));

            // Truy vấn lấy thông tin chi tiết của các thành viên từ bảng USERS
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('USERS')
                  .where(FieldPath.documentId, whereIn: memberIds).snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: userSnapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var userData = userSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                    String uid = userSnapshot.data!.docs[index].id;
                    String name = userData['fullName'] ?? userData['email'].split('@')[0];
                    String? avatar = userData['avatarUrl'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null ? Text(name[0].toUpperCase()) : null,
                      ),
                      title: Text(name),
                      onTap: () {
                        setState(() {
                          _selectedAssigneeId = uid;
                          _selectedAssigneeName = name;
                          _selectedAssigneeAvatar = avatar;
                        });
                        Navigator.pop(context); // Đóng bảng chọn
                      },
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
      appBar: AppBar(title: const Text('Thêm Công Việc Mới')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tên Task *', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Mô tả chi tiết', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            const SizedBox(height: 16),
            // KHU VỰC CHỌN NGƯỜI NHẬN VIỆC (ASSIGNEE)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _selectedAssigneeAvatar != null ? NetworkImage(_selectedAssigneeAvatar!) : null,
                child: _selectedAssigneeAvatar == null ? const Icon(Icons.person_add, color: Colors.blue) : null,
              ),
              title: const Text('Người thực hiện'),
              subtitle: Text(_selectedAssigneeName ?? 'Chưa phân công'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAssigneePicker(context),
            ),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_selectedDueDate == null
                    ? 'Thêm Deadline'
                    : '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'),
                onPressed: () => _selectDueDate(context),
              ),
            ),
            const SizedBox(width: 12),
            // Dropdown chọn mức độ
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Độ ưu tiên',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                items: _priorities.map((String priority) {
                  return DropdownMenuItem<String>(
                    value: priority,
                    child: Text(priority, style: TextStyle(
                        color: priority == 'High' ? Colors.red : (priority == 'Medium' ? Colors.orange : Colors.green)
                    )),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() { _selectedPriority = newValue!; });
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _submit, child: const Text('Thêm Task')),
            ),
          ],
        ),
      ),
    );
  }
}