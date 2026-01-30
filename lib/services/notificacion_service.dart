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
  String? get currentToken => _currentToken;

  /// Inicializar servicio de notificaciones para un usuario
  Future<void> initialize(String userId) async {
    // Solicitar permisos
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permisos de notificacion concedidos');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('Permisos provisionales concedidos');
    } else {
      print('Permisos de notificacion denegados');
      return;
    }

    // Obtener y guardar token FCM
    _currentToken = await _messaging.getToken();
    if (_currentToken != null) {
      await _dbRef.child('users').child(userId).update({
        'fcmToken': _currentToken,
        'lastTokenUpdate': ServerValue.timestamp,
      });
      print('Token FCM guardado: $_currentToken');
    }

    // Escuchar cambios de token
    _messaging.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      await _dbRef.child('users').child(userId).update({
        'fcmToken': newToken,
        'lastTokenUpdate': ServerValue.timestamp,
      });
      print('Token FCM actualizado: $newToken');
    });
  }

  /// Configurar listeners de notificaciones con callback para mostrar en UI
  void setupForegroundListener(Function(String? title, String? body) onNotification) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notificacion recibida en primer plano: ${message.notification?.title}');
      onNotification(
        message.notification?.title,
        message.notification?.body,
      );
    });
  }

  /// Configurar listener cuando la app se abre desde una notificacion
  void setupOpenedAppListener(Function(Map<String, dynamic> data) onOpenedFromNotification) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App abierta desde notificacion: ${message.data}');
      onOpenedFromNotification(message.data);
    });
  }

  /// Enviar notificacion local (para actividades internas)
  Future<void> sendLocalActivityNotification({
    required String userId,
    required String activityType,
    required String title,
    required String body,
    Map<String, dynamic>? extraData,
  }) async {
    // Guardar actividad en Firebase para historial
    await _dbRef.child('notifications').child(userId).push().set({
      'type': activityType,
      'title': title,
      'body': body,
      'data': extraData,
      'timestamp': ServerValue.timestamp,
      'read': false,
    });
  }

  /// Mostrar notificacion en la UI (SnackBar)
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
            if (body != null)
              Text(body, style: const TextStyle(fontSize: 13)),
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

  /// Limpiar token al cerrar sesion
  Future<void> clearToken(String userId) async {
    await _dbRef.child('users').child(userId).update({
      'fcmToken': null,
    });
    _currentToken = null;
  }
}
