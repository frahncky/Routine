import 'package:flutter/material.dart';
import 'package:routine/features/contacts/contact_group.dart';
import 'package:routine/features/contacts/contatos.dart';

/// Cria ou atualiza um grupo. Retorna `null` em sucesso, ou uma mensagem de
/// erro pra mostrar inline no diálogo (ex.: nome duplicado).
typedef GroupSaveCallback = Future<String?> Function({
  required String name,
  required List<String> memberEmails,
});

/// Diálogo de criar/editar grupo de contatos — extraído de
/// `contacts_screen.dart` para não duplicar essa UI em outros lugares que
/// também precisem editar grupos.
Future<void> showGroupEditorDialog(
  BuildContext context, {
  ContactGroup? group,
  required List<Contact> availableContacts,
  required GroupSaveCallback onSave,
}) async {
  final nameController = TextEditingController(text: group?.name ?? '');
  final searchController = TextEditingController();
  final selectedEmails = group == null
      ? <String>{}
      : group.members.map((m) => m.email.trim().toLowerCase()).toSet();
  List<Contact> filtered = List<Contact>.from(availableContacts);
  String? localError;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(group == null ? 'Novo grupo' : 'Editar grupo'),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.58,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Nome do grupo'),
                    onTapOutside: (_) =>
                        FocusScope.of(dialogContext).unfocus(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar contato',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onTapOutside: (_) =>
                        FocusScope.of(dialogContext).unfocus(),
                    onChanged: (value) {
                      setDialogState(() {
                        final term = value.trim().toLowerCase();
                        filtered = term.isEmpty
                            ? List<Contact>.from(availableContacts)
                            : availableContacts
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Nenhum contato encontrado.'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final contact = filtered[index];
                              final email = contact.email.trim().toLowerCase();
                              final checked = selectedEmails.contains(email);
                              return CheckboxListTile(
                                value: checked,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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

                final error = await onSave(
                  name: groupName,
                  memberEmails: selectedEmails.toList(),
                );
                if (error != null) {
                  setDialogState(() => localError = error);
                  return;
                }
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
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
}
