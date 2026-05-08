import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<UserEntity?> get authStateChanges {
    return remoteDataSource.authStateChanges.map((firebaseUser) {
      if (firebaseUser == null) return null;
      return UserEntity(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        fullName: firebaseUser.displayName ?? 'Người dùng',
      );
    });
  }

  @override
  Future<UserEntity> signInWithEmail(String email, String password) async {
    try {
      return await remoteDataSource.signInWithEmail(email, password);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleFirebaseAuthError(e.code));
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  @override
  Future<UserEntity> signUpWithEmail({required String email, required String password, required String fullName}) async {
    try {
      return await remoteDataSource.signUpWithEmail(email, password, fullName);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleFirebaseAuthError(e.code));
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  String _handleFirebaseAuthError(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại.';
      case 'wrong-password':
        return 'Sai mật khẩu.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu.';
      default:
        return 'Lỗi đăng nhập: $errorCode';
    }
  }
}