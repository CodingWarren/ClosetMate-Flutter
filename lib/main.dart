import 'package:closetmate/core/navigation/app_router.dart';
import 'package:closetmate/core/theme/app_theme.dart';
import 'package:closetmate/data/services/api_config_service.dart';
import 'package:closetmate/data/services/app_lock_service.dart';
import 'package:closetmate/features/lock/screens/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 首次启动时写入默认 API Key
  await ApiConfigService.initDefaultKeys();
  runApp(const ProviderScope(child: ClosetMateApp()));
}

class ClosetMateApp extends StatefulWidget {
  const ClosetMateApp({super.key});

  @override
  State<ClosetMateApp> createState() => _ClosetMateAppState();
}

class _ClosetMateAppState extends State<ClosetMateApp> {
  bool _isLocked = false;
  bool _lockChecked = false;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final locked = await AppLockService.isLockEnabled;
    if (!mounted) return;
    setState(() {
      _isLocked = locked;
      _lockChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_lockChecked) {
      // 检查锁状态期间显示启动画面
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_isLocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: LockScreen(
          onUnlocked: () {
            setState(() => _isLocked = false);
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'ClosetMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
