/*import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';

/// Mixin para detectar inactividad del usuario y cerrar sesion automaticamente
/// despues de 5 minutos sin interaccion.
mixin InactivityMixin<T extends StatefulWidget> on State<T> {
  Timer? _inactivityTimer;
  final AuthService _authServiceMixin = AuthService();

  // 5 minutos en segundos
  static const int _inactivityDuration = 5 * 60;

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  /// Reiniciar el timer de inactividad
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: _inactivityDuration), _onInactivityTimeout);

    // Actualizar ultima actividad en SharedPreferences
    _authServiceMixin.updateLastActivity();
  }

  /// Llamado cuando el timer de inactividad expira
  void _onInactivityTimeout() {
    _logoutDueToInactivity();
  }

  /// Cerrar sesion por inactividad
  Future<void> _logoutDueToInactivity() async {
    await _authServiceMixin.logout();

    if (!mounted) return;

    // Mostrar dialogo de sesion expirada
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Sesion Expirada',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Tu sesion ha expirado por inactividad. Por favor, inicia sesion nuevamente.',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'INICIAR SESION',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wrapper para detectar interacciones del usuario
  /// Usar este widget envolviendo el Scaffold de cada pantalla
  Widget buildWithInactivityDetector({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      onPanUpdate: (_) => _resetInactivityTimer(),
      onScaleStart: (_) => _resetInactivityTimer(),
      child: Listener(
        onPointerDown: (_) => _resetInactivityTimer(),
        onPointerMove: (_) => _resetInactivityTimer(),
        onPointerUp: (_) => _resetInactivityTimer(),
        child: child,
      ),
    );
  }
}
*/