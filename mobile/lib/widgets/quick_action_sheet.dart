import 'package:flutter/material.dart';

import '../screens/roadmap_placeholder_screen.dart';
import 'create_meeting_flow.dart';

/// 原型「点击加号」：新建会议、上传、录音等快捷入口（未实现的跳转占位说明）。
Future<void> showTabQuickActionsSheet(
  BuildContext context, {
  required Future<void> Function() onMeetingsChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('快捷操作', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('新建会议'),
              subtitle: const Text('创建后进入详情上传音频'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Future<void>.delayed(Duration.zero);
                if (!context.mounted) return;
                final created = await showCreateMeetingFlow(context);
                if (created) await onMeetingsChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('上传文件'),
              subtitle: const Text('需先选择或创建会议'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapPlaceholderScreen(
                      title: '上传文件',
                      body:
                          '当前请在「会议详情」内上传音频。后续若提供独立「文件中心」与跨会议上传能力，将迁移到此入口。',
                      icon: Icons.upload_file_outlined,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('实时录音'),
              subtitle: const Text('MVP 为会后上传，不采集实时流'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapPlaceholderScreen(
                      title: '实时录音',
                      body:
                          '原型含实时录音与边录边转能力；当前版本仅支持会后上传整段音频。若后续接入实时 ASR，将在此提供入口。',
                      icon: Icons.mic_none_outlined,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timelapse_outlined),
              title: const Text('撰写进度'),
              subtitle: const Text('查看处理流水线详情'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapPlaceholderScreen(
                      title: '撰写进度详情',
                      body:
                          '后续可对接任务各阶段（转码、识别、摘要等）的耗时与排队信息，并在会议详情中联动展示。',
                      icon: Icons.timelapse_outlined,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
