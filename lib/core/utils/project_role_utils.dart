class ProjectRoleUtils {
  static String normalize(dynamic role) {
    return role?.toString().trim().toLowerCase() ?? '';
  }

  static bool isOwner({
    required String userId,
    required String ownerId,
    required Map<String, dynamic> roles,
  }) {
    return userId.isNotEmpty &&
        (userId == ownerId || normalize(roles[userId]) == 'owner');
  }

  static bool isLeader(dynamic role) {
    final normalized = normalize(role);
    return normalized == 'leader' || normalized == 'admin';
  }

  static bool canManageTasks({
    required String userId,
    required String ownerId,
    required Map<String, dynamic> roles,
  }) {
    return isOwner(userId: userId, ownerId: ownerId, roles: roles) ||
        isLeader(roles[userId]);
  }

  static String displayName({
    required String userId,
    required String ownerId,
    required Map<String, dynamic> roles,
  }) {
    if (isOwner(userId: userId, ownerId: ownerId, roles: roles)) {
      return 'Chủ dự án';
    }
    if (isLeader(roles[userId])) return 'Trưởng nhóm';
    return 'Thành viên';
  }
}
