import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('users');

  // Verificar permisos de ubicación
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  // MÉTODO NUEVO: Activar rastreo y subir a Firebase
  void startRealtimeTracking(String userId) async {
    final hasPermission = await checkLocationPermission();
    if (!hasPermission) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Se actualiza cada 10 metros de movimiento
      ),
    ).listen((Position position) {
      _dbRef.child(userId).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdate': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      return null;
    }
  }

  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
