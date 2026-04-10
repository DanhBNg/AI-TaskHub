import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String avatarUrl;
  final String systemRole; 

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl = '',
    this.systemRole = 'user',
  });

  @override
  List<Object?> get props => [id, email, fullName, avatarUrl, systemRole];
}