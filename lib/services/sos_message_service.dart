import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './location_service.dart';
import './contact_database.dart';
import './context_database.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // const channel = AndroidNotificationChannel(
  //   'sos_channel',
  //   'SOS Emergency  Channel',
  //   description: 'Foreground service channel for SOS messages',
  //   importance: Importance.high,
  // );

  // final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  // await flutterLocalNotificationsPlugin
  //     .resolvePlatformSpecificImplementation<
  //       AndroidFlutterLocalNotificationsPlugin
  //     >()
  //     ?.createNotificationChannel(channel);

  await service.configure(
    iosConfiguration: IosConfiguration(),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      autoStartOnBoot: false,
      initialNotificationTitle: "SOS Emergency Active",
      initialNotificationContent: "Sending SOS every 3 minutes",
      foregroundServiceTypes: [
        AndroidForegroundType.dataSync,
        AndroidForegroundType.location,
      ],
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final telephony = Telephony.instance;
  final prefs = await SharedPreferences.getInstance();

  final active = prefs.getBool('sos_active') ?? false;
  if (!active) {
    service.stopSelf();
    return;
  }

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "SOS Emergency Running",
      content: "Waiting to send message...",
    );
  }

  Timer.periodic(const Duration(minutes: 3), (timer) async {
    final active = prefs.getBool('sos_active') ?? false;
    if (!active) {
      timer.cancel();
      service.stopSelf();
      return;
    }

    final contacts = await DBHelper.getContacts();
    if (contacts.isEmpty) return;

    final location = await LocationService.getCurrentLocation();
    final messageBase = await ContextDBHelper.getContexts();
    final message =
        "$messageBase http://maps.google.com/maps?q=${location.latitude},${location.longitude}";

    for (var contact in contacts) {
      try {
        await telephony.sendSms(to: contact['phone'], message: message);
        await Future.delayed(const Duration(seconds: 15));
      } catch (e) {
        print("SMS failed: $e");
      }
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "SOS Emergency Active",
        content: "Last message sent at ${DateTime.now()}",
      );
    }
  });
}
