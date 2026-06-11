import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/task_entity.dart';
import '../../data/models/task_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'task_detail_sceen.dart';

class MessageListScreen extends StatelessWidget {
  final String? projectId;
  const MessageListScreen({super.key, this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn công việc'),
      ),
      drawer: const AppDrawer(currentIndex: 1),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: projectId != null && projectId!.isNotEmpty
              ? FirebaseFirestore.instance
                  .collection('TASKS')
                  .where('projectId', isEqualTo: projectId)
                  .snapshots()
              : FirebaseFirestore.instance.collection('TASKS').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.error_outline,
                title: 'Không tải được tin nhắn',
                message: '${snapshot.error}',
                color: AppColors.danger,
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const _MessageState(
                icon: Icons.chat_bubble_outline,
                title: 'Chưa có hội thoại',
                message: 'Các trao đổi trong task sẽ xuất hiện tại đây.',
                color: AppColors.primary,
              );
            }

            final tasksWithMessages = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data.containsKey('lastMessage') &&
                  data['lastMessage'] != null &&
                  data['lastMessage'].toString().trim().isNotEmpty;
            }).toList();

            tasksWithMessages.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;

              final timeA = dataA['lastMessageTime'] as Timestamp?;
              final timeB = dataB['lastMessageTime'] as Timestamp?;

              if (timeA == null && timeB == null) return 0;
              if (timeA == null) return 1;
              if (timeB == null) return -1;

              return timeB.compareTo(timeA);
            });

            if (tasksWithMessages.isEmpty) {
              return const _MessageState(
                icon: Icons.chat_bubble_outline,
                title: 'Chưa có hội thoại',
                message: 'Các trao đổi trong task sẽ xuất hiện tại đây.',
                color: AppColors.primary,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: tasksWithMessages.length,
              itemBuilder: (context, index) {
                final doc = tasksWithMessages[index];
                final data = doc.data() as Map<String, dynamic>;
                final TaskEntity task = TaskModel.fromFirestore(doc);
                final lastMessage = data['lastMessage'] as String;
                final timestamp = data['lastMessageTime'] as Timestamp?;

                String timeString = '';
                if (timestamp != null) {
                  final date = timestamp.toDate();
                  timeString =
                      '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailScreen(
                              task: task,
                              initialTabIndex: 1,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              timeString,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _MessageState({
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
            Icon(icon, color: color, size: 52),
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
