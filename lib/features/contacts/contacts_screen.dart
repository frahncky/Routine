import 'package:flutter/material.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/contacts/contatos.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/widgets/show_snackbar.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> contacts = [];
  String search = '';
  String _currentPlan = PlanRules.gratis;

  bool get _isPersonalOnly => PlanRules.isPersonalAgendaOnly(_currentPlan);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final userMap = await DB.instance.getUser();
    final plan = PlanRules.normalize(userMap?['typeAccount']?.toString());

    if (PlanRules.isPersonalAgendaOnly(plan)) {
      if (!mounted) return;
      setState(() {
        _currentPlan = plan;
        contacts = [];
      });
      return;
    }

    final data = await DB.instance.getAllContacts();
    if (!mounted) return;
    setState(() {
      _currentPlan = plan;
      contacts = data.map((map) => Contact.fromMap(map)).toList();
    });
  }

  Future<void> _saveContact(Contact contact, {int? index}) async {
    if (contact.email.trim().isEmpty || contact.name.trim().isEmpty) {
      showSnackbar(
        title: 'Adicao de contato',
        message: 'Nome e e-mail sao obrigatorios.',
        backgroundColor: Colors.orange.shade300,
        icon: Icons.error,
      );
      return;
    }

    bool success;
    if (index == null) {
      success = await DB.instance.insertContact(contact.name.trim(), contact.email.trim());
    } else {
      success = await DB.instance.updateContact(contact.name.trim(), contact.email.trim());
    }

    if (success) {
      showSnackbar(
        title: 'Adicao de contato',
        message: 'Contato salvo com sucesso!',
        backgroundColor: Colors.green.shade300,
        icon: Icons.check_circle,
      );
      await _loadContacts();
    } else {
      showSnackbar(
        title: 'Adicao de contato',
        message: 'Contato nao encontrado no Routine.',
        backgroundColor: Colors.orange.shade300,
        icon: Icons.error,
      );
    }
  }

  Future<void> _deleteContact(int index) async {
    final contact = contacts[index];
    await DB.instance.deleteContact(contact.email);
    await _loadContacts();
  }

  void _showContactDialog({Contact? contact, int? index}) {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(contact == null ? 'Novo Contato' : 'Editar Contato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Salvar'),
            onPressed: () async {
              final newContact = Contact(
                name: nameController.text,
                email: emailController.text,
                avatarUrl: 'https://i.pravatar.cc/150?u=${emailController.text}',
              );
              Navigator.pop(context);
              await _saveContact(newContact, index: index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalPlanLocked() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 72, color: Colors.grey.shade600),
          const SizedBox(height: 14),
          const Text(
            'Agenda pessoal ativa',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Seu plano atual permite somente agenda pessoal. Para usar contatos e agenda colaborativa, migre para o Premium.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssinaturaScreen()),
              );
              await _loadContacts();
            },
            icon: const Icon(Icons.upgrade),
            label: const Text('Ver planos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = contacts
        .where((c) => c.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          const Divider(height: 2),
          if (_isPersonalOnly)
            Expanded(child: _buildPersonalPlanLocked())
          else ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) => setState(() => search = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, index) {
                  final contact = filtered[index];
                  final originalIndex = contacts.indexOf(contact);
                  return Dismissible(
                    key: ValueKey(contact.email),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteContact(originalIndex),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: contact.avatarUrl.isEmpty ||
                                contact.avatarUrl == 'https://i.pravatar.cc/150?u=default'
                            ? null
                            : NetworkImage(contact.avatarUrl),
                        child: contact.avatarUrl.isEmpty ||
                                contact.avatarUrl == 'https://i.pravatar.cc/150?u=default'
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(contact.name),
                      subtitle: Text(contact.email),
                      onTap: () => _showContactDialog(
                        contact: contact,
                        index: originalIndex,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _isPersonalOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _showContactDialog(),
              tooltip: 'Adicionar Contato',
              child: const Icon(Icons.person_add),
            ),
    );
  }
}
