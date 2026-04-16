import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _SettingsTile(
            icon: Icons.lock_outline,
            title: '应用锁',
            subtitle: '生物识别 / PIN',
          ),
          _SettingsTile(
            icon: Icons.backup_outlined,
            title: '数据备份与恢复',
            subtitle: '导出本地数据文件',
          ),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'AI 服务配置',
            subtitle: 'Remove.bg / 百度 AI / 天气',
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: '主题与显示',
            subtitle: 'Material 3 风格保持一致',
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
