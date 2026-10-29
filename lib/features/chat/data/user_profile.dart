class UserProfile {
  final String username;
  final String status;
  final bool online;

  const UserProfile({required this.username, required this.status, this.online = false});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] as String,
      status: json['status'] as String? ?? '',
      online: json['online'] as bool? ?? false,
    );
  }
}
