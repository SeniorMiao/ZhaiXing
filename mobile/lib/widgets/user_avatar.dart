import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart';
import '../providers/auth_controller.dart';

String _avatarLetter(String? nickname) {
  final s = (nickname ?? 'U').trim();
  if (s.isEmpty) return 'U';
  return String.fromCharCode(s.runes.first);
}

/// 用户头像：有 `hasAvatar` 时带 Token 拉取 `/v1/auth/avatar`，否则显示昵称首字。
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 22,
    this.onTap,
  });

  final UserInfo? user;
  final double radius;
  final VoidCallback? onTap;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id || oldWidget.user?.hasAvatar != widget.user?.hasAvatar) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final u = widget.user;
    if (!mounted || u == null || !u.hasAvatar) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final api = context.read<AuthController>().api;
      final data = await api.getMyAvatarBytes();
      if (!mounted) return;
      setState(() => _bytes = data);
    } catch (_) {
      if (mounted) setState(() => _bytes = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius;
    final u = widget.user;
    final d = 2 * r;

    Widget core;
    if (_loading && u?.hasAvatar == true && (_bytes == null || _bytes!.isEmpty)) {
      core = CircleAvatar(
        radius: r,
        child: SizedBox(
          width: r,
          height: r,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    } else if (_bytes != null && _bytes!.isNotEmpty) {
      core = ClipOval(
        child: Image.memory(
          _bytes!,
          width: d,
          height: d,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    } else {
      core = CircleAvatar(
        radius: r,
        child: Text(
          _avatarLetter(u?.nickname),
          style: TextStyle(fontSize: r * 0.72),
        ),
      );
    }

    if (widget.onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: d, height: d, child: core),
        ),
      );
    }
    return SizedBox(width: d, height: d, child: core);
  }
}
