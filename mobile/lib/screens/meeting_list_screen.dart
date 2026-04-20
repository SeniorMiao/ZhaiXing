import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart';
import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import '../widgets/create_meeting_flow.dart';
import '../widgets/quick_action_sheet.dart';
import '../widgets/tab_shell_header.dart';
import 'meeting_detail_screen.dart';

class MeetingListScreen extends StatefulWidget {
  const MeetingListScreen({super.key});

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  List<MeetingItem> _items = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _typeFilter;

  List<MeetingItem> get _filtered {
    Iterable<MeetingItem> it = _items;
    if (_typeFilter != null && _typeFilter!.isNotEmpty) {
      it = it.where((m) => m.meetingType == _typeFilter);
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return it.toList();
    bool hit(MeetingItem m) {
      final title = m.title.toLowerCase();
      final type = m.meetingType.toLowerCase();
      final st = m.status.toLowerCase();
      return title.contains(q) || type.contains(q) || st.contains(q) || m.id.toString().contains(q);
    }

    return it.where(hit).toList();
  }

  List<String> get _distinctTypes {
    final s = _items.map((m) => m.meetingType).where((t) => t.isNotEmpty).toSet().toList()..sort();
    return s;
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
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createMeeting() async {
    final created = await showCreateMeetingFlow(context);
    if (created && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fixedTabHeader(
            context,
            title: '会议',
            expandedFooter: Text('全部会议与处理状态', style: tabShellSubtitleStyle(context)),
          ),
          Padding(
            padding: TabShellTokens.contentPaddingAfterHeader.copyWith(bottom: 0),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: '搜索标题、类型、状态或会议 ID',
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
          if (!_loading && _error == null && _items.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(TabShellTokens.horizontalPadding, 8, TabShellTokens.horizontalPadding, 0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('全部类型'),
                      selected: _typeFilter == null,
                      onSelected: (_) => setState(() => _typeFilter = null),
                    ),
                  ),
                  ..._distinctTypes.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(t),
                        selected: _typeFilter == t,
                        onSelected: (sel) => setState(() => _typeFilter = sel ? t : null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final minH = (cons.maxHeight - 24).clamp(200.0, 800.0);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: TabShellTokens.listPadding,
                    children: _buildMeetingScrollBody(context, minH),
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

  List<Widget> _buildMeetingScrollBody(BuildContext context, double minH) {
    final cs = Theme.of(context).colorScheme;
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
    if (_items.isNotEmpty && _filtered.isEmpty) {
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
                  const SizedBox(height: 12),
                  Text('无符合条件的会议', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    _query.trim().isNotEmpty
                        ? '试试更换关键词，或清空搜索框'
                        : '当前类型下暂无会议，可切换「全部类型」',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
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
                  Icon(Icons.inbox_outlined, size: 72, color: cs.outline),
                  const SizedBox(height: 12),
                  Text('还没有会议', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  const Text('点击右下角 + 创建会议，然后上传音频开始处理'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _createMeeting, child: const Text('创建会议')),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      for (final m in _filtered) ...[
        Card(
          elevation: 0,
          child: ListTile(
            title: Text(m.title.isEmpty ? '未命名会议' : m.title),
            subtitle: Text('${m.meetingType} · ${m.status}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => MeetingDetailScreen(meetingId: m.id)),
              );
              _load();
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}
