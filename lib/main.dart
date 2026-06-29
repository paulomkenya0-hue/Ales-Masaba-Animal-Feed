import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/strings_sw.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/sales_provider.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('sw'); // huwezesha DateFormat ya tarehe kwa Kiswahili
  runApp(const AlesMasabaApp());
}

/// AlesMasabaApp - Sehemu kuu ya programu. Lugha: Kiswahili pekee.
class AlesMasabaApp extends StatelessWidget {
  const AlesMasabaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: SW.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        // Kiswahili pekee - hakuna tafsiri ya Kiingereza inayohitajika kwa sababu
        // maandishi yote yameandikwa moja kwa moja kwa Kiswahili katika SW (strings_sw.dart)
        locale: const Locale('sw'),
        supportedLocales: const [Locale('sw')],
        home: const SplashScreen(),
      ),
    );
  }
}
