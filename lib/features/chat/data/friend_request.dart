class FriendRequest {
  final String id;
  final String from;
  final DateTime createdAt;

  const FriendRequest({required this.id, required this.from, required this.createdAt});

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      from: json['from'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
