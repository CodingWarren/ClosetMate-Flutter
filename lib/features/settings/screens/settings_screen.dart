import 'package:closetmate/data/services/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lockEnabled = await AppLockService.isLockEnabled;
    final bioEnabled = await AppLockService.isBiometricEnabled;
    final bioAvailable = await AppLockService.isBiometricAvailable;
    if (!mounted) return;
    setState(() {
      _isLockEnabled = lockEnabled;
      _isBiometricEnabled = bioEnabled;
      _isBiometricAvailable = bioAvailable;
    });
  }

  Future<void> _enableLock() async {
    final pin = await _showPinSetupDialog();
    if (pin != null) {
      await AppLockService.setPin(pin);
      if (!mounted) return;
      setState(() => _isLockEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN 码已设置，应用锁已启用')),
      );
    }
  }

  Future<void> _disableLock() async {
    final verified = await _showPinVerifyDialog();
    if (verified) {
      await AppLockService.clearPin();
      if (!mounted) return;
      setState(() {
        _isLockEnabled = false;
        _isBiometricEnabled = false;
      });
    }
  }

  Future<void> _changePIN() async {
    final verified = await _showPinVerifyDialog();
    if (verified) {
      final newPin = await _showPinSetupDialog();
      if (newPin != null) {
        await AppLockService.setPin(newPin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN 码已更新')),
        );
      }
    }
  }

  Future<String?> _showPinSetupDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _PinSetupDialog(),
    );
  }

  Future<bool> _showPinVerifyDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _PinVerifyDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '我的',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息卡片
            Card(
              color: colorScheme.primaryContainer,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person,
                        color: colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的衣橱',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                        Text(
                          '本地数据，隐私安全',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 数据管理
            _SectionTitle(title: '数据管理'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.cloud_upload_outlined,
                    title: '备份数据',
                    subtitle: '将衣橱数据打包为 ZIP 文件',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('备份功能将在下一版本接入')),
                      );
                    },
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.cloud_download_outlined,
                    title: '恢复数据',
                    subtitle: '从备份 ZIP 文件恢复衣橱数据',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('恢复功能将在下一版本接入')),
                      );
                    },
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: '清空数据',
                    subtitle: '删除所有衣物和搭配记录',
                    titleColor: colorScheme.error,
                    onTap: () => _showClearDataDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 安全
            _SectionTitle(title: '安全'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  // 应用锁开关
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '应用锁',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _isLockEnabled ? '已启用 PIN 码保护' : '启用后需要 PIN 码或生物识别解锁',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isLockEnabled,
                          onChanged: (enabled) {
                            if (enabled) {
                              _enableLock();
                            } else {
                              _disableLock();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_isLockEnabled) ...[
                    const Divider(indent: 56, height: 1),
                    _SettingsTile(
                      icon: Icons.pin_outlined,
                      title: '修改 PIN 码',
                      subtitle: '更换当前 6 位 PIN 码',
                      onTap: _changePIN,
                    ),
                    if (_isBiometricAvailable) ...[
                      const Divider(indent: 56, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.fingerprint,
                              color: colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '生物识别解锁',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '使用指纹或面部识别解锁',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isBiometricEnabled,
                              onChanged: (enabled) async {
                                await AppLockService.setBiometricEnabled(enabled);
                                if (!mounted) return;
                                setState(() => _isBiometricEnabled = enabled);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 显示设置
            _SectionTitle(title: '显示设置'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: '主题颜色',
                    subtitle: '跟随系统',
                    onTap: () {},
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: '深色模式',
                    subtitle: '跟随系统',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 关于
            _SectionTitle(title: '关于'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: '关于 ClosetMate',
                    subtitle: '版本 1.0.0',
                    onTap: () => _showAboutDialog(),
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: '隐私说明',
                    subtitle: '所有数据仅存储在本地设备',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.checkroom,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        title: const Text('ClosetMate', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本：1.0.0'),
            SizedBox(height: 8),
            Text('一款简洁好用的衣橱管理应用，帮助你整理衣物、规划搭配、追踪穿着记录。'),
            SizedBox(height: 8),
            Text(
              '所有数据均存储在本地，不上传任何个人信息。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
        title: const Text('清空所有数据'),
        content: const Text('此操作将删除所有衣物和搭配记录，且无法恢复。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('清空功能将在下一版本接入')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

// ─── PIN 设置弹窗 ─────────────────────────────────────────────────────────────

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  int _step = 1;
  String _firstPin = '';
  final _ctrl = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
      title: Text(
        _step == 1 ? '设置 PIN 码' : '确认 PIN 码',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _step == 1 ? '请输入 6 位数字 PIN 码' : '请再次输入 PIN 码以确认',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'PIN 码',
              errorText: _errorMessage.isEmpty ? null : _errorMessage,
            ),
            onChanged: (_) => setState(() => _errorMessage = ''),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final pin = _ctrl.text;
            if (pin.length != 6) {
              setState(() => _errorMessage = 'PIN 码必须为 6 位数字');
              return;
            }
            if (_step == 1) {
              setState(() {
                _firstPin = pin;
                _ctrl.clear();
                _step = 2;
              });
            } else {
              if (pin == _firstPin) {
                Navigator.of(context).pop(pin);
              } else {
                setState(() {
                  _errorMessage = '两次输入不一致，请重试';
                  _ctrl.clear();
                  _step = 1;
                  _firstPin = '';
                });
              }
            }
          },
          child: Text(_step == 1 ? '下一步' : '确认'),
        ),
      ],
    );
  }
}

// ─── PIN 验证弹窗 ─────────────────────────────────────────────────────────────

class _PinVerifyDialog extends StatefulWidget {
  const _PinVerifyDialog();

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  final _ctrl = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.lock, color: Theme.of(context).colorScheme.primary),
      title: const Text('验证 PIN 码', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '请输入当前 PIN 码以继续',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'PIN 码',
              errorText: _errorMessage.isEmpty ? null : _errorMessage,
            ),
            onChanged: (_) => setState(() => _errorMessage = ''),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            final correct = await AppLockService.verifyPin(_ctrl.text);
            if (!mounted) return;
            if (correct) {
              nav.pop(true);
            } else {
              setState(() {
                _errorMessage = 'PIN 码错误，请重试';
                _ctrl.clear();
              });
            }
          },
          child: const Text('确认'),
        ),
      ],
    );
  }
}

// ─── 通用组件 ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveTitleColor = titleColor ?? colorScheme.onSurface;

    return ListTile(
      leading: Icon(
        icon,
        color: titleColor ?? colorScheme.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: effectiveTitleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 18,
      ),
      onTap: onTap,
    );
  }
}
