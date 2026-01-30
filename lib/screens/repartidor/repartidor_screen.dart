import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

// Funcion global para manejar notificaciones en segundo plano
@pragma('vm:entry-point')
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
  final ImagePicker _picker = ImagePicker();

  int _currentIndex = 0;
  String? _activeOrderId;
  Map<String, dynamic>? _activeOrder;
  bool _isLoading = false;
  StreamSubscription<DatabaseEvent>? _ordersSubscription;
  StreamSubscription<DatabaseEvent>? _userSecuritySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _setupNotifications();
    _listenToOrders();
    _verificarRegistroVehiculo();
    _listenToSecurityStatus();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _userSecuritySubscription?.cancel();
    _chatCtrl.dispose();
    _chatScrollController.dispose();
    _vehiculoCtrl.dispose();
    _placaCtrl.dispose();
    super.dispose();
  }

  void _checkInitialStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final snapshot = await _dbRef.child('users').child(widget.user.id).child('status').get();
    if (snapshot.exists && snapshot.value == 'bloqueado') {
      _handleLogout(forced: true);
    }
  }

  void _listenToSecurityStatus() {
    _userSecuritySubscription = _dbRef.child('users').child(widget.user.id).child('status').onValue.listen((event) {
      if (event.snapshot.value == 'bloqueado') {
        _handleLogout(forced: true);
      }
    });
  }

  void _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token = await messaging.getToken();
    if (token != null) {
      await _dbRef.child('users').child(widget.user.id).update({'fcmToken': token});
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showInAppNotification(message.notification!.title, message.notification!.body);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App abierta desde notificacion: ${message.data}');
    });
  }

  void _showInAppNotification(String? title, String? body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title ?? "Nueva Notificacion", style: const TextStyle(fontWeight: FontWeight.bold)),
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
      if (data['vehiculo'] == null || data['placa'] == null) {
        Future.delayed(Duration.zero, () => _showRegistroVehiculoDialog());
      }
    }
  }

  void _showRegistroVehiculoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Informacion del Vehiculo", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Completa tus datos para empezar a recibir pedidos."),
            const SizedBox(height: 15),
            TextField(
              controller: _vehiculoCtrl,
              decoration: InputDecoration(
                  hintText: "Ej: Moto Pulsar 200",
                  labelText: "Vehiculo",
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Datos guardados con exito"), backgroundColor: Colors.green)
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
      case 0: return "Gestion de Pedidos";
      case 1: return "Mapa de Entrega";
      case 2: return "Chat Directo";
      case 3: return "Balance de Ganancias";
      case 4: return "Perfil del Repartidor";
      default: return "Delivery App";
    }
  }

  Future<void> _updateProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await File(image.path).readAsBytes();
      String base64Image = base64Encode(bytes);
      await _dbRef.child('users').child(widget.user.id).update({'profileImg': base64Image});
      if (_activeOrderId != null) {
        await _dbRef.child('orders').child(_activeOrderId!).update({'repartidorFoto': base64Image});
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto de perfil actualizada"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al procesar imagen"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
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
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _handleLogout()),
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
          return _noOrdersUI("No hay ordenes en el sistema");
        }
        Map orders = snapshot.data!.snapshot.value as Map;

        var incoming = orders.entries.where((e) {
          var val = e.value;
          String status = val['status']?.toString() ?? '';
          String? repartidorId = val['repartidorId']?.toString();

          bool isPendiente = status == 'pendiente';
          bool sinRepartidor = repartidorId == null || repartidorId.isEmpty || repartidorId == 'null';

          return isPendiente && sinRepartidor;
        }).toList();

        if (incoming.isEmpty) {
          return _noOrdersUI("Esperando nuevas solicitudes...");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: incoming.length,
          itemBuilder: (context, index) {
            var entry = incoming[index];
            var data = Map<String, dynamic>.from(entry.value);
            var orderId = entry.key;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              child: Column(
                children: [
                  if (data['restaurantImg'] != null && data['restaurantImg'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      child: Image.memory(base64Decode(data['restaurantImg']), height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                data['restaurantName'] ?? "Restaurante",
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "\$${(data['total'] ?? 0).toStringAsFixed(2)}",
                                style: TextStyle(fontSize: 18, color: Colors.green[700], fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Cliente: ${data['clienteNombre'] ?? 'Sin nombre'}",
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                data['direccionPrincipal'] ?? 'Sin direccion',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (data['referencia'] != null && data['referencia'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.note, size: 18, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Ref: ${data['referencia']}",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 24),
                        const Text("PRODUCTOS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        if (data['productos'] != null)
                          ...((data['productos'] as Map).entries.map((p) {
                            var prod = p.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text("${prod['cantidad']}x ${prod['nombre'] ?? 'Producto'}")),
                                  Text("\$${((prod['precio'] ?? 0) * (prod['cantidad'] ?? 1)).toStringAsFixed(2)}"),
                                ],
                              ),
                            );
                          }).toList())
                        else
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: data['productImg'] != null && data['productImg'].toString().isNotEmpty
                                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(data['productImg']), width: 50, height: 50, fit: BoxFit.cover))
                                : const CircleAvatar(child: Icon(Icons.fastfood)),
                            title: Text(data['productName'] ?? "Producto"),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rechazarPedido(orderId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("RECHAZAR", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _aceptarPedido(orderId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("ACEPTAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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

  // CORREGIDO: Metodo _buildMapaView sin Stack problematico
  Widget _buildMapaView() {
    if (_activeOrder == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Debes aceptar una orden para ver el mapa",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    String direccion = _activeOrder!['direccionPrincipal'] ?? 'Sin direccion';
    String direccionSecundaria = _activeOrder!['direccionSecundaria'] ?? '';
    String referencia = _activeOrder!['referencia'] ?? '';
    String clienteNombre = _activeOrder!['clienteNombre'] ?? 'Cliente';
    String telefono = _activeOrder!['telefono'] ?? '';

    double? lat;
    double? lng;

    if (direccion.contains('Lat:')) {
      try {
        lat = double.parse(direccion.replaceAll('Lat:', '').trim());
      } catch (e) {
        lat = null;
      }
    }
    if (direccionSecundaria.contains('Lng:')) {
      try {
        lng = double.parse(direccionSecundaria.replaceAll('Lng:', '').trim());
      } catch (e) {
        lng = null;
      }
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue[100]!, Colors.blue[50]!],
              ),
            ),
            child: lat != null && lng != null
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.location_on, size: 60, color: Colors.red[600]),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "COORDENADAS DEL CLIENTE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Lat: ${lat.toStringAsFixed(6)}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        "Lng: ${lng.toStringAsFixed(6)}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () => _abrirEnGoogleMaps(lat!, lng!),
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text("Abrir en Google Maps"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 80, color: Colors.pink[300]),
                const SizedBox(height: 16),
                const Text(
                  "Direccion del cliente:",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    direccion,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (direccionSecundaria.isNotEmpty && !direccionSecundaria.contains('Lng:'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      direccionSecundaria,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.pink[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: Colors.pink[600]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clienteNombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (telefono.isNotEmpty)
                            Text(
                              telefono,
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                    if (telefono.isNotEmpty)
                      IconButton(
                        onPressed: () => _llamarCliente(telefono),
                        icon: const Icon(Icons.phone, color: Colors.green),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green[50],
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: Colors.red[400], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            direccion,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (direccionSecundaria.isNotEmpty && !direccionSecundaria.contains('Lng:'))
                            Text(
                              direccionSecundaria,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          if (referencia.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "Ref: $referencia",
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _currentIndex = 2),
                        icon: const Icon(Icons.chat),
                        label: const Text("CHAT"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.pink[600],
                          side: BorderSide(color: Colors.pink[600]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _finalizarPedidoCompleto,
                        icon: const Icon(Icons.check_circle),
                        label: const Text("ENTREGADO"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _abrirEnGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir Google Maps"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _llamarCliente(String telefono) async {
    final url = Uri.parse('tel:$telefono');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Llamar a: $telefono"), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Llamar a: $telefono"), backgroundColor: Colors.blue),
      );
    }
  }

  Widget _buildChatView() {
    if (_activeOrder == null) {
      return const Center(child: Text("El chat se habilitara cuando aceptes una orden"));
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
                  const Text("En linea", style: TextStyle(color: Colors.green, fontSize: 12)),
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
                return const Center(child: Text("Inicia una conversacion con el cliente"));
              }
              Map msgs = snap.data!.snapshot.value as Map;
              var list = msgs.entries.toList()..sort((a, b) => (a.value['t'] ?? 0).compareTo(b.value['t'] ?? 0));

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
              time != null ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(time)) : '',
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
    if (_chatCtrl.text.trim().isEmpty || _activeOrderId == null) return;
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

        double avgRating = 0.0;
        String lastFeedback = "-";

        if (myRatings.isNotEmpty) {
          double sum = 0;
          for (var r in myRatings) { sum += (double.tryParse(r.value['stars'].toString()) ?? 0.0); }
          avgRating = sum / myRatings.length;
          lastFeedback = myRatings.last.value['comment'] ?? "Buen servicio";
        }

        int entregas = myOrders.length;
        int puntos = entregas * 10;
        String nivel = (entregas < 5) ? "Bronce" : (entregas < 20) ? "Plata" : "Oro";

        String displayVehiculo = myData['vehiculo'] ?? "No registrado";
        String displayPlaca = myData['placa'] ?? "No registrada";
        String? profileImgBase64 = myData['profileImg'];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: CircleAvatar(
                      radius: 65,
                      backgroundColor: Colors.pink,
                      backgroundImage: profileImgBase64 != null ? MemoryImage(base64Decode(profileImgBase64)) : null,
                      child: profileImgBase64 == null ? const Icon(Icons.person, size: 85, color: Colors.white) : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: GestureDetector(
                      onTap: _updateProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.pink[600], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: const Icon(Icons.edit, size: 22, color: Colors.white),
                      ),
                    ),
                  ),
                  if (_isLoading) const CircularProgressIndicator(color: Colors.pink),
                ],
              ),
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
              _infoTile(Icons.star, "Mi Reputacion", "${avgRating.toStringAsFixed(1)} / 5.0", Colors.amber),
              _infoTile(Icons.comment, "Feedback de Clientes", lastFeedback, Colors.blue),
              _infoTile(Icons.directions_bike, "Vehiculo", displayVehiculo, Colors.orange),
              _infoTile(Icons.vignette, "Placa", displayPlaca, Colors.deepPurple),
              _infoTile(Icons.verified_user, "Estado de Cuenta", (myData['status'] ?? "Activo").toString().toUpperCase(), Colors.green),
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
        trailing: Text(value, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      ),
    );
  }

  void _aceptarPedido(String id) async {
    final userSnap = await _dbRef.child('users').child(widget.user.id).get();
    String? fotoActual;
    if (userSnap.exists) {
      Map data = userSnap.value as Map;
      fotoActual = data['profileImg'];
    }
    await _dbRef.child('orders').child(id).update({
      'status': 'aceptado',
      'repartidorId': widget.user.id,
      'repartidorNombre': widget.user.username,
      'repartidorFoto': fotoActual,
      'timestamp_aceptado': ServerValue.timestamp,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido aceptado. Dirigete al local."), backgroundColor: Colors.green));
    setState(() => _currentIndex = 1);
  }

  void _rechazarPedido(String id) async {
    await _dbRef.child('orders').child(id).child('rejectedBy').child(widget.user.id).set(true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido rechazado"), backgroundColor: Colors.orange));
  }

  void _finalizarPedidoCompleto() async {
    if (_activeOrderId == null) return;
    await _dbRef.child('orders').child(_activeOrderId!).update({
      'status': 'entregado',
      'timestamp_finalizado': ServerValue.timestamp,
    });
    setState(() => _currentIndex = 4);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Felicidades! Entrega finalizada."), backgroundColor: Colors.green));
  }

  void _handleLogout({bool forced = false}) async {
    await _authService.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );

    if (forced) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.block, color: Colors.red[600], size: 50),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cuenta Bloqueada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Su cuenta ha sido bloqueada. Contacte al administrador. Gracias',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'ENTENDIDO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      });
    }
  }
}