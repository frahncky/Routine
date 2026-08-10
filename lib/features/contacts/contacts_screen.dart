import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/assinatura/widgets/plan_locked_card.dart';
import 'package:routine/features/contacts/contact_group.dart';
import 'package:routine/features/contacts/contatos.dart';
import 'package:routine/features/contacts/widgets/group_editor_dialog.dart';
import 'package:routine/features/convites/convites_screen.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/theme/app_semantic_colors.dart';
import 'package:routine/widgets/app_background.dart';
import 'package:routine/widgets/confirm_dialog.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:sqflite/sqflite.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  List<Contact> contacts = [];
  List<ContactGroup> groups = [];
  String search = '';
  String _currentPlan = PlanRules.gratuito;
  int _pendingInvitesCount = 0;

  bool get _isPersonalOnly => PlanRules.isPersonalAgendaOnly(_currentPlan);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final userMap = await DB.instance.getUser();
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    final plan = PlanAccess.effectivePlan(
      isSignedIn: isSignedIn,
      storedPlan: userMap?['typeAccount']?.toString(),
    );

    if (PlanRules.isPersonalAgendaOnly(plan)) {
      if (!mounted) return;
      setState(() {
        _currentPlan = plan;
        _pendingInvitesCount = 0;
        contacts = [];
        groups = [];
      });
      return;
    }

    final data = await DB.instance.getAllContacts();
    final loadedGroups = await DB.instance.getContactGroupsWithMembers();
    final invites = await DB.instance.getPendingActivityInvites();
    if (!mounted) return;
    setState(() {
      _currentPlan = plan;
      _pendingInvitesCount = invites.length;
      contacts = data.map((map) => Contact.fromMap(map)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      groups = loadedGroups;
    });
  }

  Future<void> _openInvites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConvitesScreen()),
    );
    await _loadContacts();
  }

  Future<void> _saveContact(Contact contact, {int? index}) async {
    if (_isPersonalOnly) {
      showSnackbar(
        context: context,
        title: 'Plano atual',
        message: 'Seu plano permite apenas agenda pessoal.',
        variant: SnackbarVariant.warning,
        icon: Icons.info_outline,
      );
      return;
    }

    if (contact.email.trim().isEmpty || contact.name.trim().isEmpty) {
      showSnackbar(
        context: context,
        title: 'Adicao de contato',
        message: 'Nome e e-mail sao obrigatorios.',
        variant: SnackbarVariant.warning,
        icon: Icons.error,
      );
      return;
    }

    bool success;
    if (index == null) {
      success = await DB.instance
          .insertContact(contact.name.trim(), contact.email.trim());
    } else {
      success = await DB.instance
          .updateContact(contact.name.trim(), contact.email.trim());
    }

    if (!mounted) return;
    if (success) {
      showSnackbar(
        context: context,
        title: 'Contato',
        message: 'Contato salvo com sucesso!',
        variant: SnackbarVariant.success,
      );
      await _loadContacts();
    } else {
      showSnackbar(
        context: context,
        title: 'Contato',
        message: 'Contato não encontrado no Routine.',
        variant: SnackbarVariant.warning,
        icon: Icons.error,
      );
    }
  }

  Future<void> _deleteContact(int index) async {
    final contact = contacts[index];
    await DB.instance.deleteContact(contact.email);
    await _loadContacts();
  }

  Future<void> _showContactDialog({Contact? contact, int? index}) async {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(contact == null ? 'Novo contato' : 'Editar contato'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  textInputAction: TextInputAction.next,
                  onTapOutside: (_) => FocusScope.of(dialogContext).unfocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  keyboardType: TextInputType.emailAddress,
                  onTapOutside: (_) => FocusScope.of(dialogContext).unfocus(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final newContact = Contact(
                  name: nameController.text,
                  email: emailController.text,
                  avatarUrl:
                      'https://i.pravatar.cc/150?u=${emailController.text}',
                );
                Navigator.pop(dialogContext);
                await _saveContact(newContact, index: index);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
      emailController.dispose();
    }
  }

  Future<void> _openGroupEditor({ContactGroup? group}) async {
    await showGroupEditorDialog(
      context,
      group: group,
      availableContacts: contacts,
      onSave: ({required name, required memberEmails}) async {
        try {
          if (group == null) {
            final id = await DB.instance.createContactGroup(
              name: name,
              memberEmails: memberEmails,
            );
            if (id <= 0) return 'Não foi possível criar o grupo.';
          } else {
            final ok = await DB.instance.updateContactGroup(
              groupId: group.id,
              name: name,
              memberEmails: memberEmails,
            );
            if (!ok) return 'Não foi possível atualizar o grupo.';
          }
          return null;
        } on DatabaseException catch (e) {
          final msg = e.toString().toLowerCase();
          return msg.contains('unique')
              ? 'Ja existe um grupo com esse nome.'
              : 'Erro ao salvar o grupo.';
        } catch (_) {
          return 'Erro ao salvar o grupo.';
        }
      },
    );
    await _loadContacts();
  }

  Future<void> _deleteGroup(ContactGroup group) async {
    final confirm = await confirmDialog(
      context,
      title: 'Excluir grupo',
      message: 'Deseja excluir o grupo "${group.name}"?',
      confirmLabel: 'Excluir',
      destructive: true,
    );

    if (!confirm) return;
    await DB.instance.deleteContactGroup(group.id);
    await _loadContacts();
  }

  Future<void> _onCreateGroupPressed() async {
    if (contacts.isEmpty) {
      showSnackbar(
        context: context,
        title: 'Grupos',
        message: 'Adicione pelo menos um contato antes de criar um grupo.',
        variant: SnackbarVariant.warning,
        icon: Icons.info_outline,
      );
      return;
    }
    await _openGroupEditor();
  }

  Widget _buildGroupSection() {
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Grupos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _onCreateGroupPressed,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Novo grupo'),
                ),
              ],
            ),
            if (contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Adicione contatos primeiro para montar grupos.',
                ),
              )
            else if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Nenhum grupo criado ainda.',
                ),
              )
            else
              Column(
                children: groups.map((group) {
                  final memberNames = group.members
                      .map((member) => member.name)
                      .take(3)
                      .join(', ');
                  final extraCount = group.members.length - 3;
                  final subtitle = [
                    '${group.members.length} participantes',
                    if (memberNames.isNotEmpty)
                      extraCount > 0
                          ? '$memberNames e mais $extraCount'
                          : memberNames,
                  ].join(' - ');

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        group.name.trim().isEmpty
                            ? '?'
                            : group.name.trim()[0].toUpperCase(),
                      ),
                    ),
                    title: Text(group.name),
                    subtitle: Text(subtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _openGroupEditor(group: group),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteGroup(group),
                          icon: Icon(
                            Icons.delete_outline,
                            color: semantic.danger,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalPlanLocked() {
    return PlanLockedCard(
      title: 'Agenda pessoal ativa',
      message:
          'Seu plano atual permite somente agenda pessoal. Para usar contatos e agenda colaborativa, migre para o Premium.',
      onAction: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssinaturaScreen()),
        );
        await _loadContacts();
      },
      actionLabel: 'Ver planos',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(appChangeProvider, (_, __) => _loadContacts());
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final filtered = contacts
        .where((c) => c.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: const CustomAppBar(),
      body: AppBackground(
        child: Column(
          children: [
            const Divider(height: 2),
            if (_isPersonalOnly)
              Expanded(child: _buildPersonalPlanLocked())
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openInvites,
                    icon: const Icon(Icons.mail_outline),
                    label: Text(
                      _pendingInvitesCount > 0
                          ? 'Convites ($_pendingInvitesCount)'
                          : 'Convites',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar contato...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (value) => setState(() => search = value),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 90),
                  children: [
                    _buildGroupSection(),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            search.isEmpty
                                ? 'Nenhum contato cadastrado.'
                                : 'Nenhum contato encontrado.',
                          ),
                        ),
                      )
                    else
                      ...filtered.map((contact) {
                        final originalIndex = contacts.indexOf(contact);
                        return Dismissible(
                          key: ValueKey(contact.email),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: semantic.danger,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteContact(originalIndex),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: contact.avatarUrl.isEmpty ||
                                        contact.avatarUrl ==
                                            'https://i.pravatar.cc/150?u=default'
                                    ? null
                                    : NetworkImage(contact.avatarUrl),
                                child: contact.avatarUrl.isEmpty ||
                                        contact.avatarUrl ==
                                            'https://i.pravatar.cc/150?u=default'
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
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: _isPersonalOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _showContactDialog(),
              tooltip: 'Adicionar contato',
              child: const Icon(Icons.person_add),
            ),
    );
  }
}
