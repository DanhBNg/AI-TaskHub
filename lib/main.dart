import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskhub_ai/presentation/state/project_bloc.dart';
import 'package:taskhub_ai/presentation/state/task_bloc.dart';
import 'firebase_options.dart';
import 'core/utils/injection_container.dart' as di;
import 'presentation/state/auth_bloc.dart';
import 'presentation/pages/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Khởi tạo Dependency Injection
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Cung cấp AuthBloc cho toàn bộ ứng dụng
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>(),
        ),
        BlocProvider<ProjectBloc>(create: (_) => di.sl<ProjectBloc>()),
        BlocProvider<TaskBloc>(create: (_) => di.sl<TaskBloc>()),
      ],
      child: MaterialApp(
        title: 'TaskHub AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
          useMaterial3: true,
        ),
        home: const LoginScreen(), // Mở app lên sẽ vào thẳng màn hình Login
      ),
    );
  }
}