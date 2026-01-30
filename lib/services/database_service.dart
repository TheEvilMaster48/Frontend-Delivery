import 'package:firebase_database/firebase_database.dart';
import '../models/restaurant_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // ============= RESTAURANTES =============

  // Crear restaurante
  Future<String> createRestaurant(RestaurantModel restaurant) async {
    try {
      final newRef = _database.child('restaurants').push();
      await newRef.set(restaurant.toMap());
      return newRef.key!;
    } catch (e) {
      print('Error creando restaurante: $e');
      rethrow;
    }
  }

  // Obtener todos los restaurantes
  Stream<List<RestaurantModel>> getRestaurants() {
    return _database.child('restaurants').onValue.map((event) {
      final List<RestaurantModel> restaurants = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          restaurants.add(RestaurantModel.fromMap(
            Map<String, dynamic>.from(value as Map),
            key as String,
          ));
        });
      }
      return restaurants;
    });
  }

  // Obtener restaurante por ID
  Future<RestaurantModel?> getRestaurantById(String id) async {
    try {
      final snapshot = await _database.child('restaurants').child(id).get();
      if (snapshot.exists) {
        return RestaurantModel.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
          id,
        );
      }
      return null;
    } catch (e) {
      print('Error obteniendo restaurante: $e');
      return null;
    }
  }

  // Actualizar restaurante
  Future<void> updateRestaurant(String id, Map<String, dynamic> data) async {
    try {
      await _database.child('restaurants').child(id).update(data);
    } catch (e) {
      print('Error actualizando restaurante: $e');
      rethrow;
    }
  }

  // Eliminar restaurante
  Future<void> deleteRestaurant(String id) async {
    try {
      await _database.child('restaurants').child(id).remove();
    } catch (e) {
      print('Error eliminando restaurante: $e');
      rethrow;
    }
  }

  // ============= PRODUCTOS =============

  // Crear producto
  Future<String> createProduct(ProductModel product) async {
    try {
      final newRef = _database.child('products').push();
      await newRef.set(product.toMap());
      return newRef.key!;
    } catch (e) {
      print('Error creando producto: $e');
      rethrow;
    }
  }

  // Obtener productos de un restaurante
  Stream<List<ProductModel>> getProductsByRestaurant(String restaurantId) {
    return _database.child('products').onValue.map((event) {
      final List<ProductModel> products = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final productData = Map<String, dynamic>.from(value as Map);
          if (productData['restaurantId'] == restaurantId) {
            products.add(ProductModel.fromMap(productData, key as String));
          }
        });
      }
      return products;
    });
  }

  // Obtener todos los productos
  Stream<List<ProductModel>> getAllProducts() {
    return _database.child('products').onValue.map((event) {
      final List<ProductModel> products = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          products.add(ProductModel.fromMap(
            Map<String, dynamic>.from(value as Map),
            key as String,
          ));
        });
      }
      return products;
    });
  }

  // Actualizar producto
  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      await _database.child('products').child(id).update(data);
    } catch (e) {
      print('Error actualizando producto: $e');
      rethrow;
    }
  }

  // Eliminar producto
  Future<void> deleteProduct(String id) async {
    try {
      await _database.child('products').child(id).remove();
    } catch (e) {
      print('Error eliminando producto: $e');
      rethrow;
    }
  }

  // ============= PEDIDOS =============

  // Crear pedido
  Future<String> createOrder(OrderModel order) async {
    try {
      final newRef = _database.child('orders').push();
      await newRef.set(order.toMap());
      return newRef.key!;
    } catch (e) {
      print('Error creando pedido: $e');
      rethrow;
    }
  }

  // Obtener todos los pedidos (Admin)
  Stream<List<OrderModel>> getAllOrders() {
    return _database.child('orders').onValue.map((event) {
      final List<OrderModel> orders = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          orders.add(OrderModel.fromMap(
            Map<String, dynamic>.from(value as Map),
            key as String,
          ));
        });
      }
      // Ordenar por fecha de creación (más recientes primero)
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  // Obtener pedidos del cliente
  Stream<List<OrderModel>> getClientOrders(String clientId) {
    return _database.child('orders').onValue.map((event) {
      final List<OrderModel> orders = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final orderData = Map<String, dynamic>.from(value as Map);
          if (orderData['clientId'] == clientId) {
            orders.add(OrderModel.fromMap(orderData, key as String));
          }
        });
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  // Obtener pedidos disponibles (sin repartidor asignado)
  Stream<List<OrderModel>> getAvailableOrders() {
    return _database.child('orders').onValue.map((event) {
      final List<OrderModel> orders = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final orderData = Map<String, dynamic>.from(value as Map);
          if (orderData['status'] == 'pendiente' &&
              (orderData['repartidorId'] == null || orderData['repartidorId'] == '')) {
            orders.add(OrderModel.fromMap(orderData, key as String));
          }
        });
      }
      return orders;
    });
  }

  // Obtener pedidos del repartidor
  Stream<List<OrderModel>> getRepartidorOrders(String repartidorId) {
    return _database.child('orders').onValue.map((event) {
      final List<OrderModel> orders = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final orderData = Map<String, dynamic>.from(value as Map);
          if (orderData['repartidorId'] == repartidorId) {
            orders.add(OrderModel.fromMap(orderData, key as String));
          }
        });
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  // Actualizar estado del pedido
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
      };
      if (status == 'entregado') {
        updates['deliveredAt'] = DateTime.now().toIso8601String();
      }
      await _database.child('orders').child(orderId).update(updates);
    } catch (e) {
      print('Error actualizando estado del pedido: $e');
      rethrow;
    }
  }

  // Asignar repartidor a pedido
  Future<void> assignRepartidorToOrder(String orderId, String repartidorId, String repartidorName) async {
    try {
      await _database.child('orders').child(orderId).update({
        'repartidorId': repartidorId,
        'repartidorName': repartidorName,
        'status': 'preparando',
      });
    } catch (e) {
      print('Error asignando repartidor: $e');
      rethrow;
    }
  }

  // Actualizar ubicación del repartidor
  Future<void> updateRepartidorLocation(String orderId, double lat, double lng) async {
    try {
      await _database.child('orders').child(orderId).update({
        'repartidorLocation': {'lat': lat, 'lng': lng},
      });
    } catch (e) {
      print('Error actualizando ubicación: $e');
      rethrow;
    }
  }

  // ============= USUARIOS =============

  // Obtener todos los usuarios (Admin)
  Stream<List<UserModel>> getAllUsers() {
    return _database.child('users').onValue.map((event) {
      final List<UserModel> users = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          users.add(UserModel.fromMap(
            Map<String, dynamic>.from(value as Map),
            key as String,
          ));
        });
      }
      return users;
    });
  }

  // Obtener usuarios por rol
  Stream<List<UserModel>> getUsersByRole(String role) {
    return _database.child('users').onValue.map((event) {
      final List<UserModel> users = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final userData = Map<String, dynamic>.from(value as Map);
          if (userData['role'] == role) {
            users.add(UserModel.fromMap(userData, key as String));
          }
        });
      }
      return users;
    });
  }

  // Actualizar usuario
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _database.child('users').child(userId).update(data);
    } catch (e) {
      print('Error actualizando usuario: $e');
      rethrow;
    }
  }

  // ============= ESTADÍSTICAS (Admin) =============

  // Obtener estadísticas generales
  Future<Map<String, dynamic>> getStats() async {
    try {
      final usersSnapshot = await _database.child('users').get();
      final ordersSnapshot = await _database.child('orders').get();
      final restaurantsSnapshot = await _database.child('restaurants').get();

      int totalUsers = 0;
      int totalClientes = 0;
      int totalRepartidores = 0;
      int totalOrders = 0;
      int ordersEntregados = 0;
      double totalVentas = 0;

      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
        usersData.forEach((key, value) {
          totalUsers++;
          final role = (value as Map)['role'];
          if (role == 'cliente') totalClientes++;
          if (role == 'repartidor') totalRepartidores++;
        });
      }

      if (ordersSnapshot.exists) {
        final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>;
        ordersData.forEach((key, value) {
          totalOrders++;
          final orderData = value as Map;
          if (orderData['status'] == 'entregado') {
            ordersEntregados++;
            totalVentas += (orderData['total'] ?? 0).toDouble();
          }
        });
      }

      int totalRestaurants = 0;
      if (restaurantsSnapshot.exists) {
        totalRestaurants = (restaurantsSnapshot.value as Map).length;
      }

      return {
        'totalUsers': totalUsers,
        'totalClientes': totalClientes,
        'totalRepartidores': totalRepartidores,
        'totalOrders': totalOrders,
        'ordersEntregados': ordersEntregados,
        'totalVentas': totalVentas,
        'totalRestaurants': totalRestaurants,
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {};
    }
  }
}
