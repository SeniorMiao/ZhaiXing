import 'package:flutter/material.dart';

/// 原型「回收站」：需后端软删除与恢复接口。
class RecycleBinPlaceholderScreen extends StatelessWidget {
  const RecycleBinPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.delete_outline, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('回收站（待接入）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '需要服务端支持会议软删除、恢复与彻底清理后，才能在此展示已删除项目。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
