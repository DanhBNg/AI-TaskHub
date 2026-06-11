import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/invite_entity.dart';
import '../state/invite_bloc.dart';
import '../state/project_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'create_project_screen.dart';
import 'kanban_board_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (userId.isNotEmpty) {
      context.read<ProjectBloc>().add(LoadProjects(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskHub AI'),
        actions: [
          BlocBuilder<InviteBloc, InviteState>(
            builder: (context, state) {
              List<InviteEntity> currentInvites = [];
              if (state is InviteLoaded) {
                currentInvites = state.invites;
              }
              final count = currentInvites.length;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Lời mời dự án',
                      onPressed: () {
                        _showInvitesDialog(context, currentInvites);
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: CircleAvatar(
                          radius: 9,
                          backgroundColor: AppColors.danger,
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentIndex: 0),
      body: BlocBuilder<ProjectBloc, ProjectState>(
        builder: (context, state) {
          if (state is ProjectLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProjectError) {
            return _StatePanel(
              icon: Icons.error_outline,
              title: 'Không tải được dự án',
              message: state.message,
              color: AppColors.danger,
            );
          }

          if (state is ProjectLoaded) {
            if (state.projects.isEmpty) {
              return const _StatePanel(
                icon: Icons.folder_open_outlined,
                title: 'Chưa có dự án',
                message: 'Tạo dự án đầu tiên để bắt đầu quản lý công việc.',
                color: AppColors.primary,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  'Danh sách dự án',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Theo dõi các dự án công nghệ, công việc và trao đổi nhóm của bạn.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpacing.lg),
                ...state.projects.map(
                  (project) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProjectCard(
                      name: project.name,
                      description: project.description,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => KanbanBoardScreen(
                              projectId: project.projectId,
                              projectName: project.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Dự án'),
      ),
    );
  }

  void _showInvitesDialog(BuildContext context, List<InviteEntity> invites) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lời mời tham gia dự án'),
        content: SizedBox(
          width: double.maxFinite,
          child: invites.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Bạn không có thông báo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: invites.length,
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        invite.projectName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${invite.senderName} đã mời bạn'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 30,
                            ),
                            onPressed: () {
                              context.read<InviteBloc>().add(
                                    RespondToInvite(
                                      invite.inviteId,
                                      invite.projectId,
                                      true,
                                    ),
                                  );
                              Navigator.pop(ctx);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.cancel,
                              color: AppColors.danger,
                              size: 30,
                            ),
                            onPressed: () {
                              context.read<InviteBloc>().add(
                                    RespondToInvite(
                                      invite.inviteId,
                                      invite.projectId,
                                      false,
                                    ),
                                  );
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String name;
  final String description;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.name,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description.isEmpty ? 'Chưa có mô tả dự án' : description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.muted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 44),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
