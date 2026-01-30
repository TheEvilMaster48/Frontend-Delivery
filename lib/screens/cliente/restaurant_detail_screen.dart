import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/restaurant_model.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import 'cart_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final UserModel cliente;

  const RestaurantDetailScreen({
    Key? key,
    required this.restaurant,
    required this.cliente,
  }) : super(key: key);

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _databaseService = DatabaseService();
  final Map<String, int> _cart = {}; // productId -> quantity

  int get _cartItemCount => _cart.values.fold(0, (sum, qty) => sum + qty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.name),
        backgroundColor: Colors.pink[600],
        foregroundColor: Colors.white,
        actions: [
          if (_cartItemCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: _goToCart,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Header del restaurante
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.pink[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.restaurant.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.restaurant.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.star,
                      '${widget.restaurant.rating}',
                      Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.access_time,
                      '${widget.restaurant.deliveryTime} min',
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.delivery_dining,
                      '\$${widget.restaurant.deliveryCost.toStringAsFixed(2)}',
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de productos
          Expanded(
            child: StreamBuilder<List<ProductModel>>(
              stream: _databaseService.getProductsByRestaurant(widget.restaurant.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No hay productos disponibles'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final product = snapshot.data![index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: _goToCart,
              backgroundColor: Colors.pink[600],
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                'Ver Carrito ($_cartItemCount)',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final quantity = _cart[product.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Imagen del producto
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.fastfood, size: 40, color: Colors.grey[500]),
            ),
            const SizedBox(width: 12),
            // Información del producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            // Controles de cantidad
            if (product.isAvailable)
              Column(
                children: [
                  if (quantity == 0)
                    IconButton(
                      onPressed: () => _addToCart(product.id),
                      icon: Icon(Icons.add_circle, color: Colors.pink[600]),
                      iconSize: 32,
                    )
                  else
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _addToCart(product.id),
                          icon: Icon(Icons.add_circle, color: Colors.pink[600]),
                          iconSize: 28,
                        ),
                        Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeFromCart(product.id),
                          icon: Icon(Icons.remove_circle, color: Colors.grey[600]),
                          iconSize: 28,
                        ),
                      ],
                    ),
                ],
              )
            else
              const Text(
                'No disponible',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addToCart(String productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      final newQty = (_cart[productId] ?? 1) - 1;
      if (newQty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQty;
      }
    });
  }

  void _goToCart() async {
    if (_cart.isEmpty) return;

    // Obtener productos del carrito
    final cartProducts = <ProductModel>[];
    await for (final products in _databaseService.getProductsByRestaurant(widget.restaurant.id).take(1)) {
      for (final product in products) {
        if (_cart.containsKey(product.id)) {
          cartProducts.add(product);
        }
      }
    }

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          restaurant: widget.restaurant,
          cliente: widget.cliente,
          cartItems: _cart,
          products: cartProducts,
        ),
      ),
    );

    // Si el pedido fue exitoso, limpiar el carrito
    if (result == true) {
      setState(() => _cart.clear());
    }
  }
}
