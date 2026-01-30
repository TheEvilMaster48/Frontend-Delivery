import 'package:firebase_database/firebase_database.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String role; // 'administrador', 'repartidor', 'cliente'
  final String? photoUrl;
  final DateTime createdAt;
  final bool isActive;
  
  // Campos específicos del repartidor
  final String? vehicleType;
  final bool? isAvailable;
  final double? rating;
  
  // Campos específicos del cliente
  final List<String>? savedAddresses;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.photoUrl,
    required this.createdAt,
    this.isActive = true,
    this.vehicleType,
    this.isAvailable,
    this.rating,
    this.savedAddresses,
  });

  // CORRECCIÓN AQUÍ: Usamos DateTime.parse en lugar de .toDate()
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'cliente',
      photoUrl: map['photoUrl'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
      vehicleType: map['vehicleType'],
      isAvailable: map['isAvailable'],
      rating: (map['rating'] is int) 
          ? (map['rating'] as int).toDouble() 
          : map['rating']?.toDouble(),
      savedAddresses: map['savedAddresses'] != null 
          ? List<String>.from(map['savedAddresses']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(), // Guardar como texto ISO
      'isActive': isActive,
      'vehicleType': vehicleType,
      'isAvailable': isAvailable,
      'rating': rating,
      'savedAddresses': savedAddresses,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? role,
    String? photoUrl,
    DateTime? createdAt,
    bool? isActive,
    String? vehicleType,
    bool? isAvailable,
    double? rating,
    List<String>? savedAddresses,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      vehicleType: vehicleType ?? this.vehicleType,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      savedAddresses: savedAddresses ?? this.savedAddresses,
    );
  }
}
