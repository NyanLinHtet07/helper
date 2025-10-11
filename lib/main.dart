import 'package:flutter/material.dart';
import 'package:helper_app/services/context_database.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'package:telephony_sms/telephony_sms.dart';
import './screens/setting_screen.dart';
import './services/contact_database.dart';
import './services/location_service.dart';

const sosTask = "sosBackgroundTask";

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == sosTask) {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('sos_active') ?? false;

      if (!isActive) return Future.value(true);

      final savedContacts = await DBHelper.getContacts();
      final position = await LocationService.getCurrentLocation();
      final lat = position.latitude;
      final lng = position.longitude;
      final baseMessage = await ContextDBHelper.getContexts();
      final locationUrl = "https://maps.google.com/?q=${lat},${lng}";
      final message = "$baseMessage $locationUrl";

      final telephony = TelephonySMS();
      for (var contact in savedContacts) {
        await telephony.sendSMS(phone: contact['phone'], message: message);
      }
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
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

    final baseMessage = await ContextDBHelper.getContexts();
    final message = "$baseMessage $locationUrl";

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
  }

  Future<void> _loadContexts() async {
    final notes = await ContextDBHelper.getContexts();
  }

  Future<void> _checkSOSStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSOSActive = prefs.getBool('sos_active') ?? false;
    });
  }

  Future<void> _toggleSOS() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isSOSActive) {
      await Workmanager().cancelByUniqueName(sosTask);
      await prefs.setBool('sos_active', false);
      setState(() => _isSOSActive = false);
    } else {
      //Active SOS
      await prefs.setBool('sos_active', true);
      setState(() => _isSOSActive = true);

      // Send immediately first time
      await _sendSOS();

      // Schedule repeating every minutes
      await Workmanager().registerPeriodicTask(
        sosTask,
        sosTask,
        frequency: const Duration(minutes: 15),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadContexts();
    _checkAndRequestPermissions();
    _checkSOSStatus();
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
