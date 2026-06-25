import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/ai_assistant_screen.dart';
import '../pages/dashboard_screen.dart';
import '../pages/login_screen.dart';
import '../pages/message_list_screen.dart';
import '../pages/profile_screen.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final int currentIndex;

  const AppDrawer({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: ValueKey(currentIndex),
      child: ListView(
        key: ValueKey('drawer-list-$currentIndex'),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('USERS')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const _DrawerHeaderShell(
                  name: 'Đang tải...',
                  email: '',
                  avatar: CircleAvatar(backgroundColor: Colors.white),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final email = userData['email'] ??
                  FirebaseAuth.instance.currentUser?.email ??
                  '';
              final displayName = userData['fullName'] ?? email.split('@')[0];
              final avatarUrl = userData['avatarUrl'];

              return _DrawerHeaderShell(
                name: displayName,
                email: email,
                avatar: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            index: 0,
            targetScreen: const DashboardScreen(),
          ),
          _buildMenuItem(
            context,
            icon: Icons.chat_bubble_outline,
            title: 'Tin nhắn',
            index: 1,
            targetScreen: const MessageListScreen(projectId: ''),
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
            icon: Icons.person_outline,
            title: 'Thông tin cá nhân',
            index: 3,
            targetScreen: const ProfileScreen(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    required Widget targetScreen,
  }) {
    final isSelected = currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        selectedTileColor: AppColors.surfaceAlt,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.muted,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.text,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        onTap: () {
          final drawerNavigator = Navigator.of(context);
          final pageNavigator = Navigator.of(context, rootNavigator: true);
          drawerNavigator.pop();

          if (isSelected) return;

          pageNavigator.pushReplacement(
            MaterialPageRoute(builder: (_) => targetScreen),
          );
        },
      ),
    );
  }
}

class _DrawerHeaderShell extends StatelessWidget {
  final String name;
  final String email;
  final Widget avatar;

  const _DrawerHeaderShell({
    required this.name,
    required this.email,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
