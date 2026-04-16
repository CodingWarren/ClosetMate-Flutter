import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('穿搭统计')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatCard(
            title: '本月穿搭次数',
            value: '--',
            icon: Icons.calendar_month,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _StatCard(
            title: '最常穿品类',
            value: '--',
            icon: Icons.category_outlined,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          _StatCard(
            title: '闲置提醒',
            value: '--',
            icon: Icons.notifications_active_outlined,
            color: Colors.pink,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: const Text('统计能力迁移中'),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
