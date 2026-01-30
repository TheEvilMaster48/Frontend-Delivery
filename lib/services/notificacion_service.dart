import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String? _currentToken;
  String? _currentUserId;
  String? _currentRole;

  String? get currentToken => _currentToken;

  bool _globalListenersReady = false;

  // LISTENERS GLOBALES PARA TODA LA APP (SE LLAMA EN MAIN)
  void setupGlobalListeners() {
    if (_globalListenersReady) return;
    _globalListenersReady = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('FCM FOREGROUND: ${message.messageId} TITLE=${message.notification?.title} DATA=${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('FCM OPENED APP: ${message.messageId} DATA=${message.data}');
    });
  }

  // INICIALIZAR NOTIFICACIONES PARA UN USUARIO LOGUEADO
  Future<void> initialize({required String userId, required String role}) async {
    _currentUserId = userId;
    _currentRole = role;

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('Permisos de notificacion denegados');
      return;
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permisos de notificacion concedidos');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('Permisos provisionales concedidos');
    }

    _currentToken = await _messaging.getToken();
    if (_currentToken != null) {
      await _dbRef.child('users').child(userId).update({
        'fcmToken': _currentToken,
        'lastTokenUpdate': ServerValue.timestamp,
      });
      print('Token FCM guardado: $_currentToken');
    }

    // TOPICS PARA ENVIAR A TODOS / POR ROL DESDE BACKEND O CLOUD FUNCTIONS
    await _subscribeToTopics(role);

    // TOKEN REFRESH
    _messaging.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      if (_currentUserId == null) return;

      await _dbRef.child('users').child(_currentUserId!).update({
        'fcmToken': newToken,
        'lastTokenUpdate': ServerValue.timestamp,
      });
      print('Token FCM actualizado: $newToken');
    });
  }

  Future<void> _subscribeToTopics(String role) async {
    final r = role.trim().toLowerCase();

    await _messaging.subscribeToTopic('all');

    if (r == 'administrador' || r == 'admin') {
      await _messaging.subscribeToTopic('admins');
    } else if (r == 'repartidor') {
      await _messaging.subscribeToTopic('repartidores');
    } else {
      await _messaging.subscribeToTopic('clientes');
    }

    print('Suscrito a topics: all + $r');
  }

  Future<void> _unsubscribeFromTopics(String role) async {
    final r = role.trim().toLowerCase();

    await _messaging.unsubscribeFromTopic('all');

    if (r == 'administrador' || r == 'admin') {
      await _messaging.unsubscribeFromTopic('admins');
    } else if (r == 'repartidor') {
      await _messaging.unsubscribeFromTopic('repartidores');
    } else {
      await _messaging.unsubscribeFromTopic('clientes');
    }

    print('Desuscrito de topics: all + $r');
  }

  // LISTENER EN PRIMER PLANO CON CALLBACK A UI (SNACKBAR, DIALOG, ETC)
  void setupForegroundListener(Function(String? title, String? body) onNotification) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      onNotification(message.notification?.title, message.notification?.body);
    });
  }

  // LISTENER CUANDO ABREN LA APP DESDE NOTIFICACION
  void setupOpenedAppListener(Function(Map<String, dynamic> data) onOpenedFromNotification) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onOpenedFromNotification(message.data);
    });
  }

  Future<void> sendLocalActivityNotification({
    required String userId,
    required String activityType,
    required String title,
    required String body,
    Map<String, dynamic>? extraData,
  }) async {
    await _dbRef.child('notifications').child(userId).push().set({
      'type': activityType,
      'title': title,
      'body': body,
      'data': extraData,
      'timestamp': ServerValue.timestamp,
      'read': false,
    });
  }

  static void showInAppNotification(BuildContext context, String? title, String? body, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            if (body != null) Text(body, style: const TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // LIMPIAR TOKEN Y TOPICS AL CERRAR SESION
  Future<void> clearToken(String userId) async {
    try {
      if (_currentRole != null) {
        await _unsubscribeFromTopics(_currentRole!);
      }

      await _dbRef.child('users').child(userId).update({
        'fcmToken': null,
      });

      _currentToken = null;
      _currentUserId = null;
      _currentRole = null;

      print('Token FCM limpiado para $userId');
    } catch (e) {
      print('Error limpiando token: $e');
    }
  }
}
