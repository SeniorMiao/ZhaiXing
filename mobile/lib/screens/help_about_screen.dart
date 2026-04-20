import 'package:flutter/material.dart';

class HelpAboutScreen extends StatelessWidget {
  const HelpAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于与帮助')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('使用提示', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  const Text('1. 创建会议后，在详情页上传音频并开始处理。'),
                  const SizedBox(height: 6),
                  const Text('2. 「纪要」页仅展示处理完成的会议。'),
                  const SizedBox(height: 6),
                  const Text('3. Android 模拟器访问本机 API 请使用 10.0.2.2，不要用 127.0.0.1。'),
                  const SizedBox(height: 6),
                  const Text('4. 首页与「会议」右下角 + 打开快捷菜单（对齐原型「点击加号」）；部分项待后续接入。'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于摘星'),
            subtitle: const Text('版本 0.1.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '摘星',
                applicationVersion: '0.1.0',
                applicationLegalese: '智能会议纪要助手',
                children: [
                  const SizedBox(height: 12),
                  Text(
                    '会后上传录音，服务端转写并生成纪要。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
