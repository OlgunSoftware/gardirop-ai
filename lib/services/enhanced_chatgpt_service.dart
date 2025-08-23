// lib/services/enhanced_chatgpt_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/clothing_item.dart';

class EnhancedChatGPTService {
  // API key is loaded from environment for security
  // Set via: --dart-define=OPENAI_API_KEY=your_key or OS env var OPENAI_API_KEY
  static String get _apiKey {
    const fromDefine = String.fromEnvironment('OPENAI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromEnv = Platform.environment['OPENAI_API_KEY'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    throw Exception('OpenAI API key missing. Provide OPENAI_API_KEY via --dart-define or environment.');
  }
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  // Text-based AI ile kombin önerisi (Custom Prompt)
  static Future<TextOutfitSuggestion> getTextOutfitRecommendation({
    required List<ClothingItem> wardrobe,
    required String customPrompt,
  }) async {
    
    if (wardrobe.isEmpty) {
      throw Exception('Kombin için kıyafet bulunamadı');
    }

    // Kategorilere göre kıyafetleri ayır
    final Map<String, List<ClothingItem>> categorizedItems = {};
    for (final item in wardrobe) {
      final category = item.category.toLowerCase();
      if (!categorizedItems.containsKey(category)) {
        categorizedItems[category] = [];
      }
      categorizedItems[category]!.add(item);
    }

    // Detaylı kıyafet listesi oluştur
    String wardrobeDescription = _buildDetailedWardrobeDescription(categorizedItems);

    final prompt = '''
Sen profesyonel bir moda danışmanısın. Kullanıcının talebine göre mevcut kıyafetlerinden uygun kombin önerisi yapacaksın.

KULLANICI TALEBİ: "$customPrompt"

MEVCUT KIYAFETLERİM (kategori bazlı):
$wardrobeDescription

ÖNEMLİ KURALLAR:
1. SADECE mevcut kıyafetlerimi kullan
2. Her kategoriden (üst, alt, ayakkabı) en az 1 kıyafet öner
3. Eğer bir kategoride kıyafet yoksa "yok" yaz
4. Kıyafet isimlerini TAM OLARAK yazarken kullan
5. Renk uyumu ve stil uyumuna dikkat et
6. Kullanıcının talebini mümkün olduğunca karşıla

SADECE şu JSON formatında yanıtla:
{
  "top": "kıyafet adı veya yok",
  "bottom": "kıyafet adı veya yok", 
  "shoes": "kıyafet adı veya yok",
  "accessory": "kıyafet adı veya yok",
  "explanation": "Bu kombini neden seçtiğimi ve kullanıcı talebini nasıl karşıladığımı detaylı açıkla",
  "style_tips": "Bu kombin için ek stil önerileri",
  "confidence": 85,
  "user_request_match": "Kullanıcı talebini ne kadar karşıladığım (1-10)"
}''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-o5-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Sen profesyonel bir moda danışmanısın. Kullanıcının mevcut kıyafetlerini analiz ederek özel isteklerine uygun kombin önerileri yapıyorsun.'
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 600,
        }),
      );

      print('Text AI Response Status: ${response.statusCode}');
      print('Text AI Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return _parseTextResponse(content, wardrobe);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Text AI hatası: ${response.statusCode} - ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Text kombin önerisi alınamadı: $e');
    }
  }

  // Vision API ile kombin önerisi (Görsel Analiz)
  static Future<VisionOutfitSuggestion> getVisionOutfitRecommendation({
    required List<ClothingItem> wardrobe,
    required String customPrompt,
  }) async {
    
    List<Map<String, dynamic>> messageContent = [];
    
    // Ana prompt ekle
    messageContent.add({
      "type": "text",
      "text": '''Sen profesyonel bir moda danışmanısın. Bu kıyafet fotoğraflarına bakarak kombin önerisi yapacaksın.

KULLANICI TALEBİ: "$customPrompt"

Her fotoğraftaki kıyafetin rengini, desenini, stilini, materyalini analiz et. 
Kullanıcının talebine uygun EN UYGUN kombini öner.

ÖNEMLİ KURALLAR:
1. SADECE gösterilen kıyafetleri kullan
2. TÜM KIYAFETLERİ DEĞERLENDİR
3. Kıyafet isimlerini TAMAMEN doğru yaz
4. Renk harmony ve görsel uyum ÖNCELİK
5. Farklılık göster - hep aynı kombini önerme

SADECE şu JSON formatında yanıtla:
{
  "top": "kıyafet adı",
  "bottom": "kıyafet adı", 
  "shoes": "kıyafet adı",
  "accessory": "kıyafet adı veya yok",
  "explanation": "DETAYLI görsel analiz",
  "style_tips": "Görsel uyum ve stil önerileri",
  "confidence": 85,
  "color_analysis": "Renk analizi",
  "user_request_match": "1-10 uyum skoru"
}

İşte kıyafetlerim:'''
    });
    
    // BASIT: Tüm kıyafetleri karıştır
    final shuffledWardrobe = List<ClothingItem>.from(wardrobe);
    shuffledWardrobe.shuffle();
    
    // API limiti (maksimum 25)
    final maxItems = shuffledWardrobe.length > 25 ? 25 : shuffledWardrobe.length;
    
    int itemCount = 0;
    for (final item in shuffledWardrobe.take(maxItems)) {
      try {
        final file = File(item.imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          
          // Resim ekle
          messageContent.add({
            "type": "image_url",
            "image_url": {
              "url": "data:image/jpeg;base64,$base64Image",
              "detail": "high"
            }
          });
          
          // Basit açıklama
          messageContent.add({
            "type": "text",
            "text": '''↑ "${item.name}" (${item.category})${item.description != null ? ' - ${item.description}' : ''}'''
          });
          
          itemCount++;
        }
      } catch (e) {
        print('Resim yükleme hatası ${item.name}: $e');
      }
    }
    
    if (itemCount == 0) {
      throw Exception('Hiçbir kıyafet resmi yüklenemedi');
    }

    // Basit özet
    messageContent.add({
      "type": "text",
      "text": '''
📋 TOPLAM: $itemCount kıyafet
🎯 GÖREV: "${customPrompt}" için EN UYGUN kombini seç
⚠️ Farklı kombinler dene!'''
    });
    
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'user',
              'content': messageContent,
            }
          ],
          'max_tokens': 1000,
          'temperature': 0.8, // Yaratıcılık
        }),
      );

      print('Vision API Response Status: ${response.statusCode}');
      print('Analiz edilen kıyafet sayısı: $itemCount');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return _parseVisionResponse(content, wardrobe);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Vision API hatası: ${response.statusCode} - ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Vision kombin önerisi alınamadı: $e');
    }
  }

  // Detaylı kıyafet açıklaması oluştur
  static String _buildDetailedWardrobeDescription(Map<String, List<ClothingItem>> categorizedItems) {
    StringBuffer buffer = StringBuffer();
    
    categorizedItems.forEach((category, items) {
      buffer.writeln('\n🏷️ $category kategorisi (${items.length} adet):');
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        buffer.write('  ${i + 1}. "${item.name}"');
        if (item.description != null && item.description!.isNotEmpty) {
          buffer.write(' - ${item.description}');
        }
        buffer.writeln();
      }
    });
    
    return buffer.toString();
  }

  // Kategori sayısını hesapla
  static Map<String, int> _getCategoryCount(List<ClothingItem> wardrobe) {
    final Map<String, int> count = {};
    for (final item in wardrobe) {
      final category = item.category;
      count[category] = (count[category] ?? 0) + 1;
    }
    return count;
  }

  // Text response parse
  static TextOutfitSuggestion _parseTextResponse(String response, List<ClothingItem> wardrobe) {
    try {
      String cleanJson = response.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      
      int jsonStart = cleanJson.indexOf('{');
      int jsonEnd = cleanJson.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        cleanJson = cleanJson.substring(jsonStart, jsonEnd + 1);
      }
      
      final data = jsonDecode(cleanJson);
      
      return TextOutfitSuggestion(
        top: _findClothingByName(wardrobe, data['top']),
        bottom: _findClothingByName(wardrobe, data['bottom']),
        shoes: _findClothingByName(wardrobe, data['shoes']),
        accessory: _findClothingByName(wardrobe, data['accessory']),
        explanation: data['explanation'] as String? ?? 'Text AI ile analiz edildi',
        styleTips: data['style_tips'] as String?,
        confidence: (data['confidence'] as num?)?.toInt() ?? 80,
        userRequestMatch: (data['user_request_match'] as num?)?.toInt() ?? 5,
        isTextBased: true,
      );
    } catch (e) {
      print('Text JSON parse hatası: $e');
      throw Exception('Text yanıt formatı hatalı: $e');
    }
  }

  // Vision response parse (güncellendi)
  static VisionOutfitSuggestion _parseVisionResponse(String response, List<ClothingItem> wardrobe) {
    try {
      String cleanJson = response.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      
      int jsonStart = cleanJson.indexOf('{');
      int jsonEnd = cleanJson.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        cleanJson = cleanJson.substring(jsonStart, jsonEnd + 1);
      }
      
      print('Temizlenmiş JSON: $cleanJson'); // Debug için
    
      final data = jsonDecode(cleanJson);
      
      return VisionOutfitSuggestion(
        top: _findClothingByName(wardrobe, data['top']),
        bottom: _findClothingByName(wardrobe, data['bottom']),
        shoes: _findClothingByName(wardrobe, data['shoes']),
        accessory: _findClothingByName(wardrobe, data['accessory']),
        explanation: data['explanation'] as String? ?? 'Vision AI ile analiz edildi',
        styleTips: data['style_tips'] as String?,
        confidence: (data['confidence'] as num?)?.toInt() ?? 80,
        colorAnalysis: data['color_analysis'] as String? ?? 'Renk analizi yapıldı',
        userRequestMatch: (data['user_request_match'] as num?)?.toInt() ?? 5,
        isVisionBased: true,
      );
    } catch (e) {
      print('Vision JSON parse hatası: $e');
      print('Ham yanıt: $response');
      throw Exception('Vision yanıt formatı hatalı: $e');
    }
  }

  // Geliştirilmiş kıyafet bulma
  static ClothingItem? _findClothingByName(List<ClothingItem> wardrobe, dynamic nameData) {
    if (nameData == null) return null;
    
    String name = nameData.toString().toLowerCase().trim();
    if (name.isEmpty || name == 'yok' || name == 'null') return null;
    
    // 1. Tam eşleşme
    for (final item in wardrobe) {
      if (item.name.toLowerCase().trim() == name) {
        return item;
      }
    }
    
    // 2. Kısmi eşleşme (isim içerisinde)
    for (final item in wardrobe) {
      if (item.name.toLowerCase().contains(name) || name.contains(item.name.toLowerCase())) {
        return item;
      }
    }
    
    // 3. Kelime bazlı eşleşme
    final searchWords = name.split(' ');
    for (final item in wardrobe) {
      final itemWords = item.name.toLowerCase().split(' ');
      int matchCount = 0;
      for (final word in searchWords) {
        if (itemWords.any((itemWord) => itemWord.contains(word) || word.contains(itemWord))) {
          matchCount++;
        }
      }
      if (matchCount >= searchWords.length * 0.5) { // %50+ eşleşme
        return item;
      }
    }
    
    print('❌ Kıyafet bulunamadı: "$name"');
    print('📋 Mevcut kıyafetler: ${wardrobe.map((e) => e.name).join(", ")}');
    return null;
  }
}

// Text AI için model
class TextOutfitSuggestion {
  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? accessory;
  final String explanation;
  final String? styleTips;
  final int confidence;
  final int userRequestMatch;
  final bool isTextBased;

  TextOutfitSuggestion({
    this.top,
    this.bottom,
    this.shoes,
    this.accessory,
    required this.explanation,
    this.styleTips,
    required this.confidence,
    required this.userRequestMatch,
    this.isTextBased = false,
  });
}

// Vision AI için genişletilmiş model
class VisionOutfitSuggestion {
  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? accessory;
  final String explanation;
  final String? styleTips;
  final int confidence;
  final String colorAnalysis;
  final int userRequestMatch;
  final bool isVisionBased;

  VisionOutfitSuggestion({
    this.top,
    this.bottom,
    this.shoes,
    this.accessory,
    required this.explanation,
    this.styleTips,
    required this.confidence,
    required this.colorAnalysis,
    required this.userRequestMatch,
    this.isVisionBased = false,
  });
}