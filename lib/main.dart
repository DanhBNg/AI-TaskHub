import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskhub_ai/presentation/state/ai_assistant_bloc.dart';
import 'package:taskhub_ai/presentation/state/attachment_bloc.dart';
import 'package:taskhub_ai/presentation/state/invite_bloc.dart';
import 'package:taskhub_ai/presentation/state/message_bloc.dart';
import 'package:taskhub_ai/presentation/state/profile_bloc.dart';
import 'package:taskhub_ai/presentation/state/project_bloc.dart';
import 'package:taskhub_ai/presentation/state/task_bloc.dart';
import 'package:taskhub_ai/presentation/theme/app_theme.dart';

import 'core/utils/injection_container.dart' as di;
import 'domain/entities/user_entity.dart';
import 'domain/repositories/auth_repository.dart';
import 'firebase_options.dart';
import 'presentation/pages/dashboard_screen.dart';
import 'presentation/pages/login_screen.dart';
import 'presentation/state/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
        BlocProvider<ProfileBloc>(create: (_) => di.sl<ProfileBloc>()),
        BlocProvider<ProjectBloc>(create: (_) => di.sl<ProjectBloc>()),
        BlocProvider<TaskBloc>(create: (_) => di.sl<TaskBloc>()),
        BlocProvider<AttachmentBloc>(create: (_) => di.sl<AttachmentBloc>()),
        BlocProvider<MessageBloc>(create: (_) => di.sl<MessageBloc>()),
        BlocProvider<AiAssistantBloc>(create: (_) => di.sl<AiAssistantBloc>()),
        BlocProvider<InviteBloc>(
          create: (_) => di.sl<InviteBloc>()..add(LoadInvites()),
        ),
      ],
      child: MaterialApp(
        title: 'TaskHub AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _StartupSplash(authRepository: di.sl<AuthRepository>()),
      ),
    );
  }
}

class _StartupSplash extends StatefulWidget {
  final AuthRepository authRepository;

  const _StartupSplash({required this.authRepository});

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return _AuthGate(authRepository: widget.authRepository);
    }

    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(32)),
                child: Image(
                  image: AssetImage('assets/branding/taskhub_logo.png'),
                  width: 124,
                  height: 124,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'TaskHub AI',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Quản lý dự án công nghệ cùng trợ lý AI',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  final AuthRepository authRepository;

  const _AuthGate({required this.authRepository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserEntity?>(
      stream: authRepository.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
