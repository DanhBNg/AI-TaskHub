import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taskhub_ai/presentation/pages/profile_screen.dart';
import '../../domain/entities/invite_entity.dart';
import '../state/invite_bloc.dart';
import '../state/project_bloc.dart';
import 'create_project_screen.dart';
import 'kanban_board_screen.dart';
import 'login_screen.dart';

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
        title: const Text('Danh sách Dự án'),
        actions: [
          BlocBuilder<InviteBloc, InviteState>(
              builder: (context, state) {
                int count = 0;
                if (state is InviteLoaded) count = state.invites.length;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        if (count == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có thông báo nào')));
                        } else {
                          _showInvitesDialog(context, (state as InviteLoaded).invites);
                        }
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 8, top: 8,
                        child: CircleAvatar(
                          radius: 8, backgroundColor: Colors.red,
                          child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                  ],
                );
              }
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Phần 1: Header chứa Avatar và Tên (Đã thêm StreamBuilder để tự cập nhật)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('USERS')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                // Đang tải hoặc lỗi thì hiện khung trống mặc định
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const UserAccountsDrawerHeader(
                    decoration: BoxDecoration(color: Colors.blueAccent),
                    accountName: Text('Đang tải...'),
                    accountEmail: Text(''),
                    currentAccountPicture: CircleAvatar(backgroundColor: Colors.white),
                  );
                }

                // Đã có dữ liệu từ bảng USERS
                final userData = snapshot.data!.data() as Map<String, dynamic>;

                // Ưu tiên lấy Tên trong Database -> Nếu không có thì lấy tên Email trước @
                final email = userData['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
                final displayName = userData['fullName'] ?? email.split('@')[0];
                final avatarUrl = userData['avatarUrl'];

                return UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Colors.blueAccent),
                  accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  accountEmail: Text(email),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    // Ảnh trắng + chữ cái đầu viết hoa
                    child: avatarUrl == null
                        ? Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    )
                        : null,
                  ),
                );
              },
            ),

            // Phần 2: Các nút chức năng
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blue),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context); // Đóng menu trượt
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: const Text('Thông tin cá nhân'),
              onTap: () {
                Navigator.pop(context); // Đóng menu
                // Chuyển sang màn hình Profile
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
            const Divider(), // Đường kẻ ngang phân cách
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  // Chuyển về màn hình Login (Nhớ import LoginScreen nếu chưa có)
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            ),
          ],
        ),
      ),
      body: BlocBuilder<ProjectBloc, ProjectState>(
        builder: (context, state) {
          // 1. Trạng thái đang tải dữ liệu
          if (state is ProjectLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Trạng thái Firebase báo lỗi (như chưa tạo xong Index)
          else if (state is ProjectError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Lỗi: ${state.message}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          // 3. Trạng thái đã tải xong dữ liệu thành công
          else if (state is ProjectLoaded) {

            // Xử lý khi chưa có dự án
            if (state.projects.isEmpty) {
              return const Center(
                child: Text(
                  'Bạn chưa tham gia dự án nào',
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              );
            }

            // Xử lý khi đã có dự án
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.projects.length,
              itemBuilder: (context, index) {
                final project = state.projects[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(project.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                );
              },
            );
          }

          // Trạng thái dự phòng
          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProjectScreen()));
        },
        child: const Icon(Icons.add),
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
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: invites.length,
                    itemBuilder: (context, index) {
                      final invite = invites[index];
                      return ListTile(
                          title: Text(invite.projectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${invite.senderName} đã mời bạn'),
                          trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                    onPressed: () {
                                      context.read<InviteBloc>().add(RespondToInvite(invite.inviteId, invite.projectId, true));
                                      Navigator.pop(ctx);
                                    }
                                ),
                                IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                                    onPressed: () {
                                      context.read<InviteBloc>().add(RespondToInvite(invite.inviteId, invite.projectId, false));
                                      Navigator.pop(ctx);
                                    }
                                ),
                              ]
                          )
                      );
                    }
                )
            )
        )
    );
  }
}