class LocalUser  {
  final String name;
  final String email;
  final String avatarUrl;
  final String typeAccount;

  LocalUser ({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.typeAccount,
  });

  factory LocalUser .fromMap(Map<String, dynamic> map) {
    return LocalUser (
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      typeAccount: map['typeAccount'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'typeAccount': typeAccount,
    };
  }


  LocalUser copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    String? typeAccount,
    
  }) {
    return LocalUser(
      name: name ?? this.name,
      email: email ?? this.email,
       avatarUrl: avatarUrl ?? this.avatarUrl,
      typeAccount: typeAccount ?? this.typeAccount,
      
    );
  }
}
