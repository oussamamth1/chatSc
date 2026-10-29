class FriendProfile {
  final String username;
  final String status;
  final bool online;

  const FriendProfile({required this.username, required this.status, required this.online});

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      username: json['username'] as String,
      status: json['status'] as String? ?? '',
      online: json['online'] as bool? ?? false,
    );
  }
}
