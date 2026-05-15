import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/ai_assistant_screen.dart';
import '../pages/dashboard_screen.dart';
import '../pages/login_screen.dart';
import '../pages/message_list_screen.dart';
import '../pages/profile_screen.dart';

class AppDrawer extends StatelessWidget {
  final int currentIndex;

  const AppDrawer({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('USERS')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const UserAccountsDrawerHeader(
                  decoration: BoxDecoration(color: Colors.blueAccent),
                  accountName: Text('Đang tải...'),
                  accountEmail: Text(''),
                  currentAccountPicture: CircleAvatar(backgroundColor: Colors.white),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
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
                  child: avatarUrl == null
                      ? Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent))
                      : null,
                ),
              );
            },
          ),

          // các nút chức năng
          _buildMenuItem(
            context,
            icon: Icons.dashboard,
            title: 'Dashboard',
            index: 0,
            targetScreen: const DashboardScreen(),
          ),

          _buildMenuItem(
            context,
            icon: Icons.chat_bubble,
            title: 'Tin nhắn',
            index: 1,
            targetScreen: const MessageListScreen(projectId: '',),
          ),

          _buildMenuItem(
            context,
            icon: Icons.auto_awesome,
            title: 'Trợ lý AI', 
            index: 2,
            targetScreen: const AiAssistantScreen(),
          ),

          _buildMenuItem(
            context,
            icon: Icons.person,
            title: 'Thông tin cá nhân',
            index: 3,
            targetScreen: const ProfileScreen(),
          ),

          const Divider(),

          // log out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required int index, required Widget targetScreen}) {
    final isSelected = currentIndex == index;

    return ListTile(
      selected: isSelected,
      selectedTileColor: Colors.blue.shade50,
      leading: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey.shade600),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blueAccent : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context);

        if (!isSelected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => targetScreen),
          );
        }
      },
    );
  }
}
