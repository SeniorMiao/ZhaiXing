import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../widgets/tab_shell_header.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';
import 'personal_info_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthController>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fixedTabHeader(
            context,
            title: '我的',
            expandedFooter: Text('账号、偏好与退出登录', style: tabShellSubtitleStyle(context)),
          ),
          Expanded(
            child: ListView(
              padding: TabShellTokens.contentPaddingAfterHeader.copyWith(bottom: 24),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const PersonalInfoScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          UserAvatar(
                            key: ValueKey<Object>('${user?.id}_${user?.hasAvatar}'),
                            user: user,
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.nickname ?? '用户', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(user?.email ?? '—', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('设置'),
                        subtitle: const Text('账号、会员与用量、语言、通知、文件等'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
