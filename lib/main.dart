import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import './services/contact_database.dart';
import 'package:telephony_sms/telephony_sms.dart';
import './screens/setting_screen.dart';
import './services/location_service.dart';

// void main() {
//   runApp(const MyApp());
// }

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => LocaleProvider(const Locale('my')),
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

  Future<List<Map<String, dynamic>>> _loadSavedContacts() async {
    return await DBHelper.getContacts();
  }

  Future<void> _sendSOS() async {
    final savedContacts = await _loadSavedContacts();
    final position = await LocationService.getCurrentLocation();
    final lat = position.latitude;
    final lng = position.longitude;

    final locationUrl = "https://maps.google.com/?q=${lat},${lng}";

    if (savedContacts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No saved SOS contacts")));

      return;
    }

    final message = "SOS! I need help. My location: $locationUrl";

    try {
      for (var contact in savedContacts) {
        await _telephonySMS.sendSMS(phone: contact['phone'], message: message);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SOS Send Successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to send SOS: $e")));
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    await _telephonySMS.requestPermission();
    // If you need to check permission status, use a different API or handle permission result elsewhere.
  }

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
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
                  color: Colors.red,
                  shape: CircleBorder(),
                  elevation: 5,
                  child: InkWell(
                    onTap: _sendSOS,
                    customBorder: CircleBorder(),
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
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
