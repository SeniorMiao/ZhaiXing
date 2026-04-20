import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import '../screens/meeting_detail_screen.dart';

/// 弹出新建会议表单，创建成功后跳转详情页；返回 `true` 表示已创建并关闭详情返回。
Future<bool> showCreateMeetingFlow(BuildContext context) async {
  final typeCtrl = TextEditingController(text: 'internal');
  final titleCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  try {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('新建会议', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '会议标题（可选）',
                    prefixIcon: Icon(Icons.title),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: '会议类型',
                    hintText: 'internal / interview / ...',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? '请输入会议类型' : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    final v = formKey.currentState?.validate() ?? false;
                    if (v) Navigator.pop(ctx, true);
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final v = formKey.currentState?.validate() ?? false;
                    if (!v) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('创建'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true || !context.mounted) return false;

    final api = context.read<AuthController>().api;
    try {
      final m = await api.createMeeting(
        meetingType: typeCtrl.text.trim(),
        title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
      );
      if (!context.mounted) return false;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => MeetingDetailScreen(meetingId: m.id)),
      );
      return true;
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    }
  } finally {
    typeCtrl.dispose();
    titleCtrl.dispose();
  }
}
