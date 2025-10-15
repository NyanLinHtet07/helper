import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:telephony_sms/telephony_sms.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './location_service.dart';
import './context_database.dart';
import './contact_database.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      initialNotificationTitle: "SOS Emergency",
      initialNotificationContent: "Sending SOS messages every 3 min",
    ),
    iosConfiguration: IosConfiguration(),
  );
}

/// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Requerst for all plugins in background
  DartPluginRegistrant.ensureInitialized();

  final telephony = TelephonySMS();
  final prefs = await SharedPreferences.getInstance();
  bool isRunning = true;

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "SOS Emergency",
      content: "Sending SOS messages every 3 min",
    );
  }

  // Listen for stop commands from main app
  service.on('stopService').listen((event) async {
    isRunning = false;
    await prefs.setBool('sos_active', false);
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: "SOS Stopped",
        content: "Background SOS Stopped",
      );
    }
    service.stopSelf();
  });

  Timer.periodic(const Duration(minutes: 3), (timer) async {
    if (!isRunning) {
      timer.cancel();
      return;
    }

    final isActive = prefs.getBool('sos_active') ?? false;
    if (!isActive) {
      timer.cancel();
      service.stopSelf();
      return;
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "SOS Active",
        content: "Last message sent at ${DateTime.now()}",
      );
    }

    final savedContacts = await DBHelper.getContacts();
    if (savedContacts.isEmpty) return;

    final position = await LocationService.getCurrentLocation();
    final lat = position.latitude;
    final lng = position.longitude;
    final locationUrl = "http://maps.google.com/maps?q=$lat,$lng";
    final baseMessage = await ContextDBHelper.getContexts();
    final message = "$baseMessage $locationUrl";

    for (var contact in savedContacts) {
      final phone = contact['phone'];
      try {
        await telephony.sendSMS(phone: phone, message: message);
      } catch (e) {
        print("Issue happened");
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  });
}
