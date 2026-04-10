import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.avatarUrl,
    super.systemRole,
  });

  // Hàm chuyển từ Firebase Document (JSON) sang Model
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      systemRole: data['systemRole'] ?? 'user',
    );
  }

  // Hàm chuyển từ Model thành JSON để đẩy lên Firestore
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'systemRole': systemRole,
      'createdAt': FieldValue.serverTimestamp(), // Tự động lấy giờ server
    };
  }
}