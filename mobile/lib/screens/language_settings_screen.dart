import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_controller.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LocaleController>();
    final mode = ctrl.modeLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('语言')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('跟随系统'),
            subtitle: const Text('根据设备语言在中文/英文间自动选择'),
            trailing: mode == 'system' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () => ctrl.setFollowSystem(),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('中文（简体）'),
            trailing: mode == 'zh' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () => ctrl.setChinese(),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('English'),
            trailing: mode == 'en' ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () => ctrl.setEnglish(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '界面语言会立即生效；偏好已写入本机。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
