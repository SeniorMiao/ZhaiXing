import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import '../widgets/user_avatar.dart';

/// 个人信息（数据来自登录态；头像可上传/删除）。
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  bool _refreshing = false;
  bool _avatarBusy = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await context.read<AuthController>().refreshProfile();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pickAvatar() async {
    final auth = context.read<AuthController>();
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    final path = x.path;
    if (path.isEmpty) return;
    setState(() => _avatarBusy = true);
    try {
      final u = await auth.api.uploadAvatar(path);
      auth.applyUserInfo(u);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    final auth = context.read<AuthController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除头像'),
        content: const Text('将删除服务器上的头像文件，并恢复为默认首字头像。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('移除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _avatarBusy = true);
    try {
      final u = await auth.api.deleteAvatar();
      auth.applyUserInfo(u);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移除头像')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人信息'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      UserAvatar(
                        key: ValueKey<Object>('${user?.id}_${user?.hasAvatar}'),
                        user: user,
                        radius: 40,
                        onTap: _avatarBusy ? null : _pickAvatar,
                      ),
                      if (_avatarBusy)
                        Positioned.fill(
                          child: ClipOval(
                            child: ColoredBox(
                              color: Colors.black26,
                              child: Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _avatarBusy ? null : _pickAvatar,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('更换头像'),
                  ),
                  if (user?.hasAvatar == true)
                    TextButton.icon(
                      onPressed: _avatarBusy ? null : _removeAvatar,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('移除头像'),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '支持 JPEG / PNG / WebP，最大 2MB。点击头像或「更换头像」从相册选择。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(user?.nickname ?? '—', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '—', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('用户 ID'),
                  subtitle: Text(user == null ? '—' : '${user.id}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('邮箱'),
                  subtitle: Text(user?.email ?? '—'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('昵称'),
                  subtitle: Text(user?.nickname ?? '—'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '修改昵称需后端提供接口；头像已通过 /v1/auth/avatar 上传与删除。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
