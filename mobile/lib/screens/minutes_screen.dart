import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart';
import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import '../widgets/tab_shell_header.dart';
import 'minutes_detail_screen.dart';

/// 纪要：仅展示处理完成（ready）的会议，进入详情查看转写与摘要。
class MinutesScreen extends StatefulWidget {
  const MinutesScreen({super.key});

  @override
  State<MinutesScreen> createState() => _MinutesScreenState();
}

class _MinutesScreenState extends State<MinutesScreen> {
  List<MeetingItem> _items = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  /// `all` | `mine`（协作未上线时与全部数据源一致，仅展示说明）
  String _scopeTab = 'all';

  List<MeetingItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    bool hit(MeetingItem m) {
      final title = m.title.toLowerCase();
      final type = m.meetingType.toLowerCase();
      final created = m.createdAt.toLowerCase();
      return title.contains(q) || type.contains(q) || created.contains(q) || m.id.toString().contains(q);
    }

    return _items.where(hit).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.listMeetings();
      final ready = list.where((m) => m.status.toLowerCase() == 'ready').toList();
      if (mounted) setState(() => _items = ready);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fixedTabHeader(
            context,
            title: '纪要',
            expandedFooter: Text('已生成纪要的会议，点进查看纪要、待办与对话', style: tabShellSubtitleStyle(context)),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (!(_loading && _items.isEmpty) && _error == null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(TabShellTokens.horizontalPadding, 8, TabShellTokens.horizontalPadding, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'all',
                    label: Text('全部纪要'),
                    icon: Icon(Icons.list_alt_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'mine',
                    label: Text('我的纪要'),
                    icon: Icon(Icons.person_outline),
                  ),
                ],
                selected: {_scopeTab},
                onSelectionChanged: (s) => setState(() => _scopeTab = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(TabShellTokens.horizontalPadding, 12, TabShellTokens.horizontalPadding, 8),
              child: SearchBar(
                controller: _searchCtrl,
                hintText: '搜索标题、类型或会议 ID',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                ],
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final minH = (cons.maxHeight - 24).clamp(200.0, 800.0);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      TabShellTokens.horizontalPadding,
                      0,
                      TabShellTokens.horizontalPadding,
                      24,
                    ),
                    children: _buildMinutesScrollBody(context, cs, minH),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMinutesScrollBody(BuildContext context, ColorScheme cs, double minH) {
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
    if (_items.isEmpty) {
      return [
        SizedBox(
          height: minH,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: cs.outline),
                  const SizedBox(height: 16),
                  Text('暂无已生成纪要', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '会议处理完成后会出现在这里',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (_filtered.isEmpty) {
      return [
        SizedBox(
          height: minH,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_outlined, size: 64, color: cs.outline),
                  const SizedBox(height: 16),
                  Text('无匹配纪要', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '试试更换关键词，或清空搜索框',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    final out = <Widget>[];
    if (_scopeTab == 'mine') {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            color: cs.primaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '当前为个人空间，「我的纪要」与「全部纪要」列表一致；协作与共享上线后将按权限过滤。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface),
              ),
            ),
          ),
        ),
      );
    }
    for (final m in _filtered) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.summarize_outlined, color: cs.onPrimaryContainer),
              ),
              title: Text(m.title.isEmpty ? '未命名会议' : m.title),
              subtitle: Text('${m.meetingType} · ${m.createdAt}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => MinutesDetailScreen(meetingId: m.id),
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
}
