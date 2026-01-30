import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reportes y Métricas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Análisis del negocio en tiempo real',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Métricas principales con StreamBuilders
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              // 1. Clientes Totales (Contando el nodo 'users')
              _buildRealtimeMetric(
                path: 'users',
                title: 'Clientes Registrados',
                icon: Icons.people,
                color: Colors.purple,
                formatter: (count) => count.toString(),
              ),
              
              // 2. Pedidos Totales
              _buildRealtimeMetric(
                path: 'orders',
                title: 'Pedidos Totales',
                icon: Icons.shopping_bag,
                color: Colors.blue,
                formatter: (count) => count.toString(),
              ),

              // 3. Restaurantes Activos
              _buildRealtimeMetric(
                path: 'restaurants',
                title: 'Restaurantes',
                icon: Icons.restaurant,
                color: Colors.orange,
                formatter: (count) => count.toString(),
              ),

              // 4. Ventas Estimadas (Suma de precios si tienes el campo)
              // Aquí un ejemplo de cómo contar pedidos completados
              _buildRealtimeMetric(
                path: 'orders',
                title: 'Ventas Realizadas',
                icon: Icons.trending_up,
                color: Colors.green,
                formatter: (count) => "\$${count * 15}", // Ejemplo: promedio $15 por pedido
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'Resumen de Actividad',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Lista de pedidos recientes en tiempo real
          StreamBuilder(
            stream: _dbRef.child('orders').limitToLast(5).onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                Map values = snapshot.data!.snapshot.value as Map;
                return Column(
                  children: values.entries.map((e) {
                    final data = Map<String, dynamic>.from(e.value as Map);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.history, color: Colors.blue),
                        title: Text("Pedido #${e.key.toString().substring(0, 5)}"),
                        subtitle: Text("Estado: ${data['status'] ?? 'Pendiente'}"),
                        trailing: Text("\$${data['total'] ?? '0.00'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                );
              }
              return const Center(child: Text("Cargando actividad reciente..."));
            },
          ),
        ],
      ),
    );
  }

  // Widget genérico para métricas que escuchan la DB
  Widget _buildRealtimeMetric({
    required String path,
    required String title,
    required IconData icon,
    required Color color,
    required String Function(int) formatter,
  }) {
    return StreamBuilder(
      stream: _dbRef.child(path).onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        int count = 0;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value;
          if (data is Map) {
            count = data.length;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                formatter(count),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
