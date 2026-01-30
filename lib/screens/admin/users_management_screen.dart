import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({Key? key}) : super(key: key);

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String _selectedFilter = 'Todos';
  final List<String> _filters = ['Todos', 'Administrador', 'Repartidor', 'Cliente'];
  String _searchQuery = '';

  // Función para bloquear/desbloquear usuario
  Future<void> _toggleBlockUser(String userId, String currentStatus, String username, String role) async {
    // Verificar que no sea administrador
    if (role.toLowerCase() == 'administrador') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede bloquear a un administrador'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool isCurrentlyBlocked = currentStatus == 'bloqueado';
    final String newStatus = isCurrentlyBlocked ? 'activo' : 'bloqueado';
    final String actionText = isCurrentlyBlocked ? 'desbloquear' : 'bloquear';

    // Mostrar diálogo de confirmación
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCurrentlyBlocked ? Icons.lock_open : Icons.block,
              color: isCurrentlyBlocked ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isCurrentlyBlocked ? 'Desbloquear Usuario' : 'Bloquear Usuario',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que deseas $actionText a este usuario?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(role),
                    child: Icon(_getRoleIcon(role), color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(role, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isCurrentlyBlocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El usuario será expulsado inmediatamente si está conectado.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyBlocked ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isCurrentlyBlocked ? 'DESBLOQUEAR' : 'BLOQUEAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbRef.child('users').child(userId).update({'status': newStatus});

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isCurrentlyBlocked
                    ? 'Usuario "$username" desbloqueado exitosamente'
                    : 'Usuario "$username" bloqueado exitosamente'
            ),
            backgroundColor: isCurrentlyBlocked ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar usuario: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'repartidor': return Colors.blue;
      case 'cliente': return Colors.green;
      case 'administrador': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'repartidor': return Icons.delivery_dining;
      case 'cliente': return Icons.person;
      case 'administrador': return Icons.admin_panel_settings;
      default: return Icons.person;
    }
  }

  Widget _buildUserCard(String id, Map<String, dynamic> userData) {
    final String username = userData['username']?.toString() ?? 'Sin nombre';
    final String role = userData['role']?.toString() ?? 'desconocido';
    final String status = userData['status']?.toString() ?? 'activo';
    final bool isBlocked = status == 'bloqueado';
    final bool isAdmin = role.toLowerCase() == 'administrador';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isBlocked ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isBlocked
            ? BorderSide(color: Colors.red[300]!, width: 1.5)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isBlocked ? Colors.red[50] : Colors.white,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: isBlocked ? Colors.grey : _getRoleColor(role),
                child: Icon(
                  _getRoleIcon(role),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              if (isBlocked)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  username,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isBlocked ? Colors.grey[600] : Colors.black87,
                    decoration: isBlocked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (isBlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'BLOQUEADO',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: _getRoleColor(role),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ID: ${id.substring(0, 8)}...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          trailing: isAdmin
              ? Tooltip(
            message: 'Los administradores no pueden ser bloqueados',
            child: Icon(Icons.shield, color: Colors.purple[300], size: 28),
          )
              : IconButton(
            onPressed: () => _toggleBlockUser(id, status, username, role),
            icon: Icon(
              isBlocked ? Icons.lock_open : Icons.block,
              color: isBlocked ? Colors.green : Colors.red,
            ),
            tooltip: isBlocked ? 'Desbloquear usuario' : 'Bloquear usuario',
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: _dbRef.child('users').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No hay usuarios registrados',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final Map usersMap = snapshot.data!.snapshot.value as Map;

        // Filtrar por rol y búsqueda
        final filteredUsers = usersMap.entries.where((entry) {
          final userData = Map<String, dynamic>.from(entry.value as Map);
          final String role = userData['role']?.toString().toLowerCase() ?? '';
          final String username = userData['username']?.toString().toLowerCase() ?? '';

          // Filtro por rol
          bool matchesRole = true;
          if (_selectedFilter != 'Todos') {
            matchesRole = role == _selectedFilter.toLowerCase();
          }

          // Filtro por búsqueda
          final bool matchesSearch = _searchQuery.isEmpty ||
              username.contains(_searchQuery.toLowerCase());

          return matchesRole && matchesSearch;
        }).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedFilter == 'Repartidor' ? Icons.delivery_dining
                      : _selectedFilter == 'Cliente' ? Icons.person
                      : _selectedFilter == 'Administrador' ? Icons.admin_panel_settings
                      : Icons.people_outline,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? (_selectedFilter == 'Todos'
                      ? 'No hay usuarios registrados'
                      : 'No hay ${_selectedFilter.toLowerCase()}es registrados')
                      : 'No se encontraron resultados',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Ordenar: bloqueados al final
        filteredUsers.sort((a, b) {
          final statusA = (a.value as Map)['status']?.toString() ?? 'activo';
          final statusB = (b.value as Map)['status']?.toString() ?? 'activo';
          if (statusA == 'bloqueado' && statusB != 'bloqueado') return 1;
          if (statusA != 'bloqueado' && statusB == 'bloqueado') return -1;
          return 0;
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final entry = filteredUsers[index];
            final userData = Map<String, dynamic>.from(entry.value as Map);
            return _buildUserCard(entry.key, userData);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de búsqueda
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Buscar usuario...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _searchQuery = ''),
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Filtros con FilterChip
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                bool isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filter == 'Todos' ? Icons.people
                              : filter == 'Administrador' ? Icons.admin_panel_settings
                              : filter == 'Repartidor' ? Icons.delivery_dining
                              : Icons.person,
                          size: 16,
                          color: isSelected ? Colors.pink[600] : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(filter),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = filter);
                    },
                    selectedColor: Colors.pink[100],
                    checkmarkColor: Colors.pink[600],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.pink[600] : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),

        // Lista de usuarios
        Expanded(
          child: _buildUserList(),
        ),
      ],
    );
  }
}