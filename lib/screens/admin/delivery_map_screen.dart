import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

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
    _checkPermissions(); // Verificar permisos al iniciar
    _listenToRepartidores();
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _listenToRepartidores() {
    _dbRef.orderByChild('role').equalTo('repartidor').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final Map<MarkerId, Marker> newMarkers = {};

      data.forEach((key, value) {
        final repartidor = Map<String, dynamic>.from(value);
        if (repartidor['latitude'] != null && repartidor['longitude'] != null) {
          final markerId = MarkerId(key);
          newMarkers[markerId] = Marker(
            markerId: markerId,
            position: LatLng(repartidor['latitude'], repartidor['longitude']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            infoWindow: InfoWindow(title: repartidor['username']),
          );
        }
      });
      if (mounted) setState(() => _markers = newMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-2.9018, -79.0061),
          zoom: 14,
        ),
        markers: Set<Marker>.of(_markers.values),
        onMapCreated: (controller) => _mapController = controller,
        // CAMBIO A SATÉLITE
        mapType: MapType.satellite, 
        myLocationEnabled: true, // Ahora funcionará porque pedimos permiso en initState
        myLocationButtonEnabled: true,
      ),
    );
  }
}
