import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:closetmate/core/navigation/app_router.dart';
import 'package:closetmate/core/theme/app_theme.dart';
import 'package:closetmate/data/services/api_config_service.dart';
import 'package:closetmate/data/services/app_lock_service.dart';
import 'package:closetmate/features/lock/screens/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 设置全局错误处理
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      print('FlutterError: ${details.exception}');
      print('Stack trace: ${details.stack}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      print('PlatformDispatcher error: $error');
      print('Stack trace: $stack');
      return true;
    };

    try {
      // 首次启动时写入默认 API Key
      await ApiConfigService.initDefaultKeys();
      runApp(const ProviderScope(child: ClosetMateApp()));
    } catch (error, stackTrace) {
      print('Error during app initialization: $error');
      print('Stack trace: $stackTrace');
      // 显示错误界面
      runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('应用启动失败', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 16),
                Text('错误: $error', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ));
    }
  }, (error, stack) {
    print('Uncaught error in zone: $error');
    print('Stack trace: $stack');
  });
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
    try {
      print('Checking app lock status...');
      // 添加超时，避免无限等待
      final locked = await AppLockService.isLockEnabled
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('Lock check timeout, assuming unlocked');
        return false;
      });
      print('Lock status: $locked');
      if (!mounted) return;
      setState(() {
        _isLocked = locked;
        _lockChecked = true;
      });
    } catch (error, stackTrace) {
      print('Error checking lock: $error');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLocked = false; // 出错时默认不锁定
        _lockChecked = true;
      });
    }
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
