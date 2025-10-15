import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:helper_app/services/context_database.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'package:telephony_sms/telephony_sms.dart';
import './screens/setting_screen.dart';
import './services/contact_database.dart';
import './services/location_service.dart';
import './services/sos_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(const Locale('my')),
      child: const AppIntializer(),
    ),
  );
}

class AppIntializer extends StatelessWidget {
  const AppIntializer({super.key});
  @override
  Widget build(BuildContext context) {
    final localProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'Emergency SOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 18),
        ),
      ),
      locale: localProvider.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _telephonySMS = TelephonySMS();
  bool _isSOSActive = false;

  @override
  void initState() {
    super.initState();
    _telephonySMS.requestPermission();
    _checkSOSStatus();
  }

  Future<void> _checkSOSStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSOSActive = prefs.getBool('sos_active') ?? false;
    });
  }

  Future<void> _sendImmediateSOS() async {
    final savedContacts = await DBHelper.getContacts();
    if (savedContacts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No Saved SOS Contacts")));
      return;
    }

    final position = await LocationService.getCurrentLocation();
    final lat = position.latitude;
    final lng = position.longitude;
    final baseMessage = await ContextDBHelper.getContexts();
    final locationUrl = "http://maps.google.com/maps?q=$lat,$lng";
    final message = "$baseMessage $locationUrl";

    for (var contact in savedContacts) {
      final phone = contact['phone'];
      try {
        await _telephonySMS.sendSMS(phone: phone, message: message);
      } catch (e) {
        print("Issue happened");
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  Future<void> _toggleSOS() async {
    final service = FlutterBackgroundService();
    final prefs = await SharedPreferences.getInstance();

    if (_isSOSActive) {
      service.invoke('stopService');

      await prefs.setBool('sos_active', false);
      setState(() => _isSOSActive = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("SOS Deactivated")));
    } else {
      //Active SOS
      await prefs.setBool('sos_active', true);
      setState(() => _isSOSActive = true);

      // Send immediately first time
      await _sendImmediateSOS();
      await service.startService();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("SOS Activated")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                localizations?.emergencyHelper ?? 'Helper',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Center(
                child: Material(
                  color: _isSOSActive ? Colors.deepOrange : Colors.red,
                  shape: CircleBorder(),
                  elevation: 5,
                  child: InkWell(
                    onTap: _toggleSOS,
                    customBorder: CircleBorder(),
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: Text(
                          _isSOSActive ? 'Emergency' : 'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            textBaseline: TextBaseline.alphabetic,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 10.0),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings, size: 24),
                    label: Text('Setting'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
