import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart';
import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import '../widgets/create_meeting_flow.dart';
import '../widgets/quick_action_sheet.dart';
import '../widgets/tab_shell_header.dart';
import 'meeting_detail_screen.dart';
import 'roadmap_placeholder_screen.dart';

/// 首页：问候、快捷入口、最近会议。
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenMeetings,
    this.onOpenMinutes,
  });

  final VoidCallback? onOpenMeetings;
  final VoidCallback? onOpenMinutes;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MeetingItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.listMeetings();
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _readyCount => _items.where((m) => m.status.toLowerCase() == 'ready').length;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final cs = Theme.of(context).colorScheme;
    final recent = _items.take(5).toList();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fixedTabHeader(
            context,
            title: '摘星',
            expandedFooter: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  auth.user != null ? '你好，${auth.user!.nickname}' : '你好',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text('会后上传录音，一键生成转写与纪要', style: tabShellSubtitleStyle(context)),
              ],
            ),
          ),
          Padding(
            padding: TabShellTokens.contentPaddingAfterHeader,
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.event_note_outlined,
                    label: '会议',
                    value: '${_items.length}',
                    onTap: widget.onOpenMeetings,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.description_outlined,
                    label: '已生成纪要',
                    value: '$_readyCount',
                    onTap: widget.onOpenMinutes,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TabShellTokens.horizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final created = await showCreateMeetingFlow(context);
                      if (created && mounted) await _load();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('新建会议'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenMeetings,
                    icon: const Icon(Icons.list_alt),
                    label: const Text('全部会议'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(TabShellTokens.horizontalPadding, 16, TabShellTokens.horizontalPadding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('快捷入口', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.person_outline, size: 18),
                      label: const Text('我创建的'),
                      onPressed: () {
                        widget.onOpenMeetings?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('当前列表即你账号下的全部会议')),
                        );
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.groups_outlined, size: 18),
                      label: const Text('我参与的'),
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const RoadmapPlaceholderScreen(
                              title: '我参与的',
                              body:
                                  '协作与「参与他人会议」需后端成员关系与权限模型；当前仅支持个人空间下的会议。',
                              icon: Icons.groups_outlined,
                            ),
                          ),
                        );
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.category_outlined, size: 18),
                      label: const Text('按会议类型'),
                      onPressed: () {
                        widget.onOpenMeetings?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('在「会议」页可用类型标签筛选')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final minScrollH = (cons.maxHeight - 24).clamp(200.0, 800.0);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      TabShellTokens.horizontalPadding,
                      12,
                      TabShellTokens.horizontalPadding,
                      100,
                    ),
                    children: _buildHomeScrollBody(context, cs, recent, minScrollH),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTabQuickActionsSheet(context, onMeetingsChanged: _load),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildHomeScrollBody(
    BuildContext context,
    ColorScheme cs,
    List<MeetingItem> recent,
    double minH,
  ) {
    if (_loading && _items.isEmpty) {
      return [
        SizedBox(
          height: minH,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        SizedBox(
          height: minH,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(_error!, style: TextStyle(color: cs.error)),
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }
    if (recent.isEmpty) {
      return [
        SizedBox(
          height: minH,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 56, color: cs.outline),
                const SizedBox(height: 12),
                Text('还没有会议', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '创建会议后上传音频即可开始处理',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final out = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('最近会议', style: Theme.of(context).textTheme.titleMedium),
          TextButton(
            onPressed: widget.onOpenMeetings,
            child: const Text('查看更多'),
          ),
        ],
      ),
      const SizedBox(height: 8),
    ];
    for (final m in recent) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            child: ListTile(
              title: Text(m.title.isEmpty ? '未命名会议' : m.title),
              subtitle: Text('${m.meetingType} · ${_statusLabel(m.status)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => MeetingDetailScreen(meetingId: m.id),
                  ),
                );
                if (mounted) await _load();
              },
            ),
          ),
        ),
      );
    }
    return out;
  }

  static String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'ready':
        return '已完成';
      case 'processing':
      case 'queued':
        return '处理中';
      case 'failed':
        return '失败';
      case 'uploading':
        return '上传中';
      case 'created':
        return '待上传';
      default:
        return s;
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
