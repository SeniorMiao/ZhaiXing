import 'package:flutter/material.dart';

class NotificationPlaceholderScreen extends StatelessWidget {
  const NotificationPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.notifications_off_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('通知中心（待接入）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '后续可对接服务端推送或站内消息摘要完成、处理失败等事件。',
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
