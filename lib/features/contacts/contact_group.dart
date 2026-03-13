import 'package:routine/features/contacts/contatos.dart';

class ContactGroup {
  final int id;
  final String name;
  final List<Contact> members;

  const ContactGroup({
    required this.id,
    required this.name,
    required this.members,
  });
}
