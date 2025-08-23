import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RemoveBgService {
  // Remove.bg API anahtarınızı buraya ekleyin
  static const String _apiKey = 'czR5pUqX1T4RWWHa2dGdqBer';
  static const String _apiUrl = 'https://api.remove.bg/v1.0/removebg';
  
  /// Fotoğraftan arkaplanı kaldır ve şeffaf PNG döndür
  static Future<File?> removeBackground(File imageFile) async {
    try {
      print('🔄 Remove.bg API ile arkaplan kaldırma başlıyor...');
      
      // Dosya boyutunu kontrol et (12MB limit)
      final fileSizeInBytes = await imageFile.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      
      if (fileSizeInMB > 12) {
        throw Exception('Dosya boyutu çok büyük. Maksimum 12MB olmalı.');
      }
      
      // Resmi okuyun
      final bytes = await imageFile.readAsBytes();
      
      // API isteği hazırla
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.headers['X-Api-Key'] = _apiKey;
      
      // Resmi request'e ekle
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          bytes,
          filename: 'image.${_getFileExtension(imageFile.path)}',
        ),
      );
      
      // Kalite ayarları
      request.fields['size'] = 'auto';
      request.fields['format'] = 'png';
      
      print('📤 API isteği gönderiliyor...');
      
      // İsteği gönder
      final response = await request.send();
      
      if (response.statusCode == 200) {
        // Başarılı yanıt
        final responseBytes = await response.stream.toBytes();
        
        // Şeffaf PNG'yi geçici dosyaya kaydet
        final outputFile = await _saveTempFile(responseBytes);
        
        print('✅ Arkaplan başarıyla kaldırıldı: ${outputFile.path}');
        return outputFile;
        
      } else {
        // Hata durumu
        final errorBody = await response.stream.bytesToString();
        final errorData = json.decode(errorBody);
        
        String errorMessage = 'API Hatası (${response.statusCode})';
        if (errorData['errors'] != null && errorData['errors'].isNotEmpty) {
          errorMessage = errorData['errors'][0]['title'] ?? errorMessage;
        }
        
        throw Exception(errorMessage);
      }
      
    } catch (e) {
      print('❌ Remove.bg API hatası: $e');
      return null;
    }
  }
  
  /// Dosya uzantısını al
  static String _getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }
  
  /// Yanıtı geçici dosyaya kaydet
  static Future<File> _saveTempFile(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/removebg_$timestamp.png';
    
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    return file;
  }
  
  /// API anahtarının geçerli olup olmadığını kontrol et
  static Future<bool> validateApiKey() async {
    if (_apiKey == 'YOUR_REMOVE_BG_API_KEY_HERE') {
      return false;
    }
    
    try {
      final response = await http.get(
        Uri.parse('https://api.remove.bg/v1.0/account'),
        headers: {'X-Api-Key': _apiKey},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}