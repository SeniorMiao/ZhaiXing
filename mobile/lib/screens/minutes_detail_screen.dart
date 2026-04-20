import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart';
import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import 'roadmap_placeholder_screen.dart';

class MinutesDetailScreen extends StatefulWidget {
  const MinutesDetailScreen({super.key, required this.meetingId});

  final int meetingId;

  @override
  State<MinutesDetailScreen> createState() => _MinutesDetailScreenState();
}

class _MinutesDetailScreenState extends State<MinutesDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  MeetingDetail? _meeting;
  MeetingSummary? _summary;
  MeetingTranscript? _transcript;

  bool _loading = true;
  String? _error;

  String? _localEditedSummary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await api.getMeeting(widget.meetingId);
      final s = await api.getSummary(widget.meetingId);
      final t = await api.getTranscript(widget.meetingId);
      if (!mounted) return;
      setState(() {
        _meeting = m;
        _summary = s;
        _transcript = t;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _displaySummary {
    final remote = (_summary?.summary ?? '').trim();
    final local = (_localEditedSummary ?? '').trim();
    if (local.isNotEmpty) return local;
    return remote;
  }

  Future<void> _editSummary() async {
    final ctrl = TextEditingController(text: _displaySummary);
    try {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('编辑纪要（本地）', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  minLines: 6,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: '纪要内容',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('保存'),
                ),
              ],
            ),
          );
        },
      );
      if (ok != true || !mounted) return;
      setState(() => _localEditedSummary = ctrl.text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到本地（未同步后端）')));
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _exportToClipboard() async {
    final m = _meeting;
    final s = _summary;
    if (m == null || s == null) return;

    final buf = StringBuffer();
    final title = m.title.trim().isEmpty ? '未命名会议' : m.title.trim();
    buf.writeln('标题：$title');
    buf.writeln('类型：${m.meetingType}');
    buf.writeln('状态：${m.status}');
    buf.writeln('');
    buf.writeln('【纪要】');
    final summaryText = _displaySummary;
    buf.writeln(summaryText.isEmpty ? '（空）' : summaryText);
    buf.writeln('');
    buf.writeln('【待办】');
    if (s.todos.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (final (i, t) in s.todos.indexed) {
        buf.writeln('${i + 1}. $t');
      }
    }
    buf.writeln('');
    buf.writeln('【决策】');
    if (s.decisions.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (final (i, d) in s.decisions.indexed) {
        buf.writeln('${i + 1}. $d');
      }
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = _meeting;
    final title = m == null
        ? '纪要 #${widget.meetingId}'
        : (m.title.trim().isEmpty ? '未命名会议' : m.title.trim());

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多',
            onSelected: (v) {
              if (v == 'progress') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapPlaceholderScreen(
                      title: '撰写进度详情',
                      body:
                          '后续可展示转码、ASR、摘要各阶段耗时与排队位置，并与后台任务 id 关联。',
                      icon: Icons.timelapse_outlined,
                    ),
                  ),
                );
              } else if (v == 'notify') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapPlaceholderScreen(
                      title: '通知消息',
                      body:
                          '对应原型「通知消息」。待接入站内信或推送后，可在此查看纪要完成、失败等事件。',
                      icon: Icons.notifications_none_outlined,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(value: 'progress', child: Text('撰写进度')),
              const PopupMenuItem<String>(value: 'notify', child: Text('通知消息')),
            ],
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: (_summary == null) ? null : _editSummary,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '导出（复制）',
            onPressed: (_summary == null) ? null : _exportToClipboard,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '纪要', icon: Icon(Icons.summarize_outlined)),
            Tab(text: '待办', icon: Icon(Icons.checklist_outlined)),
            Tab(text: '决策', icon: Icon(Icons.gavel_outlined)),
            Tab(text: '对话', icon: Icon(Icons.subject_outlined)),
          ],
        ),
      ),
      body: _loading && m == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && m == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: cs.error)),
                            const SizedBox(height: 12),
                            FilledButton.tonal(onPressed: _load, child: const Text('重试')),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildSummaryTab(),
                    _buildTodoTab(),
                    _buildDecisionTab(),
                    _buildTranscriptTab(),
                  ],
                ),
    );
  }

  Widget _buildSummaryTab() {
    final cs = Theme.of(context).colorScheme;
    final text = _displaySummary;
    if (text.trim().isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.description_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          Center(child: Text('纪要为空', style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '可能还在处理中，或摘要生成失败。\n你也可以先手动编辑一份本地纪要。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _summary == null ? null : _editSummary,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑纪要（本地）'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if ((_localEditedSummary ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.edit_note_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '当前显示的是本地编辑版本（未同步后端）',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoTab() {
    final s = _summary;
    final cs = Theme.of(context).colorScheme;
    if (s == null || s.todos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.checklist_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          const Center(child: Text('暂无待办')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: s.todos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final t = s.todos[i];
        return Card(
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              child: Text('${i + 1}'),
            ),
            title: Text(t),
          ),
        );
      },
    );
  }

  Widget _buildDecisionTab() {
    final s = _summary;
    final cs = Theme.of(context).colorScheme;
    if (s == null || s.decisions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.gavel_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          const Center(child: Text('暂无决策')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: s.decisions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final d = s.decisions[i];
        return Card(
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
              child: Text('${i + 1}'),
            ),
            title: Text(d),
          ),
        );
      },
    );
  }

  Widget _buildTranscriptTab() {
    final t = _transcript;
    final cs = Theme.of(context).colorScheme;
    if (t == null || t.segments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.subject_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          const Center(child: Text('暂无对话内容')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: t.segments.length,
      itemBuilder: (ctx, i) {
        final s = t.segments[i];
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(label: Text(s.speaker), visualDensity: VisualDensity.compact),
                    const SizedBox(width: 8),
                    Text('${_fmtMs(s.startMs)} - ${_fmtMs(s.endMs)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(s.text, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmtMs(int ms) {
    final s = (ms / 1000).floor();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

