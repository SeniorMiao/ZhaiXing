import 'package:flutter/material.dart';

/// 原型中有入口、但当前后端/产品尚未实现的功能说明页。
class RoadmapPlaceholderScreen extends StatelessWidget {
  const RoadmapPlaceholderScreen({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.construction_outlined,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 56, color: cs.outline),
            const SizedBox(height: 20),
            Text('功能开发中', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}
