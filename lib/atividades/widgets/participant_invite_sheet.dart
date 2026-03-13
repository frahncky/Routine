import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/contacts/contact_group.dart';
import 'package:routine/features/contacts/contatos.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class ParticipantInviteSheet extends StatefulWidget {
  const ParticipantInviteSheet({
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
      builder: (_) => ParticipantInviteSheet(
        currentEmail: currentEmail,
        existingEmails: existingEmails,
      ),
    );
  }

  @override
  State<ParticipantInviteSheet> createState() => _ParticipantInviteSheetState();
}

class _ParticipantInviteSheetState extends State<ParticipantInviteSheet> {
  final _emailController = TextEditingController();
  final _searchIndividualController = TextEditingController();
  final _searchMultipleController = TextEditingController();

  final _selectedContactEmails = <String>{};
  final _selectedGroupIds = <int>{};
  final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  List<Contact> _contacts = [];
  List<Contact> _filteredIndividual = [];
  List<Contact> _filteredMultiple = [];
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
    _searchIndividualController.dispose();
    _searchMultipleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final contacts = (await DB.instance.getAllContacts()).map(Contact.fromMap).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final groups = await DB.instance.getContactGroupsWithMembers();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _groups = groups;
      _filteredIndividual = List<Contact>.from(contacts);
      _filteredMultiple = List<Contact>.from(contacts);
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
    final allowed = participants.where((p) => !_isBlockedEmail(p.email)).toList();
    if (allowed.isEmpty) {
      _setError('Nenhum novo participante foi adicionado.');
      return;
    }
    Navigator.of(context).pop(allowed);
  }

  void _filterContacts(String query, {required bool multiple}) {
    final term = query.trim().toLowerCase();
    final filtered = term.isEmpty
        ? List<Contact>.from(_contacts)
        : _contacts
            .where((c) =>
                c.name.toLowerCase().contains(term) ||
                c.email.toLowerCase().contains(term))
            .toList();

    setState(() {
      if (multiple) {
        _filteredMultiple = filtered;
      } else {
        _filteredIndividual = filtered;
      }
    });
  }

  void _addByEmail() {
    final email = _emailController.text.trim().toLowerCase();
    if (!_emailRegex.hasMatch(email)) {
      _setError('Informe um e-mail valido.');
      return;
    }
    if (email == _currentEmail) {
      _setError('Voce nao pode convidar seu proprio e-mail.');
      return;
    }
    if (widget.existingEmails.contains(email)) {
      _setError('Este participante ja foi adicionado.');
      return;
    }

    _clearError();
    final fromContact = _contacts.where((c) => c.email.trim().toLowerCase() == email);
    if (fromContact.isNotEmpty) {
      _emitParticipants([_participantFromContact(fromContact.first)]);
      return;
    }
    _emitParticipants([_participantFromEmail(email)]);
  }

  void _addBySingleContact(Contact contact) {
    final email = contact.email.trim().toLowerCase();
    if (email == _currentEmail) {
      _setError('Voce nao pode convidar seu proprio e-mail.');
      return;
    }
    if (widget.existingEmails.contains(email)) {
      _setError('Este participante ja foi adicionado.');
      return;
    }
    _clearError();
    _emitParticipants([_participantFromContact(contact)]);
  }

  void _addByMultiSelection() {
    if (_selectedContactEmails.isEmpty) {
      _setError('Selecione ao menos um contato.');
      return;
    }
    final participants = _selectedContactEmails
        .map((email) => _contacts.where((c) => c.email.trim().toLowerCase() == email))
        .where((matches) => matches.isNotEmpty)
        .map((matches) => _participantFromContact(matches.first))
        .toList();
    _clearError();
    _emitParticipants(participants);
  }

  void _addByGroups() {
    if (_selectedGroupIds.isEmpty) {
      _setError('Selecione ao menos um grupo.');
      return;
    }
    final selectedGroups = _groups.where((g) => _selectedGroupIds.contains(g.id));
    final participants = <Participante>[];
    for (final group in selectedGroups) {
      for (final member in group.members) {
        participants.add(_participantFromContact(member));
      }
    }
    _clearError();
    _emitParticipants(participants);
  }

  Future<bool> _showGroupEditorDialog({ContactGroup? group}) async {
    final nameController = TextEditingController(text: group?.name ?? '');
    final searchController = TextEditingController();
    final selectedEmails = group == null
        ? <String>{}
        : group.members.map((m) => m.email.trim().toLowerCase()).toSet();
    List<Contact> filtered = List<Contact>.from(_contacts);
    String? localError;
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(group == null ? 'Novo grupo' : 'Editar grupo'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.sizeOf(context).height * 0.62,
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome do grupo'),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar contato',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) {
                      setDialogState(() {
                        final term = value.trim().toLowerCase();
                        if (term.isEmpty) {
                          filtered = List<Contact>.from(_contacts);
                          return;
                        }
                        filtered = _contacts
                            .where((c) =>
                                c.name.toLowerCase().contains(term) ||
                                c.email.toLowerCase().contains(term))
                            .toList();
                      });
                    },
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        localError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Nenhum contato encontrado.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final contact = filtered[index];
                              final email = contact.email.trim().toLowerCase();
                              final checked = selectedEmails.contains(email);
                              return CheckboxListTile(
                                value: checked,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(contact.name),
                                subtitle: Text(contact.email),
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedEmails.add(email);
                                    } else {
                                      selectedEmails.remove(email);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final groupName = nameController.text.trim();
                  if (groupName.isEmpty) {
                    setDialogState(() {
                      localError = 'Informe um nome para o grupo.';
                    });
                    return;
                  }
                  if (selectedEmails.isEmpty) {
                    setDialogState(() {
                      localError = 'Selecione ao menos um contato.';
                    });
                    return;
                  }

                  try {
                    if (group == null) {
                      final id = await DB.instance.createContactGroup(
                        name: groupName,
                        memberEmails: selectedEmails.toList(),
                      );
                      if (id <= 0) {
                        setDialogState(() {
                          localError = 'Nao foi possivel criar o grupo.';
                        });
                        return;
                      }
                    } else {
                      final ok = await DB.instance.updateContactGroup(
                        groupId: group.id,
                        name: groupName,
                        memberEmails: selectedEmails.toList(),
                      );
                      if (!ok) {
                        setDialogState(() {
                          localError = 'Nao foi possivel atualizar o grupo.';
                        });
                        return;
                      }
                    }

                    saved = true;
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } on DatabaseException catch (e) {
                    setDialogState(() {
                      final msg = e.toString().toLowerCase();
                      localError = msg.contains('unique')
                          ? 'Ja existe um grupo com esse nome.'
                          : 'Erro ao salvar o grupo.';
                    });
                  } catch (_) {
                    setDialogState(() {
                      localError = 'Erro ao salvar o grupo.';
                    });
                  }
                },
                child: Text(group == null ? 'Criar grupo' : 'Salvar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      searchController.dispose();
    }
    return saved;
  }

  Future<void> _openGroupManager() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Grupos de participantes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Novo grupo',
                      icon: const Icon(Icons.group_add),
                      onPressed: () async {
                        final changed = await _showGroupEditorDialog();
                        if (!changed) return;
                        final refreshed = await DB.instance.getContactGroupsWithMembers();
                        if (!mounted) return;
                        setModalState(() {
                          _groups = refreshed;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _groups.isEmpty
                    ? const Center(child: Text('Nenhum grupo criado ainda.'))
                    : ListView.builder(
                        itemCount: _groups.length,
                        itemBuilder: (_, index) {
                          final group = _groups[index];
                          return ListTile(
                            title: Text(group.name),
                            subtitle: Text('${group.members.length} participantes'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final changed =
                                        await _showGroupEditorDialog(group: group);
                                    if (!changed) return;
                                    final refreshed = await DB.instance
                                        .getContactGroupsWithMembers();
                                    if (!mounted) return;
                                    setModalState(() {
                                      _groups = refreshed;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Excluir grupo'),
                                        content: Text(
                                          'Deseja excluir o grupo "${group.name}"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Excluir'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    await DB.instance.deleteContactGroup(group.id);
                                    final refreshed = await DB.instance
                                        .getContactGroupsWithMembers();
                                    if (!mounted) return;
                                    setModalState(() {
                                      _groups = refreshed;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    final refreshed = await DB.instance.getContactGroupsWithMembers();
    if (!mounted) return;
    setState(() {
      _groups = refreshed;
      _selectedGroupIds.removeWhere((id) => !_groups.any((g) => g.id == id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return DefaultTabController(
      length: 3,
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
                  Tab(text: 'Individual'),
                  Tab(text: 'Varios'),
                  Tab(text: 'Grupos'),
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
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: const InputDecoration(
                                          labelText: 'Convidar por e-mail',
                                          hintText: 'exemplo@dominio.com',
                                          prefixIcon: Icon(Icons.alternate_email),
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
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _searchIndividualController,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar contato',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  onChanged: (value) =>
                                      _filterContacts(value, multiple: false),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _filteredIndividual.isEmpty
                                      ? const Center(
                                          child: Text('Nenhum contato encontrado.'),
                                        )
                                      : ListView.builder(
                                          itemCount: _filteredIndividual.length,
                                          itemBuilder: (_, index) {
                                            final contact = _filteredIndividual[index];
                                            return ListTile(
                                              title: Text(contact.name),
                                              subtitle: Text(contact.email),
                                              onTap: () => _addBySingleContact(contact),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _searchMultipleController,
                                  decoration: const InputDecoration(
                                    labelText: 'Buscar contato',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  onChanged: (value) =>
                                      _filterContacts(value, multiple: true),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _filteredMultiple.isEmpty
                                      ? const Center(
                                          child: Text('Nenhum contato encontrado.'),
                                        )
                                      : ListView.builder(
                                          itemCount: _filteredMultiple.length,
                                          itemBuilder: (_, index) {
                                            final contact = _filteredMultiple[index];
                                            final email =
                                                contact.email.trim().toLowerCase();
                                            final selected =
                                                _selectedContactEmails.contains(email);
                                            return CheckboxListTile(
                                              value: selected,
                                              controlAffinity:
                                                  ListTileControlAffinity.leading,
                                              title: Text(contact.name),
                                              subtitle: Text(contact.email),
                                              onChanged: (value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selectedContactEmails.add(email);
                                                  } else {
                                                    _selectedContactEmails
                                                        .remove(email);
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _addByMultiSelection,
                                    icon: const Icon(Icons.group_add),
                                    label: const Text('Adicionar selecionados'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Convite por grupo',
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _openGroupManager,
                                      icon: const Icon(Icons.settings),
                                      label: const Text('Gerenciar'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _groups.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'Nenhum grupo criado. Use "Gerenciar".',
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _groups.length,
                                          itemBuilder: (_, index) {
                                            final group = _groups[index];
                                            final selected =
                                                _selectedGroupIds.contains(group.id);
                                            return CheckboxListTile(
                                              value: selected,
                                              controlAffinity:
                                                  ListTileControlAffinity.leading,
                                              title: Text(group.name),
                                              subtitle: Text(
                                                '${group.members.length} participantes',
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selectedGroupIds.add(group.id);
                                                  } else {
                                                    _selectedGroupIds
                                                        .remove(group.id);
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _addByGroups,
                                    icon: const Icon(Icons.groups),
                                    label: const Text('Adicionar por grupo'),
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
