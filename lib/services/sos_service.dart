import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:another_telephony/telephony.dart';
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
      autoStart: false,
      notificationChannelId: 'sos_service',
      initialNotificationTitle: "SOS Emergency",
      initialNotificationContent: "Sending SOS messages every 3 min",
      foregroundServiceTypes: [
        AndroidForegroundType.dataSync,
        AndroidForegroundType.location,
      ],
    ),
    iosConfiguration: IosConfiguration(),
  );
}

/// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final telephony = Telephony.instance;
  //final prefs = await SharedPreferences.getInstance();
  bool isRunning = true;

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: "SOS Emergency",
      content: "Sending SOS messages every 3 min",
    );
  }

  // Listen for stop commands from main app
  service.on('stopService').listen((event) async {
    isRunning = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sos_active', false);
    // if (service is AndroidServiceInstance) {
    //   await service.setForegroundNotificationInfo(
    //     title: "SOS Stopped",
    //     content: "Background SOS Stopped",
    //   );
    // }
    await service.stopSelf();
  });

  Timer.periodic(const Duration(minutes: 3), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool('sos_active') ?? true;

    if (!isRunning || !isActive) {
      timer.cancel();
      await service.stopSelf();
      return;
    }

    // if (!isActive) {
    //   timer.cancel();
    //   service.stopSelf();
    //   return;
    // }

    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: "SOS Active",
        content: "Last message sent at ${DateTime.now()}",
      );
    }

    final savedContacts = await DBHelper.getContacts();
    if (savedContacts.isEmpty) return;

    try {
      final position = await LocationService.getCurrentLocation();
      final lat = position.latitude;
      final lng = position.longitude;
      final locationUrl = "http://maps.google.com/maps?q=$lat,$lng";
      final baseMessage = await ContextDBHelper.getContexts();
      final message = "$baseMessage $locationUrl";

      for (var contact in savedContacts) {
        final phone = contact['phone'];
        try {
          await telephony.sendSms(to: phone, message: message);
        } catch (e) {
          print("Issue happened");
        }
        await Future.delayed(const Duration(seconds: 20));
      }
    } catch (e) {
      print("Error during SOS cycle: $e");
    }
  });
}
