import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({Key? key}) : super(key: key);

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('users');
  String _selectedFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- FILTROS EXACTOS (Todos, Cliente, Repartidor, Administrador) ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          child: Row(
            children: ['Todos', 'Cliente', 'Repartidor', 'Administrador'].map((filter) {
              bool isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: Colors.pink[600],
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  onSelected: (val) => setState(() => _selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),

        // --- LISTA DE USUARIOS ---
        Expanded(
          child: StreamBuilder(
            stream: _dbRef.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: Text('No hay usuarios registrados.'));
              }

              Map values = snapshot.data!.snapshot.value as Map;
              List<MapEntry> userEntries = values.entries.toList();

              // --- FILTRADO CORREGIDO PARA "Administrador" ---
              List<MapEntry> items = userEntries.where((e) {
                final d = Map<String, dynamic>.from(e.value as Map);
                String role = (d['role'] ?? 'Cliente').toString().toLowerCase();
                
                if (_selectedFilter == 'Todos') return true;
                if (_selectedFilter == 'Administrador') {
                  return role == 'admin' || role == 'administrador';
                }
                return role == _selectedFilter.toLowerCase();
              }).toList();

              if (items.isEmpty) {
                return Center(child: Text('No hay usuarios en la categoría: $_selectedFilter'));
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final key = items[index].key;
                  final userData = Map<String, dynamic>.from(items[index].value as Map);
                  
                  String name = userData['username'] ?? 'Usuario';
                  String role = userData['role'] ?? 'Cliente';
                  String email = userData['email'] ?? 'Sin correo';
                  // Usamos 'bloqueado' como valor de estado para mayor claridad
                  bool isActive = userData['status'] != 'bloqueado';
                  bool isAdmin = role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrador';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    elevation: isActive ? 2 : 0,
                    color: isActive ? Colors.white : Colors.grey[200],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAdmin ? Colors.red : (isActive ? Colors.blue : Colors.grey),
                        child: Icon(isAdmin ? Icons.security : Icons.person, color: Colors.white),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name, 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.black : Colors.grey[600]
                              )
                            )
                          ),
                          // --- ETIQUETA DE ESTADO AL LADO DEL NOMBRE ---
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Text(
                              isActive ? "Estado: Activo" : "Estado: Bloqueado",
                              style: TextStyle(
                                fontSize: 10, 
                                color: isActive ? Colors.green[800] : Colors.red[800], 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text('Email: $email\nRol: $role'),
                      isThreeLine: true,
                      
                      // --- LÓGICA DE SEGURIDAD (TRAILING) ---
                      // Si el usuario es administrador, desaparecen los 3 puntos (null)
                      trailing: isAdmin ? null : PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'toggle_status') {
                            await _dbRef.child(key!).update({
                              'status': isActive ? 'bloqueado' : 'activo'
                            });
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle_status',
                            child: Row(
                              children: [
                                Icon(isActive ? Icons.block : Icons.check_circle, 
                                     color: isActive ? Colors.red : Colors.green),
                                const SizedBox(width: 10),
                                Text(isActive ? 'Bloquear Acceso' : 'Activar Acceso'),
                              ],
                            ),
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
    );
  }
}
