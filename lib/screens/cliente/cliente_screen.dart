import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class ClienteScreen extends StatefulWidget {
  final UserModel user;
  const ClienteScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ClienteScreen> createState() => _ClienteScreenState();
}

class _ClienteScreenState extends State<ClienteScreen> {
  final _authService = AuthService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  int _currentIndex = 0;
  Map<String, int> _carrito = {}; // productId: cantidad
  Map<String, dynamic> _productosInfo = {}; // productId: {nombre, precio, imagen, restaurantId, restaurantName}
  String? _activeOrderId;
  Map<String, dynamic>? _activeOrder;
  StreamSubscription<DatabaseEvent>? _orderSubscription;
  StreamSubscription<DatabaseEvent>? _userSecuritySubscription;

  // Controladores del formulario de checkout
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _direccionPrincipalCtrl = TextEditingController();
  final _direccionSecundariaCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
    _listenToSecurityStatus();
    _listenToActiveOrder();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _userSecuritySubscription?.cancel();
    _chatCtrl.dispose();
    _chatScrollController.dispose();
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _direccionPrincipalCtrl.dispose();
    _direccionSecundariaCtrl.dispose();
    _referenciaCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  void _checkInitialStatus() async {
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

  void _loadUserProfile() async {
    final snapshot = await _dbRef.child('users').child(widget.user.id).get();
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      setState(() {
        _nombresCtrl.text = data['nombres'] ?? '';
        _apellidosCtrl.text = data['apellidos'] ?? '';
        _telefonoCtrl.text = data['telefono'] ?? '';
        _correoCtrl.text = data['correo'] ?? '';
      });
    }
  }

  void _listenToActiveOrder() {
    _orderSubscription = _dbRef.child('orders').orderByChild('clienteId').equalTo(widget.user.id).onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map orders = event.snapshot.value as Map;
        var activeOrders = orders.entries.where((e) {
          var status = e.value['status'];
          return status != 'entregado' && status != 'cancelado';
        }).toList();

        if (activeOrders.isNotEmpty) {
          setState(() {
            _activeOrderId = activeOrders.first.key;
            _activeOrder = Map<String, dynamic>.from(activeOrders.first.value);
          });

          // Si el pedido fue aceptado, mostrar notificacion
          if (_activeOrder!['status'] == 'aceptado' && _activeOrder!['notifiedAccepted'] != true) {
            _dbRef.child('orders').child(_activeOrderId!).update({'notifiedAccepted': true});
            _showOrderAcceptedDialog();
          }

          // Si el pedido fue entregado, mostrar dialogo de calificacion
          if (_activeOrder!['status'] == 'entregado' && _activeOrder!['rated'] != true) {
            _showRatingDialog();
          }
        } else {
          setState(() {
            _activeOrderId = null;
            _activeOrder = null;
          });
        }
      } else {
        setState(() {
          _activeOrderId = null;
          _activeOrder = null;
        });
      }
    });
  }

  void _showOrderAcceptedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green[100], shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 30),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Pedido Aceptado', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delivery_dining, size: 60, color: Colors.green),
            const SizedBox(height: 15),
            Text('Tu pedido ha sido aceptado por ${_activeOrder?['repartidorNombre'] ?? 'un repartidor'}'),
            const SizedBox(height: 10),
            const Text('Puedes ver su ubicacion en el mapa y chatear con el.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 2); // Ir al mapa
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('VER EN MAPA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    int stars = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Califica tu experiencia', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_activeOrder?['repartidorFoto'] != null)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: MemoryImage(base64Decode(_activeOrder!['repartidorFoto'])),
                ),
              const SizedBox(height: 10),
              Text(_activeOrder?['repartidorNombre'] ?? 'Repartidor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setDialogState(() => stars = i + 1),
                  child: Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 40),
                )),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Deja un comentario (opcional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _dbRef.child('ratings').push().set({
                    'orderId': _activeOrderId,
                    'clienteId': widget.user.id,
                    'repartidorId': _activeOrder?['repartidorId'],
                    'stars': stars,
                    'comment': commentCtrl.text,
                    'timestamp': ServerValue.timestamp,
                  });
                  await _dbRef.child('orders').child(_activeOrderId!).update({'rated': true, 'status': 'entregado'});
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[600]),
                child: const Text('ENVIAR CALIFICACION', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
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
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red[100], shape: BoxShape.circle),
                  child: const Icon(Icons.block, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 10),
                const Flexible(child: Text('ACCESO DENEGADO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red))),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(),
                SizedBox(height: 10),
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 50),
                SizedBox(height: 15),
                Text('Su cuenta ha sido bloqueada. Contacte al administrador. Gracias', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      });
    }
  }

  double _calcularTotal() {
    double total = 0;
    _carrito.forEach((productId, cantidad) {
      if (_productosInfo.containsKey(productId)) {
        total += (_productosInfo[productId]['precio'] ?? 0) * cantidad;
      }
    });
    return total;
  }

  void _agregarAlCarrito(String productId, Map<String, dynamic> productData, String restaurantId, String restaurantName) {
    setState(() {
      _carrito[productId] = (_carrito[productId] ?? 0) + 1;
      _productosInfo[productId] = {
        'nombre': productData['nombre'],
        'precio': (productData['precio'] ?? 0).toDouble(),
        'imagen': productData['imagen'],
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
      };
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${productData['nombre']} agregado al carrito'), duration: const Duration(seconds: 1), backgroundColor: Colors.green),
    );
  }

  void _quitarDelCarrito(String productId) {
    setState(() {
      if (_carrito[productId] != null && _carrito[productId]! > 1) {
        _carrito[productId] = _carrito[productId]! - 1;
      } else {
        _carrito.remove(productId);
        _productosInfo.remove(productId);
      }
    });
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso de ubicacion denegado'), backgroundColor: Colors.red));
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _direccionPrincipalCtrl.text = 'Lat: ${position.latitude.toStringAsFixed(6)}';
        _direccionSecundariaCtrl.text = 'Lng: ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener ubicacion: $e'), backgroundColor: Colors.red));
    }
  }

  void _mostrarCheckout() {
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tu carrito esta vacio'), backgroundColor: Colors.orange));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Finalizar Pedido', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Resumen del carrito
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      ..._carrito.entries.map((e) {
                        final info = _productosInfo[e.key];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${e.value}x ${info?['nombre'] ?? 'Producto'}')),
                              Text('\$${((info?['precio'] ?? 0) * e.value).toStringAsFixed(2)}'),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('\$${_calcularTotal().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[700])),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text('Datos de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),

                TextField(controller: _nombresCtrl, decoration: const InputDecoration(labelText: 'Nombres', prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 10),
                TextField(controller: _apellidosCtrl, decoration: const InputDecoration(labelText: 'Apellidos', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 10),
                TextField(controller: _direccionPrincipalCtrl, decoration: const InputDecoration(labelText: 'Direccion Principal', prefixIcon: Icon(Icons.location_on))),
                const SizedBox(height: 10),
                TextField(controller: _direccionSecundariaCtrl, decoration: const InputDecoration(labelText: 'Direccion Secundaria', prefixIcon: Icon(Icons.location_city))),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _obtenerUbicacionActual,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Usar ubicacion actual'),
                  ),
                ),

                const SizedBox(height: 10),
                TextField(controller: _referenciaCtrl, decoration: const InputDecoration(labelText: 'Referencia', prefixIcon: Icon(Icons.note))),
                const SizedBox(height: 10),
                TextField(controller: _telefonoCtrl, decoration: const InputDecoration(labelText: 'Telefono', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                TextField(controller: _correoCtrl, decoration: const InputDecoration(labelText: 'Correo Electronico', prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _procesarPedido(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text('FINALIZAR PAGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _procesarPedido(BuildContext modalContext) async {
    if (_nombresCtrl.text.isEmpty || _direccionPrincipalCtrl.text.isEmpty || _telefonoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa los campos obligatorios'), backgroundColor: Colors.red));
      return;
    }

    Navigator.pop(modalContext);

    // Obtener info del restaurante del primer producto
    String? restaurantId;
    String? restaurantName;
    String? restaurantImg;
    String? productName;
    String? productImg;

    if (_productosInfo.isNotEmpty) {
      final firstProduct = _productosInfo.values.first;
      restaurantId = firstProduct['restaurantId'];
      restaurantName = firstProduct['restaurantName'];
      productName = firstProduct['nombre'];
      productImg = firstProduct['imagen'];

      // Obtener imagen del restaurante
      final resSnap = await _dbRef.child('restaurants').child(restaurantId!).get();
      if (resSnap.exists) {
        Map resData = resSnap.value as Map;
        restaurantImg = resData['imagen'];
      }
    }

    // CREAR LA ORDEN - SIN nextRepartidorId para que TODOS los repartidores la vean
    final orderRef = _dbRef.child('orders').push();
    await orderRef.set({
      'clienteId': widget.user.id,
      'clienteNombre': '${_nombresCtrl.text} ${_apellidosCtrl.text}',
      'direccionPrincipal': _direccionPrincipalCtrl.text,
      'direccionSecundaria': _direccionSecundariaCtrl.text,
      'referencia': _referenciaCtrl.text,
      'telefono': _telefonoCtrl.text,
      'correo': _correoCtrl.text,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantImg': restaurantImg,
      'productName': productName,
      'productImg': productImg,
      'productos': _carrito.map((k, v) => MapEntry(k, {'cantidad': v, 'nombre': _productosInfo[k]?['nombre'], 'precio': _productosInfo[k]?['precio']})),
      'total': _calcularTotal(),
      'status': 'pendiente',
      'repartidorId': null, // SIN REPARTIDOR ASIGNADO - CUALQUIER REPARTIDOR PUEDE TOMARLO
      'timestamp': ServerValue.timestamp,
    });

    // Limpiar carrito
    setState(() {
      _carrito.clear();
      _productosInfo.clear();
    });

    // Mostrar dialogo de confirmacion
    _showOrderProcessedDialog();
  }

  void _showOrderProcessedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green[100], shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 20),
            const Text('Pedido Procesado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Esperando a un repartidor...', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1); // Ir a revision del pedido
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('VER ESTADO', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: Colors.pink[600],
        foregroundColor: Colors.white,
        actions: [
          if (_currentIndex == 0 && _carrito.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: _mostrarCheckout,
                ),
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${_carrito.values.fold(0, (a, b) => a + b)}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _handleLogout()),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pink[600],
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Revision'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
      floatingActionButton: _currentIndex == 0 && _carrito.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _mostrarCheckout,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.shopping_cart, color: Colors.white),
        label: Text('Carrito (\$${_calcularTotal().toStringAsFixed(2)})', style: const TextStyle(color: Colors.white)),
      )
          : null,
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0: return 'Restaurantes';
      case 1: return 'Estado del Pedido';
      case 2: return 'Mapa de Entrega';
      case 3: return 'Chat';
      case 4: return 'Mi Perfil';
      default: return 'Delivery App';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildRestaurantesView();
      case 1: return _buildRevisionView();
      case 2: return _buildMapaView();
      case 3: return _buildChatView();
      case 4: return _buildPerfilView();
      default: return _buildRestaurantesView();
    }
  }

  Widget _buildRestaurantesView() {
    return StreamBuilder(
      stream: _dbRef.child('restaurants').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No hay restaurantes disponibles', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        Map restaurants = snapshot.data!.snapshot.value as Map;
        var validRestaurants = restaurants.entries.where((e) {
          if (e.value is! Map) return false;
          final nombre = (e.value as Map)['nombre']?.toString().trim() ?? '';
          return nombre.isNotEmpty;
        }).toList();

        if (validRestaurants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No hay restaurantes disponibles', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: validRestaurants.length,
          itemBuilder: (context, index) {
            final entry = validRestaurants[index];
            final data = Map<String, dynamic>.from(entry.value as Map);
            final String id = entry.key;
            final String nombre = data['nombre'] ?? 'Sin nombre';
            final String descripcion = data['descripcion'] ?? '';
            final String imagen = data['imagen'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: InkWell(
                onTap: () => _showRestaurantProducts(id, nombre, imagen, descripcion),
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Imagen redonda
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          image: imagen.isNotEmpty
                              ? DecorationImage(image: MemoryImage(base64Decode(imagen)), fit: BoxFit.cover)
                              : null,
                        ),
                        child: imagen.isEmpty ? const Icon(Icons.restaurant, size: 40, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(descripcion, style: TextStyle(color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRestaurantProducts(String restaurantId, String restaurantName, String restaurantImg, String restaurantDesc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header del restaurante
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.pink[600],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      image: restaurantImg.isNotEmpty
                          ? DecorationImage(image: MemoryImage(base64Decode(restaurantImg)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: restaurantImg.isEmpty ? const Icon(Icons.restaurant, size: 35, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(restaurantName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(restaurantDesc, style: const TextStyle(color: Colors.white70), maxLines: 2),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Lista de productos
            Expanded(
              child: StreamBuilder(
                stream: _dbRef.child('products').orderByChild('restaurantId').equalTo(restaurantId).onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text('No hay productos disponibles'));
                  }

                  Map products = snapshot.data!.snapshot.value as Map;
                  var validProducts = products.entries.where((e) {
                    if (e.value is! Map) return false;
                    final nombre = (e.value as Map)['nombre']?.toString().trim() ?? '';
                    return nombre.isNotEmpty;
                  }).toList();

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: validProducts.length,
                    itemBuilder: (context, index) {
                      final entry = validProducts[index];
                      final productId = entry.key;
                      final productData = Map<String, dynamic>.from(entry.value as Map);
                      final nombre = productData['nombre'] ?? 'Sin nombre';
                      final descripcion = productData['descripcion'] ?? '';
                      final precio = (productData['precio'] ?? 0).toDouble();
                      final imagen = productData['imagen'] ?? '';
                      final cantidadEnCarrito = _carrito[productId] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Imagen del producto
                              Container(
                                width: 70, height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey[200],
                                  image: imagen.isNotEmpty
                                      ? DecorationImage(image: MemoryImage(base64Decode(imagen)), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: imagen.isEmpty ? const Icon(Icons.fastfood, color: Colors.grey) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(descripcion, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2),
                                    const SizedBox(height: 4),
                                    Text('\$${precio.toStringAsFixed(2)}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              // Controles de cantidad
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      if (cantidadEnCarrito > 0)
                                        IconButton(
                                          onPressed: () {
                                            _quitarDelCarrito(productId);
                                            (context as Element).markNeedsBuild();
                                          },
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                        ),
                                      if (cantidadEnCarrito > 0)
                                        Text('$cantidadEnCarrito', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      IconButton(
                                        onPressed: () {
                                          _agregarAlCarrito(productId, productData, restaurantId, restaurantName);
                                          (context as Element).markNeedsBuild();
                                        },
                                        icon: const Icon(Icons.add_circle, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionView() {
    if (_activeOrder == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No tienes pedidos activos', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    String status = _activeOrder!['status'] ?? 'pendiente';
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'pendiente':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'ESPERANDO';
        break;
      case 'aceptado':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'ACEPTADO';
        break;
      case 'rechazado':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'RECHAZADO';
        break;
      case 'en_camino':
        statusColor = Colors.blue;
        statusIcon = Icons.delivery_dining;
        statusText = 'EN CAMINO';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = status.toUpperCase();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Estado del pedido
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Column(
              children: [
                Icon(statusIcon, size: 60, color: statusColor),
                const SizedBox(height: 15),
                Text(statusText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor)),
                if (status == 'pendiente')
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Esperando que un repartidor acepte tu pedido...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                if (status == 'aceptado' && _activeOrder!['repartidorNombre'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('Repartidor: ${_activeOrder!['repartidorNombre']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Detalles del pedido
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detalles del Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restaurant),
                    title: Text(_activeOrder!['restaurantName'] ?? 'Restaurante'),
                    subtitle: Text(_activeOrder!['productName'] ?? ''),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on),
                    title: Text(_activeOrder!['direccionPrincipal'] ?? 'Sin direccion'),
                    subtitle: Text(_activeOrder!['referencia'] ?? ''),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('\$${(_activeOrder!['total'] ?? 0).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[700])),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapaView() {
    if (_activeOrder == null || _activeOrder!['status'] != 'aceptado') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _activeOrder == null
                  ? 'No tienes pedidos activos'
                  : 'El mapa estara disponible cuando un repartidor acepte tu pedido',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Mapa placeholder
        Container(
          color: Colors.blue[50],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delivery_dining, size: 100, color: Colors.pink),
                const SizedBox(height: 20),
                Text('Repartidor: ${_activeOrder!['repartidorNombre']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('En camino a tu ubicacion...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        // Info card
        Positioned(
          bottom: 20, left: 20, right: 20,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_activeOrder!['repartidorFoto'] != null)
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: MemoryImage(base64Decode(_activeOrder!['repartidorFoto'])),
                    )
                  else
                    const CircleAvatar(radius: 25, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_activeOrder!['repartidorNombre'] ?? 'Repartidor', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Text('Tu pedido esta en camino', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _currentIndex = 3),
                    icon: const Icon(Icons.chat, color: Colors.pink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatView() {
    if (_activeOrder == null || _activeOrder!['status'] != 'aceptado') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _activeOrder == null
                  ? 'No tienes pedidos activos'
                  : 'El chat se habilitara cuando un repartidor acepte tu pedido',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header del chat
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
          child: Row(
            children: [
              if (_activeOrder!['repartidorFoto'] != null)
                CircleAvatar(radius: 22, backgroundImage: MemoryImage(base64Decode(_activeOrder!['repartidorFoto'])))
              else
                const CircleAvatar(radius: 22, backgroundColor: Colors.pink, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activeOrder!['repartidorNombre'] ?? 'Repartidor', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text('En linea', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Mensajes
        Expanded(
          child: StreamBuilder(
            stream: _dbRef.child('chats').child(_activeOrderId!).onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snap) {
              if (!snap.hasData || snap.data!.snapshot.value == null) {
                return const Center(child: Text('Inicia una conversacion'));
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

        // Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: _showAttachModal),
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  decoration: InputDecoration(
                    hintText: 'Escribir mensaje...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: _sendMessage,
                child: const CircleAvatar(backgroundColor: Colors.pink, child: Icon(Icons.send, color: Colors.white, size: 20)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubbleChat(String msg, bool isMe, dynamic time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
            Text(msg, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
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

  void _sendMessage() {
    if (_chatCtrl.text.trim().isEmpty || _activeOrderId == null) return;
    _dbRef.child('chats').child(_activeOrderId!).push().set({
      's': widget.user.id,
      'm': _chatCtrl.text,
      't': ServerValue.timestamp,
    });
    _chatCtrl.clear();
  }

  void _showAttachModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.image, color: Colors.green),
            title: const Text('Enviar Foto'),
            onTap: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
              if (image != null && _activeOrderId != null) {
                final bytes = await File(image.path).readAsBytes();
                String base64Img = base64Encode(bytes);
                _dbRef.child('chats').child(_activeOrderId!).push().set({
                  's': widget.user.id,
                  'm': '[IMAGEN]',
                  'img': base64Img,
                  't': ServerValue.timestamp,
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.blue),
            title: const Text('Enviar Video'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funcion de video proximamente')));
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPerfilView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 60,
            backgroundColor: Colors.pink,
            child: Icon(Icons.person, size: 70, color: Colors.white),
          ),
          const SizedBox(height: 15),
          Text(widget.user.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Cliente', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Editar Informacion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(),
                  const SizedBox(height: 10),
                  TextField(controller: _nombresCtrl, decoration: const InputDecoration(labelText: 'Nombres', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 15),
                  TextField(controller: _apellidosCtrl, decoration: const InputDecoration(labelText: 'Apellidos', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 15),
                  TextField(controller: _correoCtrl, decoration: const InputDecoration(labelText: 'Correo Electronico', prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  TextField(controller: _telefonoCtrl, decoration: const InputDecoration(labelText: 'Telefono', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardarPerfil,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[600], padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: const Text('GUARDAR CAMBIOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _guardarPerfil() async {
    await _dbRef.child('users').child(widget.user.id).update({
      'nombres': _nombresCtrl.text.trim(),
      'apellidos': _apellidosCtrl.text.trim(),
      'correo': _correoCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: Colors.green));
  }
}