import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';

class EarningsScreen extends StatelessWidget {
  final UserModel repartidor;
  final _databaseService = DatabaseService();

  EarningsScreen({Key? key, required this.repartidor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.pink[50],
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.pink[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis Ganancias',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Historial de pagos y comisiones',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: _databaseService.getRepartidorOrders(repartidor.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes entregas',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final completedOrders = snapshot.data!
                  .where((order) => order.status == 'entregado')
                  .toList();

              // Calcular ganancias
              final totalEarnings = _calculateEarnings(completedOrders);
              final todayEarnings = _calculateTodayEarnings(completedOrders);
              final weekEarnings = _calculateWeekEarnings(completedOrders);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen de ganancias
                    _buildEarningsSummary(
                      totalEarnings,
                      todayEarnings,
                      weekEarnings,
                      completedOrders.length,
                    ),
                    const SizedBox(height: 24),

                    // Historial de entregas
                    const Text(
                      'Historial de Entregas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (completedOrders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No hay entregas completadas',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...completedOrders.map((order) => _buildEarningCard(order)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsSummary(
      double total,
      double today,
      double week,
      int deliveries,
      ) {
    return Column(
      children: [
        // Card principal de ganancias totales
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[600]!],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Ganancias Totales',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$deliveries entregas completadas',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cards de período
        Row(
          children: [
            Expanded(
              child: _buildPeriodCard(
                'Hoy',
                today,
                Icons.today,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPeriodCard(
                'Esta Semana',
                week,
                Icons.date_range,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodCard(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningCard(OrderModel order) {
    // Comisión estimada (ejemplo: 15% del costo de envío)
    final earning = order.deliveryCost * 0.85;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.check_circle, color: Colors.green[600]),
        ),
        title: Text(
          order.restaurantName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.clientName),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+\$${earning.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            Text(
              'Comisión',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  double _calculateEarnings(List<OrderModel> orders) {
    return orders.fold(0.0, (sum, order) {
      // Comisión estimada: 85% del costo de envío
      return sum + (order.deliveryCost * 0.85);
    });
  }

  double _calculateTodayEarnings(List<OrderModel> orders) {
    final today = DateTime.now();
    final todayOrders = orders.where((order) {
      return order.createdAt.year == today.year &&
          order.createdAt.month == today.month &&
          order.createdAt.day == today.day;
    }).toList();

    return _calculateEarnings(todayOrders);
  }

  double _calculateWeekEarnings(List<OrderModel> orders) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekOrders = orders.where((order) {
      return order.createdAt.isAfter(weekAgo);
    }).toList();

    return _calculateEarnings(weekOrders);
  }
}
