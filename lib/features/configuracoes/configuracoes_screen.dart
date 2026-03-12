import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:routine/features/configuracoes/delete_account.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/login/user.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/login/login_screen.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/main.dart';

class ConfiguracoesScreen extends StatefulWidget {
   ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  LocalUser? user;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isEditingName = false;

  int _minutosAntes = 10;
  bool _notificacoesAtivas = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadMinutosAntes();
    _loadNotificacoesAtivas();
  }

  Future<void> _loadUser() async {
    final userMap = await DB.instance.getUser();
    setState(() {
      user = userMap != null ? LocalUser.fromMap(userMap) : null;
      _nameController.text = user?.name ?? '';
      
    });
  }

  Future<void> _loadMinutosAntes() async {
    final minutos = await DB.instance.getConfig('minutosAntesNotificacao');
    setState(() {
      _minutosAntes = minutos != null ? int.tryParse(minutos) ?? 10 : 10;
    });
  }

  Future<void> _salvarMinutosAntes(int value) async {
    await DB.instance.setConfig('minutosAntesNotificacao', value.toString());
    setState(() {
      _minutosAntes = value;
    });
    showSnackbar(
      title: 'Configuração salva',
      message: 'Tempo de notificação atualizado!',
      backgroundColor: Colors.green.shade200,
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _loadNotificacoesAtivas() async {
    final ativo = await DB.instance.getConfig('notificacoesAtivas');
    setState(() {
      _notificacoesAtivas = ativo == null ? true : ativo == 'true';
    });
  }

  Future<void> _salvarNotificacoesAtivas(bool value) async {
    await DB.instance.setConfig('notificacoesAtivas', value.toString());
    setState(() {
      _notificacoesAtivas = value;
    });
    notificacoesAtivasNotifier.value = value; // Notifica todas as telas
  }

  Future<void> _editarFoto() async {
    if (user == null) {
      showSnackbar(
        title: 'Erro',
        message: 'Usuário não encontrado!',
        backgroundColor: Colors.red.shade200,
        icon: Icons.error_outline,
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imagePath = pickedFile.path;

      await DB.instance.updateAccount(email: user!.email, avatarUrl: imagePath);

      // Notifique todas as telas que usam o avatar
      
     changeAvatar.value = !(changeAvatar.value);

      // Atualiza o avatar do usuário
     // user = user!.copyWith(avatarUrl: imagePath);
      

      // Atualiza o avatar na tela atual
      setState(() {});

      

      // Recarrega o usuário para garantir atualização na tela atual
      await _loadUser();

      // Exibe snackbar de sucesso
       showSnackbar(
        title: 'Foto atualizada',
        message: 'Sua foto de perfil foi atualizada com sucesso!',
        backgroundColor: Colors.green.shade200,
        icon: Icons.check_circle_outline,
      );
    }
  }

  void _toggleEditarNome() {
    if (_isEditingName) {
      setState(() => _isEditingName = false);
      _salvarNome();
    } else {
      setState(() => _isEditingName = true);
    }

    _loadUser();
  }

  Future<void> _salvarNome() async {
    if (_formKey.currentState!.validate()) {
      final newName = _nameController.text.trim();
      await DB.instance.updateAccount(name: newName, email: user!.email);

      setState(() {
        user = user!.copyWith(name: newName);
        _isEditingName = false;
      });

      if (context.mounted) {
        showSnackbar(
          title: 'Atualização de nome',
          message: 'Seu nome de Usuário foi Atualizado',
          backgroundColor: Colors.green.shade200,
          icon: Icons.check_circle_outline,
        );
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await DB.instance.clearLocalData();

    showSnackbar(
      title: "Conta desconectada",
      message: "Sua conta foi desconectada!",
      backgroundColor: Colors.orange.shade200,
      icon: Icons.check_circle,
    );

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: CustomAppBar(),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
             Divider(height: 2),
            Expanded(
              child: ListView(
                padding:  EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,                         
                          backgroundImage: user?.avatarUrl != null &&
                                  user!.avatarUrl.isNotEmpty
                              ? FileImage(File(user!.avatarUrl))
                              : null,
                          child: user?.avatarUrl == null ||
                                  user!.avatarUrl.isEmpty
                              ?  Icon(Icons.person,
                                  size: 40, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: ()=>_editarFoto(),
                            child: Container(
                              padding:  EdgeInsets.all(6),
                              decoration:  BoxDecoration(
                                color: Colors.indigo,
                                shape: BoxShape.circle,
                              ),
                              child:  Icon(Icons.edit,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                   SizedBox(height: 20),
                  ListTile(
                    title:  Text('Usuário'),
                    subtitle: _isEditingName
                        ? TextFormField(
                            controller: _nameController,
                            decoration:  InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Campo Obrigatório';
                              }
                              return null;
                            },
                          )
                        : Text(user?.name ?? ''),
                    trailing: IconButton(
                      icon: Icon(_isEditingName ? Icons.save : Icons.edit),
                      onPressed: _toggleEditarNome,
                    ),
                  ),
                  ListTile(
                    title:  Text('E-mail'),
                    subtitle: Text(user?.email ?? ''),
                  ),
                   Divider(),
                  ListTile(
                    title:  Text('Receber notificações'),
                    trailing: Switch(
                      value: _notificacoesAtivas,
                      onChanged: (value) {
                        _salvarNotificacoesAtivas(value);
                      },
                    ),
                  ),
                  if (_notificacoesAtivas)
                    ListTile(
                      title:  Text('Notificar antes da atividade'),
                      subtitle: Text(
                        _minutosAntes == 0
                            ? 'Sem notificação'
                            : '$_minutosAntes minutos antes',
                      ),
                      trailing: SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: _minutosAntes.toString(),
                          keyboardType: TextInputType.number,
                          decoration:  InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            hintText: '0 = sem',
                          ),
                          onFieldSubmitted: (value) {
                            final v = int.tryParse(value);
                            if (v != null && v >= 0) {
                              _salvarMinutosAntes(v);
                            }
                          },
                        ),
                      ),
                    ),
                   Divider(),
                  ListTile(
                    title:  Text('Tipo de plano'),
                    subtitle: Text(user?.typeAccount ?? ''),
                    trailing:  Icon(Icons.edit),
                    onTap: () {},
                  ),
                   Divider(),
                  ListTile(
                    title:  Text('Sair'),
                    leading:  Icon(Icons.logout, color: Colors.red),
                    onTap: _signOut,
                  ),
                  ListTile(
                    title:  Text('Deletar Conta'),
                    leading:  Icon(Icons.delete_forever, color: Colors.red),
                    onTap: () => deleteAccount(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
