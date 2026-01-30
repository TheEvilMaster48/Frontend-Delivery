import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

// Función global para manejar notificaciones en segundo plano/app cerrada
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Manejando mensaje en segundo plano: ${message.messageId}");
}

class RepartidorScreen extends StatefulWidget {
  final UserModel user;
  const RepartidorScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<RepartidorScreen> createState() => _RepartidorScreenState();
}

class _RepartidorScreenState extends State<RepartidorScreen> {
  final _authService = AuthService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _vehiculoCtrl = TextEditingController();
  final TextEditingController _placaCtrl = TextEditingController();
  
  int _currentIndex = 4; 
  String? _activeOrderId;
  Map<String, dynamic>? _activeOrder;
  bool _isLoading = false;
  StreamSubscription<DatabaseEvent>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _listenToOrders();
    _verificarRegistroVehiculo();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _chatCtrl.dispose();
    _chatScrollController.dispose();
    _vehiculoCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  // Configuración para recibir notificaciones 24/7
  void _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Solicitar permisos (iOS/Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Obtener Token para envío de notificaciones personalizadas
    String? token = await messaging.getToken();
    if (token != null) {
      await _dbRef.child('users').child(widget.user.id).update({'fcmToken': token});
    }

    // Escuchar cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showInAppNotification(message.notification!.title, message.notification!.body);
      }
    });

    // Escuchar cuando se abre la app desde una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App abierta desde notificación: ${message.data}');
    });
  }

  void _showInAppNotification(String? title, String? body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title ?? "Nueva Notificación", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body ?? ""),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _verificarRegistroVehiculo() async {
    final snapshot = await _dbRef.child('users').child(widget.user.id).get();
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      // Si alguno de los campos falta, forzar la pantalla emergente
      if (data['vehiculo'] == null || data['placa'] == null) {
        Future.delayed(Duration.zero, () => _showRegistroVehiculoDialog());
      }
    }
  }

  void _showRegistroVehiculoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Obligatorio: no se cierra tocando fuera
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Información del Vehículo", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Completa tus datos para empezar a recibir pedidos."),
            const SizedBox(height: 15),
            TextField(
              controller: _vehiculoCtrl,
              decoration: InputDecoration(
                hintText: "Ej: Moto Pulsar 200",
                labelText: "Vehículo",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _placaCtrl,
              decoration: InputDecoration(
                hintText: "Ej: P-123456",
                labelText: "Placa",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (_vehiculoCtrl.text.trim().isNotEmpty && _placaCtrl.text.trim().isNotEmpty) {
                await _dbRef.child('users').child(widget.user.id).update({
                  'vehiculo': _vehiculoCtrl.text.trim(),
                  'placa': _placaCtrl.text.trim().toUpperCase(),
                });
                Navigator.pop(context); // Cierra el modal y queda en la pantalla principal
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Datos guardados con éxito"), backgroundColor: Colors.green)
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[600]),
            child: const Text("GUARDAR Y CONTINUAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _listenToOrders() {
    _ordersSubscription = _dbRef.child('orders').onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map orders = event.snapshot.value as Map;
        var myOrder = orders.entries.where((e) {
          var val = e.value;
          return val['repartidorId'] == widget.user.id && val['status'] != 'entregado';
        }).toList();

        if (mounted) {
          setState(() {
            if (myOrder.isNotEmpty) {
              _activeOrderId = myOrder.first.key;
              _activeOrder = Map<String, dynamic>.from(myOrder.first.value);
            } else {
              _activeOrderId = null;
              _activeOrder = null;
            }
          });
        }
      }
    });
  }

  void _onTabTapped(int index) {
    if (index == 0 && _activeOrderId != null) {
      _showOccupiedAlert();
    } else {
      setState(() => _currentIndex = index);
    }
  }

  void _showOccupiedAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Estado: Ocupado", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Usted se encuentra como ocupado en una entrega. "
          "Para recibir nuevas solicitudes, primero debe finalizar su orden actual.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 4);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("ACEPTAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0: return "Gestión de Pedidos";
      case 1: return "Mapa de Entrega";
      case 2: return "Chat Directo";
      case 3: return "Balance de Ganancias";
      case 4: return "Perfil del Repartidor";
      default: return "Delivery App";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 2,
        title: Text(_getTitle(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.pink[600],
        foregroundColor: Colors.white,
        actions: [
          if (_activeOrderId != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: ElevatedButton.icon(
                onPressed: _finalizarPedidoCompleto,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text("FINALIZAR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pink[600],
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_rounded), label: 'Ganancia'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildPedidosView();
      case 1: return _buildMapaView();
      case 2: return _buildChatView();
      case 3: return _buildGananciasView();
      case 4: return _buildPerfilView();
      default: return const SizedBox();
    }
  }

  Widget _buildPedidosView() {
    return StreamBuilder(
      stream: _dbRef.child('orders').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _noOrdersUI("No hay órdenes en el sistema");
        }
        Map orders = snapshot.data!.snapshot.value as Map;
        var incoming = orders.entries.where((e) {
          var val = e.value;
          return val['status'] == 'pendiente' && val['nextRepartidorId'] == widget.user.id;
        }).toList();

        if (incoming.isEmpty) {
          return _noOrdersUI("Esperando nuevas solicitudes...");
        }

        var data = Map<String, dynamic>.from(incoming.first.value);
        var orderId = incoming.first.key;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
                child: Column(
                  children: [
                    if (data['restaurantImg'] != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: Image.memory(base64Decode(data['restaurantImg']), height: 180, width: double.infinity, fit: BoxFit.cover),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(data['restaurantName'] ?? "Restaurante", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Text("\$${data['total']}", style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text("Cliente: ${data['clienteNombre']}"),
                            ],
                          ),
                          const Divider(height: 30),
                          const Text("DETALLE DEL PRODUCTO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 10),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: data['productImg'] != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(data['productImg']), width: 60, height: 60, fit: BoxFit.cover))
                              : const CircleAvatar(child: Icon(Icons.fastfood)),
                            title: Text(data['productName'] ?? "Producto"),
                            subtitle: Text(data['productDesc'] ?? ""),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _rechazarPedido(orderId),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 15)),
                              child: const Text("RECHAZAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _aceptarPedido(orderId),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                              child: const Text("ACEPTAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _noOrdersUI(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 15),
          Text(msg, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMapaView() {
    if (_activeOrder == null) {
      return const Center(child: Text("Debes tener una orden activa para ver el mapa"));
    }
    return Stack(
      children: [
        Container(
          color: Colors.blue[50],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 100, color: Colors.pink),
                const SizedBox(height: 20),
                Text("Destino: ${_activeOrder!['clienteNombre']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("ID de Cliente: ${_activeOrder!['clienteId']}"),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.directions, color: Colors.blue),
              title: const Text("Indicaciones de Entrega"),
              subtitle: Text(_activeOrder!['productName'] ?? "Sin nombre"),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildChatView() {
    if (_activeOrder == null) {
      return const Center(child: Text("El chat se habilitará cuando aceptes una orden"));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.pink, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_activeOrder!['clienteNombre'] ?? "Cliente", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text("En línea", style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              )
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: _dbRef.child('chats').child(_activeOrderId!).onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
              if (!snap.hasData || snap.data!.snapshot.value == null) {
                return const Center(child: Text("Inicia una conversación con el cliente"));
              }
              Map msgs = snap.data!.snapshot.value as Map;
              var list = msgs.entries.toList()..sort((a, b) => a.value['t'].compareTo(b.value['t']));
              
              return ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(15),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  bool isMe = list[i].value['s'] == widget.user.id;
                  return _bubbleChat(list[i].value['m'], isMe, list[i].value['t']);
                },
              );
            },
          ),
        ),
        _buildChatInputArea(),
      ],
    );
  }

  Widget _bubbleChat(String msg, bool isMe, dynamic time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.pink[600] : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isMe ? 15 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 15),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(msg, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(time)),
              style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: _showAttachModal),
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              decoration: InputDecoration(
                hintText: "Escribir mensaje...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: _sendChatMessage,
            child: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.send, color: Colors.white, size: 20)),
          ),
        ],
      ),
    );
  }

  void _sendChatMessage() {
    if (_chatCtrl.text.trim().isEmpty) return;
    _dbRef.child('chats').child(_activeOrderId!).push().set({
      's': widget.user.id,
      'm': _chatCtrl.text,
      't': ServerValue.timestamp,
    });
    _chatCtrl.clear();
    _chatScrollController.animateTo(_chatScrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _showAttachModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Wrap(
        children: [
          ListTile(leading: const Icon(Icons.file_copy, color: Colors.orange), title: const Text("Documento / PDF"), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.image, color: Colors.green), title: const Text("Imagen / Video"), onTap: () => Navigator.pop(context)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGananciasView() {
    return StreamBuilder(
      stream: _dbRef.child('orders').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text("Sin historial de ganancias"));
        }
        Map allOrders = snapshot.data!.snapshot.value as Map;
        var myCompleted = allOrders.entries.where((e) => e.value['repartidorId'] == widget.user.id && e.value['status'] == 'entregado').toList();
        double total = myCompleted.length * 2.50;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.pink[600], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30))),
              child: Column(
                children: [
                  const Text("TOTAL RECAUDADO", style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
                  Text("\$${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("Entregas completadas: ${myCompleted.length}", style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: myCompleted.length,
                itemBuilder: (context, i) {
                  var item = myCompleted[i].value;
                  var date = DateTime.now().toUtc().subtract(const Duration(hours: 5));
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                      title: Text(item['restaurantName'] ?? "Entregado"),
                      subtitle: Text("Cliente: ${item['clienteNombre']}\n${DateFormat('dd/MM/yyyy HH:mm').format(date)}"),
                      trailing: const Text("+\$2.50", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  );
                },
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildPerfilView() {
    return StreamBuilder(
      stream: _dbRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        Map root = snapshot.data!.snapshot.value as Map;
        Map orders = root['orders'] ?? {};
        Map ratings = root['ratings'] ?? {};
        Map users = root['users'] ?? {};
        Map myData = users[widget.user.id] ?? {};

        var myOrders = orders.entries.where((e) => e.value['repartidorId'] == widget.user.id && e.value['status'] == 'entregado').toList();
        var myRatings = ratings.entries.where((e) => e.value['repartidorId'] == widget.user.id).toList();
        double avgRating = 5.0;
        String lastFeedback = "¡Excelente rapidez!";
        if (myRatings.isNotEmpty) {
          double sum = 0;
          for (var r in myRatings) { sum += (double.tryParse(r.value['stars'].toString()) ?? 5.0); }
          avgRating = sum / myRatings.length;
          lastFeedback = myRatings.last.value['comment'] ?? "Buen servicio";
        }
        int entregas = myOrders.length;
        int puntos = entregas * 10;
        String nivel = (entregas < 5) ? "Bronce" : (entregas < 20) ? "Plata" : "Oro";
        
        // Mostrar Vehículo y Placa en tiempo real
        String displayVehiculo = myData['vehiculo'] ?? "No registrado";
        String displayPlaca = myData['placa'] ?? "";

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(radius: 60, backgroundColor: Colors.white, child: Icon(Icons.person, size: 80, color: Colors.pink)),
              const SizedBox(height: 15),
              Text(widget.user.username, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Text("Repartidor Profesional", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem("Entregas", entregas.toString()),
                    const VerticalDivider(),
                    _statItem("Puntos", puntos.toString()),
                    const VerticalDivider(),
                    _statItem("Nivel", nivel),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _infoTile(Icons.star, "Mi Reputación", "${avgRating.toStringAsFixed(1)} / 5.0", Colors.amber),
              _infoTile(Icons.comment, "Feedback de Clientes", lastFeedback, Colors.blue),
              _infoTile(Icons.directions_bike, "Vehículo", "$displayVehiculo $displayPlaca", Colors.orange),
              _infoTile(Icons.verified_user, "Cuenta Verificada", "Activo", Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _infoTile(IconData icon, String title, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  void _aceptarPedido(String id) async {
    await _dbRef.child('orders').child(id).update({
      'status': 'aceptado',
      'repartidorId': widget.user.id,
      'repartidorNombre': widget.user.username,
      'timestamp_aceptado': ServerValue.timestamp,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido aceptado. Dirígete al local."), backgroundColor: Colors.green));
  }

  void _rechazarPedido(String id) async {
    int nextId = (int.tryParse(widget.user.id) ?? 0) + 1;
    await _dbRef.child('orders').child(id).update({
      'nextRepartidorId': nextId.toString(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido rechazado."), backgroundColor: Colors.red));
  }

  void _finalizarPedidoCompleto() async {
    if (_activeOrderId == null) return;
    await _dbRef.child('orders').child(_activeOrderId!).update({
      'status': 'entregado',
      'timestamp_finalizado': ServerValue.timestamp,
    });
    setState(() => _currentIndex = 4);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Felicidades! Entrega finalizada."), backgroundColor: Colors.green));
  }

  void _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }
}
