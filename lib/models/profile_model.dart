class ProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String role; // 'tourist', 'influencer', 'admin'
  final bool isSuspended;

  ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.isSuspended = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'role': role,
    'is_suspended': isSuspended,
  };

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
    id: map['id'] ?? '',
    email: map['email'] ?? '',
    fullName: map['full_name'] ?? '',
    avatarUrl: map['avatar_url'],
    role: map['role'] ?? 'tourist',
    isSuspended: map['is_suspended'] ?? false,
  );
}
