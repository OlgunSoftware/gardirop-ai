import 'package:combiner_ai/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
/*   // Veritabanını reset et (ilk çalışmada)
  final dbHelper = DatabaseHelper();
  await dbHelper.deleteDatabase();
  print('✅ Veritabanı sıfırlandı'); */
  
  // WebView platform ayarı
  WebViewPlatform.instance ??= WebViewPlatform.instance;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gardırop AI',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF2a6a73),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2a6a73),
          brightness: Brightness.light,
          surfaceTint: Colors.transparent,
        ),
        
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}