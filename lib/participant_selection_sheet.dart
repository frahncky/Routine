import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/contacts/contact_group.dart';
import 'package:routine/features/contacts/contatos.dart';
import 'package:routine/helper/database_helper.dart';

class ParticipantSelectionSheet extends StatefulWidget {
  const ParticipantSelectionSheet({
    super.key,
    required this.currentEmail,
    required this.existingEmails,
  });

  final String currentEmail;
  final Set<String> existingEmails;

  static Future<List<Participante>?> show({
    required BuildContext context,
    required String currentEmail,
    required Set<String> existingEmails,
  }) {
    return showModalBottomSheet<List<Participante>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ParticipantSelectionSheet(
        currentEmail: currentEmail,
        existingEmails: existingEmails,
      ),
    );
  }

  @override
  State<ParticipantSelectionSheet> createState() =>
      _ParticipantSelectionSheetState();
}

class _ParticipantSelectionSheetState extends State<ParticipantSelectionSheet> {
  final _emailController = TextEditingController();
  final _searchController = TextEditingController();
  final _selectedContactEmails = <String>{};
  final _selectedGroupIds = <int>{};
  final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  List<ContactGroup> _groups = [];
  String? _errorText;
  bool _loading = true;

  String get _currentEmail => widget.currentEmail.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final contacts = (await DB.instance.getAllContacts())
        .map(Contact.fromMap)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final groups = await DB.instance.getContactGroupsWithMembers();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _groups = groups;
      _filteredContacts = List<Contact>.from(contacts);
      _loading = false;
    });
  }

  void _setError(String message) {
    setState(() => _errorText = message);
  }

  void _clearError() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  String _displayNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return email;
    final cleaned = localPart.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return email;
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Participante _participantFromContact(Contact contact) {
    return Participante(
      nome: contact.name.trim().isEmpty ? 'Sem nome' : contact.name.trim(),
      email: contact.email.trim().toLowerCase(),
      fotoUrl: contact.avatarUrl.trim().isEmpty ? null : contact.avatarUrl,
      status: ParticipanteStatus.pendente,
    );
  }

  Participante _participantFromEmail(String email) {
    return Participante(
      nome: _displayNameFromEmail(email),
      email: email.trim().toLowerCase(),
      status: ParticipanteStatus.pendente,
    );
  }

  bool _isBlockedEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized == _currentEmail) return true;
    return widget.existingEmails.contains(normalized);
  }

  void _emitParticipants(List<Participante> participants) {
    final uniqueByEmail = <String, Participante>{};
    for (final participant in participants) {
      final email = participant.email.trim().toLowerCase();
      if (_isBlockedEmail(email)) continue;
      uniqueByEmail[email] = participant;
    }

    if (uniqueByEmail.isEmpty) {
      _setError('Nenhum novo participante foi adicionado.');
      return;
    }

    Navigator.of(context).pop(uniqueByEmail.values.toList());
  }

  void _filterContacts(String query) {
    final term = query.trim().toLowerCase();
    final filtered = term.isEmpty
        ? List<Contact>.from(_contacts)
        : _contacts
            .where((c) =>
                c.name.toLowerCase().contains(term) ||
                c.email.toLowerCase().contains(term))
            .toList();

    setState(() {
      _filteredContacts = filtered;
    });
  }

  void _addByEmail() {
    final email = _emailController.text.trim().toLowerCase();
    if (!_emailRegex.hasMatch(email)) {
      _setError('Informe um e-mail valido.');
      return;
    }
    if (email == _currentEmail) {
      _setError('Você não pode convidar seu próprio e-mail.');
      return;
    }
    if (widget.existingEmails.contains(email)) {
      _setError('Este participante ja foi adicionado.');
      return;
    }

    _clearError();
    final fromContact =
        _contacts.where((c) => c.email.trim().toLowerCase() == email);
    if (fromContact.isNotEmpty) {
      _emitParticipants([_participantFromContact(fromContact.first)]);
      return;
    }
    _emitParticipants([_participantFromEmail(email)]);
  }

  void _addBySelection() {
    final participants = <Participante>[];

    for (final email in _selectedContactEmails) {
      final matches =
          _contacts.where((c) => c.email.trim().toLowerCase() == email);
      if (matches.isNotEmpty) {
        participants.add(_participantFromContact(matches.first));
      }
    }

    for (final group
        in _groups.where((g) => _selectedGroupIds.contains(g.id))) {
      for (final member in group.members) {
        participants.add(_participantFromContact(member));
      }
    }

    if (participants.isEmpty) {
      _setError('Selecione ao menos um contato ou grupo.');
      return;
    }

    _clearError();
    _emitParticipants(participants);
  }

  Widget _buildSelectableList() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Buscar contato',
            prefixIcon: Icon(Icons.search),
          ),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          onChanged: _filterContacts,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              if (_groups.isNotEmpty) ...[
                Text(
                  'Grupos criados',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._groups.map((group) {
                  final selected = _selectedGroupIds.contains(group.id);
                  return CheckboxListTile(
                    value: selected,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(group.name),
                    subtitle: Text('${group.members.length} participantes'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedGroupIds.add(group.id);
                        } else {
                          _selectedGroupIds.remove(group.id);
                        }
                      });
                    },
                  );
                }),
                const Divider(height: 24),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Crie grupos na aba Contatos para eles aparecerem aqui.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Text(
                'Contatos da agenda',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_filteredContacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Nenhum contato encontrado.'),
                  ),
                )
              else
                ..._filteredContacts.map((contact) {
                  final email = contact.email.trim().toLowerCase();
                  final selected = _selectedContactEmails.contains(email);
                  return CheckboxListTile(
                    value: selected,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(contact.name),
                    subtitle: Text(contact.email),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedContactEmails.add(email);
                        } else {
                          _selectedContactEmails.remove(email);
                        }
                      });
                    },
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _addBySelection,
            icon: const Icon(Icons.group_add),
            label: const Text('Adicionar selecionados'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return DefaultTabController(
      length: 2,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Adicionar participantes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(text: 'Lista'),
                  Tab(text: 'E-mail'),
                ],
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: _buildSelectableList(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: const InputDecoration(
                                          labelText: 'Convidar por e-mail',
                                          hintText: 'exemplo@dominio.com',
                                          prefixIcon:
                                              Icon(Icons.alternate_email),
                                        ),
                                        onTapOutside: (_) =>
                                            FocusScope.of(context).unfocus(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _addByEmail,
                                      child: const Text('Adicionar'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      'Use a aba Lista para marcar grupos e contatos ja salvos na agenda.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
