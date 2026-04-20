import 'package:flutter/material.dart';

/// 原型「我的文件」：服务端暂无独立文件库接口时占位。
class MyFilesPlaceholderScreen extends StatelessWidget {
  const MyFilesPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的文件')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('我的文件（待接入）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '当前音频随会议上传并保存在服务端存储；后续若提供「文件中心」列表接口，可在此统一浏览与管理。',
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
