import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('users');
  GoogleMapController? _mapController;
  Map<MarkerId, Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _listenToRepartidores();
  }

  void _listenToRepartidores() {
    // Filtramos usuarios que sean 'repartidor'
    _dbRef.orderByChild('role').equalTo('repartidor').onValue.listen((event) {
      if (event.snapshot.value == null) return;

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final Map<MarkerId, Marker> newMarkers = {};

      data.forEach((key, value) {
        final repartidor = Map<String, dynamic>.from(value);
        
        // Verificamos que tenga latitud y longitud
        if (repartidor['latitude'] != null && repartidor['longitude'] != null) {
          final markerId = MarkerId(key);
          final position = LatLng(repartidor['latitude'], repartidor['longitude']);
          
          final marker = Marker(
            markerId: markerId,
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.huePink),
            infoWindow: InfoWindow(
              title: repartidor['username'],
              snippet: repartidor['isAvailable'] == true ? 'Disponible' : 'Fuera de servicio',
            ),
          );
          newMarkers[markerId] = marker;
        }
      });

      setState(() {
        _markers = newMarkers;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-2.9018, -79.0061), // Coordenadas de Cuenca, Ecuador
          zoom: 13,
        ),
        markers: Set<Marker>.of(_markers.values),
        onMapCreated: (controller) => _mapController = controller,
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_markers.isNotEmpty) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(_markers.values.first.position),
            );
          }
        },
        label: Text('${_markers.length} Repartidores'),
        icon: const Icon(Icons.delivery_dining),
        backgroundColor: Colors.pink[600],
      ),
    );
  }
}
