import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/task_entity.dart';
import '../../data/models/task_model.dart';
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
      body: StreamBuilder<QuerySnapshot>(
        stream: projectId != null
            ? FirebaseFirestore.instance
            .collection('TASKS')
            .where('projectId', isEqualTo: projectId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots()
            : FirebaseFirestore.instance
            .collection('TASKS')
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Lỗi Firebase: ${snapshot.error}');
            return Center(
                child: Text('Lỗi: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center)
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Chưa có đoạn hội thoại nào.'));
          }

          //chỉ lấy những Task có tin nhắn
          final tasksWithMessages = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data.containsKey('lastMessage') && data['lastMessage'] != null;
          }).toList();

          if (tasksWithMessages.isEmpty) {
            return const Center(child: Text('Chưa có đoạn hội thoại nào.'));
          }

          return ListView.builder(
            itemCount: tasksWithMessages.length,
            itemBuilder: (context, index) {
              final doc = tasksWithMessages[index];
              final data = doc.data() as Map<String, dynamic>;

              // Map document sang TaskEntity
              final TaskEntity task = TaskModel.fromFirestore(doc);

              final lastMessage = data['lastMessage'] as String;
              final timestamp = data['lastMessageTime'] as Timestamp?;

              String timeString = '';
              if (timestamp != null) {
                final date = timestamp.toDate();
                timeString = '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                  ),
                  title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  trailing: Text(timeString, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}