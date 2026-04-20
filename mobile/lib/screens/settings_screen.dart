import 'package:flutter/material.dart';

import 'help_about_screen.dart';
import 'language_settings_screen.dart';
import 'my_files_placeholder_screen.dart';
import 'notification_placeholder_screen.dart';
import 'personal_info_screen.dart';
import 'recycle_bin_placeholder_screen.dart';
import 'roadmap_placeholder_screen.dart';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// 设置：对齐原型入口；未实现能力跳转统一占位说明。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('账号与安全'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('个人信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const PersonalInfoScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_reset_outlined),
            title: const Text('找回密码'),
            subtitle: const Text('待接入邮件/短信验证流程'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '找回密码',
                    body:
                        '原型含邮箱/手机找回。当前后端未提供重置密码接口，请继续使用本地测试账号或联系管理员重置。',
                    icon: Icons.lock_reset_outlined,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('账号注销'),
            subtitle: const Text('待接入合规注销流程'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '账号注销',
                    body:
                        '需后端提供身份校验、数据保留策略与冷静期等能力后再开放此入口。',
                    icon: Icons.person_off_outlined,
                  ),
                ),
              );
            },
          ),
          const _SectionHeader('偏好与连接'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const LanguageSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('通知中心'),
            subtitle: const Text('待接入服务端'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const NotificationPlaceholderScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('通知设置'),
            subtitle: const Text('推送开关、免打扰等'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '通知设置',
                    body:
                        '原型含推送与免打扰。当前无推送通道，待接入服务端配置与用户偏好存储后再实现。',
                    icon: Icons.tune_outlined,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: const Text('离线模式'),
            subtitle: const Text('弱网/离线可用性'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '离线模式',
                    body:
                        '后续可缓存最近纪要、排队上传与失败重试；当前需保持网络以访问 API。',
                    icon: Icons.cloud_off_outlined,
                  ),
                ),
              );
            },
          ),
          const _SectionHeader('会员与用量'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('会员中心'),
            subtitle: const Text('权益与订阅，待产品接入'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '会员中心',
                    body:
                        '对应原型「会员中心 / 点击会员后的页面」。当前为课程演示环境，不包含计费与权益体系。',
                    icon: Icons.workspace_premium_outlined,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('用量统计'),
            subtitle: const Text('转写时长、摘要次数等'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '用量统计',
                    body:
                        '对应原型「用量统计」。需后端聚合用量与配额后再展示图表与导出。',
                    icon: Icons.bar_chart_outlined,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('模型参数微调'),
            subtitle: const Text('术语表、风格偏好等'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '模型参数微调',
                    body:
                        '对应原型「模型参数微调」。后续可对接团队术语、摘要风格与 ASR 热词等高级配置。',
                    icon: Icons.auto_awesome_outlined,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.upgrade_outlined),
            title: const Text('升级方案'),
            subtitle: const Text('对应原型「点击升级后」'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RoadmapPlaceholderScreen(
                    title: '升级方案',
                    body:
                        '占位说明：正式商业化后将在此展示套餐对比与支付入口。',
                    icon: Icons.upgrade_outlined,
                  ),
                ),
              );
            },
          ),
          const _SectionHeader('数据与文件'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('我的文件'),
            subtitle: const Text('待接入服务端'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const MyFilesPlaceholderScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('回收站'),
            subtitle: const Text('待接入服务端'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const RecycleBinPlaceholderScreen()),
              );
            },
          ),
          const _SectionHeader('帮助'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('关于与帮助'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const HelpAboutScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
