class Contact {
  final String name;
  final String email;
  final String avatarUrl;

  Contact({required this.name, required this.email, required this.avatarUrl});



Map<String, dynamic> toMap() =>
      {'name': name, 'email': email, 'avatarUrl': avatarUrl};

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      name: map['name']?.toString() ?? 'Sem nome',
      email: map['email']?.toString() ?? 'sememail@exemplo.com',
      avatarUrl:
          map['avatarUrl']?.toString() ?? 'https://i.pravatar.cc/150?u=default',
    );
  }

}