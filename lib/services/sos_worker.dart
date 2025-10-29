import 'dart:async';

import 'package:workmanager/workmanager.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './location_service.dart';
import './contact_database.dart';
import './context_database.dart';

const String sosTask = "sos_background_task";

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == sosTask) {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('sos_active') ?? false;

      if (!isActive) {
        return Future.value(true);
      }

      final telephony = Telephony.instance;

      try {
        final contacts = await DBHelper.getContacts();
        if (contacts.isEmpty) return Future.value(true);

        final position = await LocationService.getCurrentLocation();
        final lat = position.latitude;
        final lng = position.longitude;
        final locationURL = "http://maps.google.com/maps?q=$lat,$lng";
        final baseMessage = await ContextDBHelper.getContexts();
        final message = "$baseMessage $locationURL";

        for (var contact in contacts) {
          final phone = contact['phone'];
          await telephony.sendSms(to: phone, message: message);
          await Future.delayed(const Duration(seconds: 10));
        }
      } catch (e) {
        print("Error");
      }
    }

    return Future.value(true);
  });
}
