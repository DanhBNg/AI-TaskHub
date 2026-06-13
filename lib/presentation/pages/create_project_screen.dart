import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/project_entity.dart';
import '../state/project_bloc.dart';
import '../theme/app_theme.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  void _submit() {
    if (_nameController.text.trim().isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final newProject = ProjectEntity(
      projectId: '',
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      ownerId: userId,
      memberIds: [userId],
      roles: {userId: 'owner'},
      createdAt: DateTime.now(),
    );

    context.read<ProjectBloc>().add(CreateProject(newProject));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo dự án mới')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: const Icon(
                              Icons.view_kanban_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Thông tin dự án',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên dự án *',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.add),
                          label: const Text('Tạo dự án'),
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
