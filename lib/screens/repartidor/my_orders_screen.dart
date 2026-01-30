import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';

class MyOrdersScreen extends StatefulWidget {
  final UserModel repartidor;
  const MyOrdersScreen({Key? key, required this.repartidor}) : super(key: key);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _databaseService = DatabaseService();
  final _locationService = LocationService();

  bool _sharingGps = false;

  @override
  void dispose() {
    // Si añadiste stopRealtimeTracking(), descomenta:
    // _locationService.stopRealtimeTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.pink[50],
          child: Row(
            children: [
              Icon(Icons.delivery_dining, color: Colors.pink[600]),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis Pedidos',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Gestiona tus entregas',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _databaseService.getRepartidorOrders(widget.repartidor.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No tienes pedidos activos'));
              }

              final activosOrders = snapshot.data!
                  .where(
                      (o) => o.status != 'entregado' && o.status != 'cancelado')
                  .toList();
              final completedOrders = snapshot.data!
                  .where(
                      (o) => o.status == 'entregado' || o.status == 'cancelado')
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (activosOrders.isNotEmpty) ...[
                    const Text('Activos',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ...activosOrders
                        .map((order) => _buildActiveOrderCard(order)),
                  ],
                  if (completedOrders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Historial',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ...completedOrders
                        .map((order) => _buildHistoryOrderCard(order)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: Text(order.restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  "Cliente: ${order.clientName}\nDir: ${order.deliveryAddress}"),
              trailing: Text(
                _getStatusLabel(order.status),
                style: TextStyle(color: _getStatusColor(order.status)),
              ),
            ),
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryOrderCard(OrderModel order) {
    return ListTile(
      leading: Icon(Icons.history, color: _getStatusColor(order.status)),
      title: Text(order.restaurantName),
      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)),
      trailing: Text('\$${order.total.toStringAsFixed(2)}'),
    );
  }

  Widget _buildActionButtons(OrderModel order) {
    if (order.status == 'preparando') {
      return ElevatedButton(
        onPressed: () => _updateOrderStatus(order.id, 'en_camino'),
        child: const Text('Iniciar Entrega'),
      );
    } else if (order.status == 'en_camino') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => _toggleGpsRealtime(),
            child: Text(_sharingGps ? 'Detener GPS' : 'Compartir GPS'),
          ),
          ElevatedButton(
            onPressed: () => _updateOrderStatus(order.id, 'entregado'),
            child: const Text('Entregado'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _toggleGpsRealtime() async {
    try {
      if (_sharingGps) {
        // Si añadiste stopRealtimeTracking(), descomenta:
        // await _locationService.stopRealtimeTracking();
        setState(() => _sharingGps = false);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS en tiempo real detenido')),
        );
        return;
      }

      // ✅ Tu servicio ya sube realtime a /users/{repartidorId}
      _locationService.startRealtimeTracking(widget.repartidor.id);
      setState(() => _sharingGps = true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compartiendo ubicación en tiempo real')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error GPS: $e')),
      );
    }
  }

  void _updateOrderStatus(String orderId, String status) async {
    await _databaseService.updateOrderStatus(orderId, status);

    // ✅ Si finaliza, apagamos el sharing (y paramos stream si existe stop)
    if (status == 'entregado' || status == 'cancelado') {
      // Si añadiste stopRealtimeTracking(), descomenta:
      // await _locationService.stopRealtimeTracking();
      if (mounted) setState(() => _sharingGps = false);
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'entregado') return Colors.green;
    if (status == 'en_camino') return Colors.purple;
    return Colors.blue;
  }

  String _getStatusLabel(String status) => status.toUpperCase();
}
