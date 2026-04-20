class UserInfo {
  UserInfo({
    required this.id,
    required this.email,
    required this.nickname,
    this.hasAvatar = false,
  });

  final int id;
  final String? email;
  final String nickname;
  final bool hasAvatar;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as int,
      email: json['email'] as String?,
      nickname: json['nickname'] as String? ?? '用户',
      hasAvatar: json['has_avatar'] as bool? ?? false,
    );
  }
}

class AuthResult {
  AuthResult({required this.accessToken, required this.user});

  final String accessToken;
  final UserInfo user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['access_token'] as String,
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class MeetingItem {
  MeetingItem({
    required this.id,
    required this.title,
    required this.meetingType,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String meetingType;
  final String status;
  final String createdAt;

  factory MeetingItem.fromJson(Map<String, dynamic> json) {
    return MeetingItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      meetingType: json['meeting_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class MeetingDetail extends MeetingItem {
  MeetingDetail({
    required super.id,
    required super.title,
    required super.meetingType,
    required super.status,
    required super.createdAt,
    required this.updatedAt,
  });

  final String updatedAt;

  factory MeetingDetail.fromJson(Map<String, dynamic> json) {
    return MeetingDetail(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      meetingType: json['meeting_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class JobStatus {
  JobStatus({
    required this.id,
    required this.meetingId,
    required this.stage,
    required this.state,
    required this.progress,
    this.errorMessage,
  });

  final int id;
  final int meetingId;
  final String stage;
  final String state;
  final int progress;
  final String? errorMessage;

  factory JobStatus.fromJson(Map<String, dynamic> json) {
    return JobStatus(
      id: json['id'] as int,
      meetingId: json['meeting_id'] as int,
      stage: json['stage'] as String? ?? '',
      state: json['state'] as String? ?? '',
      progress: json['progress'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
    );
  }

  bool get isTerminal =>
      state == 'succeeded' || state == 'failed' || state == 'success' || state == 'error' || state == 'completed';

  bool get isSuccess => state == 'succeeded' || state == 'success' || state == 'completed';
}

class TranscriptSegment {
  TranscriptSegment({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.speaker,
    required this.text,
  });

  final int id;
  final int startMs;
  final int endMs;
  final String speaker;
  final String text;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      id: json['id'] as int,
      startMs: json['start_ms'] as int,
      endMs: json['end_ms'] as int,
      speaker: json['speaker'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

class MeetingTranscript {
  MeetingTranscript({required this.meetingId, required this.segments});

  final int meetingId;
  final List<TranscriptSegment> segments;

  factory MeetingTranscript.fromJson(Map<String, dynamic> json) {
    final list = json['segments'] as List<dynamic>? ?? [];
    return MeetingTranscript(
      meetingId: json['meeting_id'] as int,
      segments: list.map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MeetingSummary {
  MeetingSummary({
    required this.meetingId,
    this.summary,
    required this.todos,
    required this.decisions,
    this.modelVersion,
  });

  final int meetingId;
  final String? summary;
  final List<String> todos;
  final List<String> decisions;
  final String? modelVersion;

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      meetingId: json['meeting_id'] as int,
      summary: json['summary'] as String?,
      todos: (json['todos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      decisions: (json['decisions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      modelVersion: json['model_version'] as String?,
    );
  }
}
