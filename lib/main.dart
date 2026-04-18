import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:closetmate/core/navigation/app_router.dart';
import 'package:closetmate/core/theme/app_theme.dart';
import 'package:closetmate/data/services/api_config_service.dart';
import 'package:closetmate/data/services/app_lock_service.dart';
import 'package:closetmate/data/services/image_path_fixer.dart';
import 'package:closetmate/features/lock/screens/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
      // 加载 .env 文件（必须在 initDefaultKeys 之前）
      await dotenv.load(fileName: '.env');
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
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 并行执行锁定检查和图片路径修复，两者都完成后再展示主界面
    // 这样可以确保 closet controller 加载数据时路径已经修复好
    final lockFuture = _performLockCheck();
    final pathFixFuture = _performPathFix();

    final locked = await lockFuture;
    await pathFixFuture;

    if (!mounted) return;
    setState(() {
      _isLocked = locked;
      _ready = true;
    });
  }

  Future<bool> _performLockCheck() async {
    try {
      print('Checking app lock status...');
      final locked = await AppLockService.isLockEnabled
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('Lock check timeout, assuming unlocked');
        return false;
      });
      print('Lock status: $locked');
      return locked;
    } catch (error, stackTrace) {
      print('Error checking lock: $error');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> _performPathFix() async {
    try {
      print('Checking if image path fix is needed...');
      final needsFix = await ImagePathFixer.needsFix();
      if (needsFix) {
        print('Running image path fix...');
        final fixedCount = await ImagePathFixer.fixAllImagePaths();
        print('Image path fix completed: $fixedCount items fixed');
      } else {
        print('Image paths are OK, no fix needed');
      }
    } catch (e) {
      print('Error running image path fix: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
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
