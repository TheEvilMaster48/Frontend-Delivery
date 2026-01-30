import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../models/restaurant_model.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';

class CartScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final UserModel cliente;
  final Map<String, int> cartItems;
  final List<ProductModel> products;

  const CartScreen({
    Key? key,
    required this.restaurant,
    required this.cliente,
    required this.cartItems,
    required this.products,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _databaseService = DatabaseService();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedPaymentMethod = 'efectivo';
  bool _isProcessing = false;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    double total = 0;
    for (final product in widget.products) {
      final quantity = widget.cartItems[product.id] ?? 0;
      total += product.price * quantity;
    }
    return total;
  }

  double get _total => _subtotal + widget.restaurant.deliveryCost;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Pedido'),
        backgroundColor: Colors.pink[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Productos del carrito
            const Text(
              'Tu Pedido',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.products.map((product) {
              final quantity = widget.cartItems[product.id] ?? 0;
              if (quantity == 0) return const SizedBox.shrink();
              return _buildCartItem(product, quantity);
            }),
            
            const SizedBox(height: 24),
            const Divider(),
            
            // Dirección de entrega
            const SizedBox(height: 16),
            const Text(
              'Dirección de Entrega',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'Ingresa tu dirección completa',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 24),
            
            // Método de pago
            const Text(
              'Método de Pago',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPaymentMethod('efectivo', 'Efectivo', Icons.money),
            _buildPaymentMethod('tarjeta', 'Tarjeta', Icons.credit_card),
            _buildPaymentMethod('billetera', 'Billetera Digital', Icons.account_balance_wallet),
            
            const SizedBox(height: 24),
            
            // Notas adicionales
            const Text(
              'Notas Adicionales (Opcional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Ej: Sin cebolla, tocar timbre, etc.',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            
            // Resumen de costos
            const SizedBox(height: 16),
            _buildCostRow('Subtotal', _subtotal),
            _buildCostRow('Costo de envío', widget.restaurant.deliveryCost),
            const SizedBox(height: 12),
            _buildCostRow('Total', _total, isTotal: true),
            
            const SizedBox(height: 32),
            
            // Botón de confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _confirmOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Confirmar Pedido - \$${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(ProductModel product, int quantity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Text(
            '${quantity}x',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              product.name,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            '\$${(product.price * quantity).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String value, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.pink[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.pink[600]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.pink[600] : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.pink[600] : Colors.grey[800],
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.pink[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.green[700] : null,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmOrder() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa una dirección de entrega'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_subtotal < widget.restaurant.minimumOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El pedido mínimo es \$${widget.restaurant.minimumOrder.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Crear items del pedido
      final items = <OrderItem>[];
      for (final product in widget.products) {
        final quantity = widget.cartItems[product.id] ?? 0;
        if (quantity > 0) {
          items.add(OrderItem(
            productId: product.id,
            productName: product.name,
            price: product.price,
            quantity: quantity,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          ));
        }
      }

      // Crear pedido
      final order = OrderModel(
        id: const Uuid().v4(),
        clientId: widget.cliente.id,
        clientName: widget.cliente.username,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        items: items,
        subtotal: _subtotal,
        deliveryCost: widget.restaurant.deliveryCost,
        total: _total,
        status: 'pendiente',
        deliveryAddress: _addressController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _databaseService.createOrder(order);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Pedido realizado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );

      // Retornar true para indicar que el pedido fue exitoso
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
