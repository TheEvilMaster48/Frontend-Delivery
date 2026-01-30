import 'package:firebase_database/firebase_database.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';

class AuthService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        "_${DateTime.now().microsecond}";
  }

  // MÉTODO AGREGADO PARA CORREGIR EL ERROR
  Future<void> updateAvailability(String userId, bool isAvailable) async {
    try {
      await _database.child('users').child(userId).update({
        'isAvailable': isAvailable,
      });
    } catch (e) {
      print('Error al actualizar disponibilidad: $e');
      throw Exception('No se pudo actualizar el estado');
    }
  }

  Future<UserModel?> register({
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      final snapshot = await _database
          .child('users')
          .orderByChild('username')
          .equalTo(username.trim())
          .get();

      if (snapshot.exists) {
        throw Exception('El nombre de usuario ya está en uso');
      }

      final String odSuffix = role == 'administrador' ? 'A' :
      role == 'repartidor' ? 'R' : 'C';
      final String odNumber = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final String odCode = '$odSuffix$odNumber';

      final userModel = UserModel(
        id: _generateId(),
        username: username.trim(),
        email: '${username.trim()}@delivery.app',
        role: role,
        createdAt: DateTime.now(),
        isActive: true,
        isAvailable: role == 'repartidor' ? true : null,
        rating: role == 'repartidor' ? 5.0 : null,
        savedAddresses: role == 'cliente' ? [] : null,
      );

      final userData = userModel.toMap();
      userData['createdAt'] = userModel.createdAt.toIso8601String();
      userData['password'] = _hashPassword(password);
      userData['odCode'] = odCode;

      await _database.child('users').child(userModel.id).set(userData);

      return userModel;
    } catch (e) {
      print('Error en registro: $e');
      rethrow;
    }
  }

  Future<UserModel?> login({
    required String username,
    required String password,
  }) async {
    try {
      final snapshot = await _database
          .child('users')
          .orderByChild('username')
          .equalTo(username.trim())
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Usuario no encontrado');
      }

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final userEntry = data.entries.first;
      final Map<String, dynamic> userData = Map<String, dynamic>.from(userEntry.value as Map);
      final String userId = userEntry.key.toString();

      final hashedPassword = _hashPassword(password);
      if (userData['password'] != hashedPassword) {
        throw Exception('Contraseña incorrecta');
      }

      if (userData['isActive'] == false) {
        throw Exception('Usuario desactivado');
      }

      _currentUser = UserModel.fromMap(userData, userId);
      return _currentUser;
    } catch (e) {
      print('Error en login: $e');
      rethrow;
    }
  }

  Future<void> logout() async { _currentUser = null; }
}
