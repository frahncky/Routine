import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:routine/features/convites/convites_screen.dart';
import 'package:routine/notifications/notifications.dart';

/// Navigator raiz do app — permite navegar (ex.: ao tocar numa notificação
/// push) a partir de código que roda fora da árvore de widgets.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

String? _lastRegisteredToken;

String? _normalizedEmail() =>
    FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();

/// Pede permissão de notificação (Android 13+/iOS) e registra o token FCM
/// do dispositivo em `users/{email}.fcmTokens`, pra que a Cloud Function
/// `notifyOnInviteWritten` saiba pra onde mandar push. Chamado depois de
/// login — best-effort, falhas não devem travar o app.
Future<void> registerPushTokenForCurrentUser() async {
  try {
    final email = _normalizedEmail();
    if (email == null || email.isEmpty) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token != null) {
      await _saveToken(email, token);
    }

    messaging.onTokenRefresh.listen((newToken) {
      final currentEmail = _normalizedEmail();
      if (currentEmail == null || currentEmail.isEmpty) return;
      _saveToken(currentEmail, newToken);
    });
  } catch (e) {
    debugPrint('Falha ao registrar token de push: $e');
  }
}

Future<void> _saveToken(String email, String token) async {
  _lastRegisteredToken = token;
  try {
    await FirebaseFirestore.instance.collection('users').doc(email).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('Falha ao salvar token de push: $e');
  }
}

/// Remove o token deste dispositivo de `fcmTokens` — chamado antes do
/// sign-out (enquanto ainda há permissão de escrever no próprio doc).
Future<void> unregisterPushTokenForCurrentUser() async {
  try {
    final email = _normalizedEmail();
    final token =
        _lastRegisteredToken ?? await FirebaseMessaging.instance.getToken();
    if (email == null || email.isEmpty || token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(email).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('Falha ao remover token de push: $e');
  } finally {
    _lastRegisteredToken = null;
  }
}

bool _foregroundHandlingInitialized = false;

/// Configura o tratamento de mensagens push: em foreground (app aberto),
/// o FCM não mostra notificação sozinho — reaproveita a infraestrutura
/// local já existente pra exibir. Ao tocar numa notificação (app em
/// background ou fechado), navega pra tela de convites.
void initPushMessageHandling() {
  if (_foregroundHandlingInitialized) return;
  _foregroundHandlingInitialized = true;

  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;
    mostrarNotificacaoImediata(
      titulo: notification.title ?? 'Routine',
      corpo: notification.body ?? '',
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((_) => _openConvites());
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _openConvites();
  });
}

void _openConvites() {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(
    MaterialPageRoute(builder: (_) => const ConvitesScreen()),
  );
}
