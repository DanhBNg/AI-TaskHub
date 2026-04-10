import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<User?> get authStateChanges;
  Future<UserModel> signInWithEmail(String email, String password);
  Future<UserModel> signUpWithEmail(String email, String password, String fullName);
  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({required this.firebaseAuth, required this.firestore});

  @override
  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    // 1. Đăng nhập bằng Firebase Auth
    final userCredential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Lấy thông tin user từ bảng USERS trên Firestore
    final doc = await firestore.collection('USERS').doc(userCredential.user!.uid).get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    } else {
      throw Exception('Không tìm thấy thông tin người dùng trong cơ sở dữ liệu');
    }
  }

  @override
  Future<UserModel> signUpWithEmail(String email, String password, String fullName) async {
    // 1. Tạo tài khoản mới trên Firebase Auth
    final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Tạo đối tượng Model để chuẩn bị lưu
    final newUser = UserModel(
      id: userCredential.user!.uid,
      email: email,
      fullName: fullName,
    );

    // 3. Lưu thông tin bổ sung (fullName, vai trò) vào bảng USERS trên Firestore
    await firestore.collection('USERS').doc(newUser.id).set(newUser.toJson());

    return newUser;
  }

  @override
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }
}