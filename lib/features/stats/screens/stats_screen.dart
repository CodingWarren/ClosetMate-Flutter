import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/repositories/outfit_repository.dart';
import 'package:flutter/material.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ClothingRepository _clothingRepo = ClothingRepository();
  final OutfitRepository _outfitRepo = OutfitRepository();

  bool _isLoading = true;
  int _totalClothing = 0;
  int _totalOutfits = 0;
  double _totalSpending = 0;
  List<Map<String, dynamic>> _categoryStats = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _clothingRepo.getTotalCount(),
      _outfitRepo.getTotalCount(),
      _clothingRepo.getTotalSpending(),
      _clothingRepo.getCategoryStats(),
    ]);

    if (!mounted) return;
    setState(() {
      _totalClothing = results[0] as int;
      _totalOutfits = results[1] as int;
      _totalSpending = results[2] as double;
      _categoryStats = (results[3] as List<Map<String, dynamic>>)
          .map((row) => {'category': row['category'] as String, 'count': row['count'] as int})
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '数据统计',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: '总览'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.checkroom,
                            label: '衣物总数',
                            value: '$_totalClothing',
                            unit: '件',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.style,
                            label: '搭配方案',
                            value: '$_totalOutfits',
                            unit: '套',
                          ),
                        ),
                      ],
                    ),
                    if (_totalSpending > 0) ...[
                      const SizedBox(height: 12),
                      _StatCard(
                        icon: Icons.attach_money,
                        label: '衣物总价值',
                        value: '¥${_totalSpending.toStringAsFixed(0)}',
                        unit: '',
                        fullWidth: true,
                      ),
                    ],
                    if (_categoryStats.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionTitle(title: '品类分布'),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ..._categoryStats.take(8).map((item) {
                                final count = item['count'] as int;
                                final pct = _totalClothing > 0
                                    ? count / _totalClothing
                                    : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _CategoryBar(
                                    category: item['category'] as String,
                                    count: count,
                                    percentage: pct,
                                  ),
                                );
                              }),
                              if (_categoryStats.length > 8)
                                Text(
                                  '还有 ${_categoryStats.length - 8} 个品类...',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_totalSpending > 0) ...[
                      const SizedBox(height: 24),
                      _SectionTitle(title: '消费分析'),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _SpendingRow(
                                label: '衣物总价值',
                                value: '¥${_totalSpending.toStringAsFixed(0)}',
                              ),
                              if (_totalClothing > 0) ...[
                                const SizedBox(height: 12),
                                _SpendingRow(
                                  label: '件均价格',
                                  value:
                                      '¥${(_totalSpending / _totalClothing).toStringAsFixed(0)}',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_totalClothing == 0) ...[
                      const SizedBox(height: 48),
                      Center(
                        child: Column(
                          children: [
                            const Text('📊', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text(
                              '还没有数据',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '先去衣橱添加衣物，统计数据就会出现在这里',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          unit,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.count,
    required this.percentage,
  });

  final String category;
  final int count;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pctInt = (percentage * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              '$count 件 ($pctInt%)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 6,
            backgroundColor: colorScheme.primaryContainer,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _SpendingRow extends StatelessWidget {
  const _SpendingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}
