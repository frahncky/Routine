class UserProfile {
  const UserProfile({
    required this.name,
    required this.avatarUrl,
    required this.revision,
  });

  final String name;
  final String? avatarUrl;
  final int revision;

  static const Object _unset = Object();

  UserProfile copyWith({
    String? name,
    Object? avatarUrl = _unset,
    int? revision,
  }) {
    return UserProfile(
      name: name ?? this.name,
      avatarUrl: avatarUrl == _unset ? this.avatarUrl : avatarUrl as String?,
      revision: revision ?? this.revision,
    );
  }
}
