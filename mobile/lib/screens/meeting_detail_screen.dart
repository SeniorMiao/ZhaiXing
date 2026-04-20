import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart' as m;
import '../providers/auth_controller.dart';
import '../services/api_service.dart';

class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({super.key, required this.meetingId});

  final int meetingId;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> with SingleTickerProviderStateMixin {
  m.MeetingDetail? _detail;
  m.MeetingTranscript? _transcript;
  m.MeetingSummary? _summary;
  String? _loadError;
  bool _loading = true;

  m.JobStatus? _job;
  Timer? _pollTimer;
  bool _busy = false;
  bool _autoProcessing = false;

  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _refreshDetail();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshDetail() async {
    final api = context.read<AuthController>().api;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final d = await api.getMeeting(widget.meetingId);
      final t = await api.getTranscript(widget.meetingId);
      final s = await api.getSummary(widget.meetingId);
      if (mounted) {
        setState(() {
          _detail = d;
          _transcript = t;
          _summary = s;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'mp4', 'webm'],
      withData: false,
    );
    if (pick == null || pick.files.isEmpty) return;
    final path = pick.files.single.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件路径')),
        );
      }
      return;
    }

    final api = context.read<AuthController>().api;
    setState(() {
      _busy = true;
      _autoProcessing = false;
    });
    try {
      final d = await api.uploadMedia(widget.meetingId, path);
      if (mounted) {
        setState(() => _detail = d);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传成功')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadAndProcess() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'mp4', 'webm'],
      withData: false,
    );
    if (pick == null || pick.files.isEmpty) return;
    final path = pick.files.single.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件路径')),
        );
      }
      return;
    }

    final api = context.read<AuthController>().api;
    setState(() {
      _busy = true;
      _autoProcessing = true;
      _job = null;
    });
    try {
      final d = await api.uploadMedia(widget.meetingId, path);
      if (!mounted) return;
      setState(() => _detail = d);
      final jobId = await api.processMeeting(widget.meetingId);
      _stopPoll();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollJob(jobId));
      await _pollJob(jobId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _autoProcessing = false;
        });
      }
    }
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _startProcess() async {
    final api = context.read<AuthController>().api;
    setState(() => _busy = true);
    try {
      final jobId = await api.processMeeting(widget.meetingId);
      _stopPoll();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollJob(jobId));
      await _pollJob(jobId);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollJob(int jobId) async {
    final api = context.read<AuthController>().api;
    try {
      final j = await api.getJob(jobId);
      if (!mounted) return;
      setState(() => _job = j);
      if (j.isTerminal) {
        _stopPoll();
        if (j.isSuccess) {
          await _refreshDetail();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('处理完成')));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(j.errorMessage ?? '处理失败')),
            );
          }
        }
      }
    } catch (e) {
      _stopPoll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && d == null
              ? Center(child: Text(_loadError!))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            cs.primary.withOpacity(0.16),
                            cs.surface,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                Expanded(
                                  child: Text(
                                    d == null ? '会议 #${widget.meetingId}' : (d.title.isEmpty ? '会议' : d.title),
                                    style: Theme.of(context).textTheme.titleLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _loading ? null : _refreshDetail,
                                  icon: const Icon(Icons.refresh),
                                  tooltip: '刷新',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (d != null)
                              Row(
                                children: [
                                  Chip(
                                    label: Text(d.meetingType),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text('状态：${d.status}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            if (_job != null) _buildJobCard(),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _busy ? null : _uploadAndProcess,
                                    child: Text(_autoProcessing ? '上传并处理…' : '上传并开始'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: _busy ? null : _pickAndUpload,
                                    child: const Text('仅上传'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: _busy ? null : _startProcess,
                              child: const Text('开始处理（已上传后使用）'),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 0, label: Text('转写'), icon: Icon(Icons.subject_outlined)),
                                ButtonSegment(value: 1, label: Text('纪要'), icon: Icon(Icons.summarize_outlined)),
                              ],
                              selected: {_tabs.index},
                              onSelectionChanged: (s) => setState(() => _tabs.index = s.first),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _buildTranscript(),
                          _buildSummary(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildJobCard() {
    final j = _job!;
    final cs = Theme.of(context).colorScheme;
    final pct = (j.progress.clamp(0, 100)) / 100.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: j.isTerminal ? 1 : pct,
                      strokeWidth: 6,
                    ),
                  ),
                  Text('${j.progress}%', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      j.isTerminal ? (j.isSuccess ? '处理完成' : '处理失败') : '处理中',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text('${j.stage} · ${j.state}', style: Theme.of(context).textTheme.bodySmall),
                    if (j.isTerminal && !j.isSuccess && (j.errorMessage ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(j.errorMessage!, style: TextStyle(color: cs.error)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranscript() {
    final t = _transcript;
    if (t == null || t.segments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Icon(Icons.notes_outlined, size: 64),
          SizedBox(height: 12),
          Center(child: Text('暂无转写内容')),
          SizedBox(height: 6),
          Center(child: Text('上传音频并开始处理后，这里会显示按时间排序的转写段落')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: t.segments.length,
      itemBuilder: (ctx, i) {
        final s = t.segments[i];
        final start = _fmtMs(s.startMs);
        final end = _fmtMs(s.endMs);
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
                    Text('$start - $end', style: Theme.of(context).textTheme.bodySmall),
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

  Widget _buildSummary() {
    final s = _summary;
    if (s == null) {
      return const Center(child: Text('暂无纪要'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (s.modelVersion != null) Text('模型：${s.modelVersion}', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(s.summary ?? '（无正文）', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        if (s.todos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('待办', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...s.todos.map(
            (e) => Card(
              elevation: 0,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.check_box_outline_blank),
                title: Text(e),
              ),
            ),
          ),
        ],
        if (s.decisions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('决策', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...s.decisions.map(
            (e) => Card(
              elevation: 0,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.gavel_outlined),
                title: Text(e),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _fmtMs(int ms) {
    final sec = ms ~/ 1000;
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
