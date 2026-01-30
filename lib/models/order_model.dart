import 'geo_point.dart';

class OrderModel {
  final String id;
  final String clientId;
  final String clientName;
  final String restaurantId;
  final String restaurantName;
  final String? repartidorId;
  final String? repartidorName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryCost;
  final double total;
  final String status; // 'pendiente', 'preparando', 'en_camino', 'entregado', 'cancelado'
  final String deliveryAddress;
  final GeoPoint? deliveryLocation;
  final GeoPoint? repartidorLocation;
  final String paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  OrderModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.restaurantId,
    required this.restaurantName,
    this.repartidorId,
    this.repartidorName,
    required this.items,
    required this.subtotal,
    required this.deliveryCost,
    required this.total,
    required this.status,
    required this.deliveryAddress,
    this.deliveryLocation,
    this.repartidorLocation,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.deliveredAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      repartidorId: map['repartidorId'],
      repartidorName: map['repartidorName'],
      items: (map['items'] as List<dynamic>)
          .map((item) => OrderItem.fromMap(item))
          .toList(),
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
      deliveryCost: map['deliveryCost']?.toDouble() ?? 0.0,
      total: map['total']?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pendiente',
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryLocation: map['deliveryLocation'],
      repartidorLocation: map['repartidorLocation'],
      paymentMethod: map['paymentMethod'] ?? 'efectivo',
      notes: map['notes'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      deliveredAt: map['deliveredAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'repartidorId': repartidorId,
      'repartidorName': repartidorName,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryCost': deliveryCost,
      'total': total,
      'status': status,
      'deliveryAddress': deliveryAddress,
      'deliveryLocation': deliveryLocation,
      'repartidorLocation': repartidorLocation,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdAt': createdAt,
      'deliveredAt': deliveredAt,
    };
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final List<String>? extras;
  final String? notes;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.extras,
    this.notes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
      quantity: map['quantity'] ?? 1,
      extras: map['extras'] != null ? List<String>.from(map['extras']) : null,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'extras': extras,
      'notes': notes,
    };
  }

  double get totalPrice => price * quantity;
}

