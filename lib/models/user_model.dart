class UserModel {
  final String uid;
  final String username;
  final String email;
  final String status; // 'pending' or 'active'
  final bool isGoogleUser;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.status,
    required this.isGoogleUser,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'status': status,
      'isGoogleUser': isGoogleUser,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      status: json['status'] ?? 'pending',
      isGoogleUser: json['isGoogleUser'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? status,
    bool? isGoogleUser,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      status: status ?? this.status,
      isGoogleUser: isGoogleUser ?? this.isGoogleUser,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
