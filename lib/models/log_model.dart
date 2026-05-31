class LogModel {
  final String id;
  final String type; // 'success' or 'failure'
  final String who;  // username or email
  final String action; // description of success or failure reason
  final DateTime when;

  LogModel({
    required this.id,
    required this.type,
    required this.who,
    required this.action,
    required this.when,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'who': who,
      'action': action,
      'when': when.toIso8601String(),
    };
  }

  factory LogModel.fromJson(Map<String, dynamic> json) {
    return LogModel(
      id: json['id'] ?? '',
      type: json['type'] ?? 'success',
      who: json['who'] ?? 'unknown',
      action: json['action'] ?? '',
      when: json['when'] != null ? DateTime.parse(json['when']) : DateTime.now(),
    );
  }
}
