import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import './screens/geolocation_screen.dart';
import './screens/contact_screen.dart';
import './screens/setting_screen.dart';

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

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      // appBar: AppBar(
      //   // title: Text(
      //   //   localizations?.emergencyHelper ?? 'Helper',
      //   //   style: const TextStyle(
      //   //     fontSize: 20,
      //   //     fontWeight: FontWeight.bold,
      //   //     color: Colors.red,
      //   //   ),
      //   // ),
      //   // actions: [
      //   //   IconButton(
      //   //     onPressed: () {
      //   //       Navigator.push(
      //   //         context,
      //   //         MaterialPageRoute(builder: (_) => const SettingScreen()),
      //   //       );
      //   //     },
      //   //     icon: const Icon(Icons.settings, size: 28),
      //   //   ),
      //   // ],
      // ),
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
                child: Semantics(
                  label: 'Send Help Button',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations?.sendEmergency ??
                                'Emergency Alert Sent!',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
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
