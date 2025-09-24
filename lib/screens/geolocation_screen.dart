import 'package:flutter/material.dart';
import '../services/location_service.dart';

class GeolocationScreen extends StatefulWidget {
  const GeolocationScreen({super.key});

  @override
  State<GeolocationScreen> createState() => _GeolocationScreenState();
}

class _GeolocationScreenState extends State<GeolocationScreen> {
  bool isSending = false;
  String status = '';

  Future<void> sendEmergency() async {
    setState(() {
      isSending = true;
      status = 'Fetching location ....';
    });

    try {
      final position = await LocationService.getCurrentLocation();
      final lat = position.latitude;
      final lng = position.longitude;

      debugPrint('Emergency at: $lat, $lng');
      setState(() => status = 'Alert sent with location ($lat, $lng)');
    } catch (e) {
      setState(() => status = 'Failed: $e');
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: isSending ? null : sendEmergency,
              icon: const Icon(Icons.warning, color: Colors.white),
              label: const Text('Send Emergency Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            Text(status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
