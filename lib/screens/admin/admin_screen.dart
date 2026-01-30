import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'delivery_map_screen.dart';
import 'users_management_screen.dart';
import 'reports_screen.dart';

class AdminScreen extends StatefulWidget {
  final UserModel user;
  const AdminScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _authService = AuthService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  
  int _currentIndex = 0;
  String? _selectedRestaurantId;
  String? _selectedRestaurantName;

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Future<String?> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 40);
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      debugPrint("Error al capturar imagen: $e");
    }
    return null;
  }

  void _showImageSourceDialog(Function(String) onImageSelected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Origen de la Imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.pink),
              title: const Text('Galería de fotos'),
              onTap: () async {
                Navigator.pop(context);
                String? b64 = await _pickImage(ImageSource.gallery);
                if (b64 != null) onImageSelected(b64);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.pink),
              title: const Text('Tomar Foto'),
              onTap: () async {
                Navigator.pop(context);
                String? b64 = await _pickImage(ImageSource.camera);
                if (b64 != null) onImageSelected(b64);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRestaurantForm({String? id, String? currentName, String? currentDesc, String? currentImg}) {
    final nameCtrl = TextEditingController(text: currentName);
    final descCtrl = TextEditingController(text: currentDesc);
    String b64Image = currentImg ?? '';

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
              children: [
                Text(id == null ? 'Crear Restaurante' : 'Editar Restaurante', 
                     style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () => _showImageSourceDialog((img) => setModalState(() => b64Image = img)),
                  child: Container(
                    height: 120, width: 120,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.pink.withOpacity(0.3))),
                    child: b64Image.isEmpty 
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), Text("Cargar Imagen", style: TextStyle(fontSize: 10))]) 
                      : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(base64Decode(b64Image), fit: BoxFit.cover)),
                  ),
                ),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del Restaurante')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[600], foregroundColor: Colors.white),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty) return;
                      final data = {'nombre': nameCtrl.text, 'descripcion': descCtrl.text, 'imagen': b64Image};
                      id == null ? await _dbRef.child('restaurants').push().set(data) : await _dbRef.child('restaurants').child(id).update(data);
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('GUARDAR RESTAURANTE'),
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

  void _showProductForm(String resId, {String? id, String? currentName, String? currentDesc, String? currentImg}) {
    final nameCtrl = TextEditingController(text: currentName);
    final descCtrl = TextEditingController(text: currentDesc);
    String b64Image = currentImg ?? '';

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
              children: [
                Text(id == null ? 'Nuevo Producto' : 'Editar Producto', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () => _showImageSourceDialog((img) => setModalState(() => b64Image = img)),
                  child: Container(
                    height: 120, width: 120,
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange)),
                    child: b64Image.isEmpty 
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.fastfood, size: 40, color: Colors.orange), Text("Cargar Imagen", style: TextStyle(fontSize: 10))]) 
                      : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(base64Decode(b64Image), fit: BoxFit.cover)),
                  ),
                ),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del Producto')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty) return;
                      final data = {'nombre': nameCtrl.text, 'descripcion': descCtrl.text, 'imagen': b64Image, 'restaurantId': resId};
                      id == null ? await _dbRef.child('products').push().set(data) : await _dbRef.child('products').child(id).update(data);
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('GUARDAR PRODUCTO'),
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

  @override
  Widget build(BuildContext context) {
    bool isViewingProducts = _currentIndex == 2 && _selectedRestaurantId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isViewingProducts ? 'Productos: $_selectedRestaurantName' : 'Panel Admin'),
        backgroundColor: Colors.pink[600],
        foregroundColor: Colors.white,
        leading: isViewingProducts 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedRestaurantId = null))
          : null,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout)],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() { _currentIndex = index; _selectedRestaurantId = null; }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pink[600],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Restaurantes'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuarios'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reportes'),
        ],
      ),
      floatingActionButton: _currentIndex == 2 ? FloatingActionButton(
        backgroundColor: Colors.pink[600],
        onPressed: () => _selectedRestaurantId == null ? _showRestaurantForm() : _showProductForm(_selectedRestaurantId!),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildDashboard();
      case 1: return const DeliveryMapScreen();
      case 2: return _selectedRestaurantId == null ? _buildRestaurantsList() : _buildProductsList(_selectedRestaurantId!);
      case 3: return const UsersManagementScreen();
      case 4: return const ReportsScreen();
      default: return _buildDashboard();
    }
  }

  Widget _buildRestaurantsList() {
    return StreamBuilder(
      stream: _dbRef.child('restaurants').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text('No hay restaurantes creados.'));
        Map values = snapshot.data!.snapshot.value as Map;
        return ListView(
          children: values.entries.map((e) {
            final data = Map<String, dynamic>.from(e.value as Map);
            final String name = data['nombre']?.toString() ?? 'Sin nombre';
            final String desc = data['descripcion']?.toString() ?? 'Sin descripción';
            final String img = data['imagen']?.toString() ?? '';

            return Card(
              child: ListTile(
                leading: img.isNotEmpty 
                  ? Image.memory(base64Decode(img), width: 40, height: 40, fit: BoxFit.cover) 
                  : const Icon(Icons.restaurant),
                title: Text(name),
                subtitle: Text(desc),
                onTap: () => setState(() { _selectedRestaurantId = e.key; _selectedRestaurantName = name; }),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showRestaurantForm(id: e.key, currentName: name, currentDesc: desc, currentImg: img)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _dbRef.child('restaurants').child(e.key).remove()),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildProductsList(String resId) {
    return StreamBuilder(
      stream: _dbRef.child('products').orderByChild('restaurantId').equalTo(resId).onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text('Sin productos en este local.'));
        Map values = snapshot.data!.snapshot.value as Map;
        return ListView(
          children: values.entries.map((e) {
            final data = Map<String, dynamic>.from(e.value as Map);
            final String name = data['nombre']?.toString() ?? 'Sin nombre';
            final String desc = data['descripcion']?.toString() ?? 'Sin descripción';
            final String img = data['imagen']?.toString() ?? '';

            return Card(
              color: Colors.orange[50],
              child: ListTile(
                leading: img.isNotEmpty 
                  ? Image.memory(base64Decode(img), width: 40, height: 40, fit: BoxFit.cover) 
                  : const Icon(Icons.fastfood),
                title: Text(name),
                subtitle: Text(desc),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showProductForm(resId, id: e.key, currentName: name, currentDesc: desc, currentImg: img)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _dbRef.child('products').child(e.key).remove()),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDashboard() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Bienvenido, ${widget.user.username}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      ElevatedButton.icon(icon: const Icon(Icons.restaurant), label: const Text("Gestionar Restaurantes"), onPressed: () => setState(() => _currentIndex = 2)),
    ]));
  }
}
