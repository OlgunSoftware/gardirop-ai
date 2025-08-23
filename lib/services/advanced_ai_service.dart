// lib/services/advanced_ai_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/clothing_item.dart';
import '../services/database_helper.dart';

class AdvancedAIService {
  // API key is loaded securely from environment or --dart-define
  static String get _apiKey {
    const fromDefine = String.fromEnvironment('OPENAI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromEnv = Platform.environment['OPENAI_API_KEY'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    throw Exception('OpenAI API key missing. Provide OPENAI_API_KEY via --dart-define or environment.');
  }
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static final DatabaseHelper _db = DatabaseHelper();

  // AŞAMA 1: Envanter Tarama
  static Future<void> analyzeWardrobe() async {
    print('🔍 Gardırop analizi başlatıldı...');
    
    // Analiz edilmemiş kıyafetleri al
    final unanalyzedItems = await _db.getUnanalyzedItems();
    
    if (unanalyzedItems.isEmpty) {
      print('✅ Tüm kıyafetler zaten analiz edilmiş');
      return;
    }

    print('📊 ${unanalyzedItems.length} kıyafet analiz edilecek');

    // 25'lik gruplar halinde işle
    for (int i = 0; i < unanalyzedItems.length; i += 25) {
      final batch = unanalyzedItems.skip(i).take(25).toList();
      print('🔄 Grup ${(i~/25)+1} analiz ediliyor... (${batch.length} kıyafet)');
      
      try {
        await _analyzeBatch(batch);
        print('✅ Grup ${(i~/25)+1} tamamlandı');
        
        // API rate limit için kısa bekleme
        await Future.delayed(Duration(seconds: 2));
        
      } catch (e) {
        print('❌ Grup ${(i~/25)+1} hatası: $e');
      }
    }
    
    print('🎉 Gardırop analizi tamamlandı!');
  }

  // Batch halinde kıyafet analizi
  static Future<void> _analyzeBatch(List<ClothingItem> batch) async {
    List<Map<String, dynamic>> messageContent = [];
    
    // Ana prompt
    messageContent.add({
      "type": "text",
      "text": '''Sen profesyonel bir moda uzmanısın. Bu kıyafet fotoğraflarını analiz edip her birini etiketleyeceksin.

Her kıyafet için şu JSON formatında yanıt ver:
{
  "items": [
    {
      "name": "fotoğraftaki kıyafet adı",
      "colors": "ana renkler (max 3)",
      "patterns": "desen türü (düz/çizgili/puantiyeli/desenli)",
      "style": "stil (casual/formal/sporty/elegant/trendy)",
      "season": "mevsim uygunluğu (yazlık/kışlık/geçiş/her_mevsim)",
      "formality": "formalite seviyesi (çok_rahat/rahat/orta/şık/çok_şık)",
      "material": "materyal tahmini (pamuk/polyester/denim/deri/yün/vb)",
      "confidence": "analiz güveni (1-100)"
    }
  ]
}

ÖNEMLI: Her fotoğrafı sırayla analiz et, isim eşleştirmesine dikkat et.

İşte analiz edilecek kıyafetler:'''
    });

    // Fotoğrafları ekle
    for (final item in batch) {
      try {
        final file = File(item.imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          
          messageContent.add({
            "type": "image_url",
            "image_url": {
              "url": "data:image/jpeg;base64,$base64Image",
              "detail": "high"
            }
          });
          
          messageContent.add({
            "type": "text",
            "text": '↑ Kıyafet: "${item.name}" (${item.category})'
          });
        }
      } catch (e) {
        print('Resim yükleme hatası ${item.name}: $e');
      }
    }

    // API çağrısı
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [{'role': 'user', 'content': messageContent}],
        'max_tokens': 2000,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      await _saveAnalysisResults(content, batch);
    } else {
      throw Exception('API hatası: ${response.statusCode}');
    }
  }

  // Analiz sonuçlarını kaydet
  static Future<void> _saveAnalysisResults(String response, List<ClothingItem> batch) async {
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
      final items = data['items'] as List;
      
      for (int i = 0; i < items.length && i < batch.length; i++) {
        final analysis = items[i];
        final clothingItem = batch[i];
        
        await _db.updateAIAnalysis(clothingItem.id!, {
          'colors': analysis['colors'],
          'patterns': analysis['patterns'],
          'style': analysis['style'],
          'season': analysis['season'],
          'formality': analysis['formality'],
          'material': analysis['material'],
          'confidence': analysis['confidence'],
        });
        
        print('✅ ${clothingItem.name} analizi kaydedildi');
      }
      
    } catch (e) {
      print('❌ Analiz kaydetme hatası: $e');
      // Fallback: Kıyafetleri "analiz edildi" olarak işaretle
      for (final item in batch) {
        await _db.updateAIAnalysis(item.id!, {
          'colors': 'Bilinmiyor',
          'patterns': 'Düz',
          'style': 'Casual',
          'season': 'Her_mevsim',
          'formality': 'Orta',
          'material': 'Bilinmiyor',
          'confidence': 50,
        });
      }
    }
  }

  // AŞAMA 2: Akıllı Kombin Üretme
  static Future<List<SmartOutfitSuggestion>> generateSmartOutfits({
    required String customPrompt,
    int outfitCount = 3,
  }) async {
    
    // Tüm analiz edilmiş kıyafetleri al
    final allItems = await _db.getAllClothingItems();
    final analyzedItems = allItems.where((item) => item.aiAnalyzed).toList();
    
    if (analyzedItems.isEmpty) {
      throw Exception('Önce gardırop analizi yapılmalı');
    }

    // Kıyafet açıklamalarını oluştur
    String wardrobeDescription = _buildSmartWardrobeDescription(analyzedItems);

    final prompt = '''Sen uzman bir moda danışmanısın. Aşağıdaki detaylı analiz edilmiş kıyafetlerden $outfitCount farklı kombin önerisi yap.

KULLANICI TALEBİ: "$customPrompt"

ANALIZ EDİLMİŞ KIYAFETLERİM:
$wardrobeDescription

KURALLAR:
1. SADECE verilen kıyafetleri kullan
2. $outfitCount tamamen FARKLI kombin öner
3. Her kombinде renk uyumu ve stil uyumu olsun
4. Kıyafet isimlerini TAM OLARAK yaz
5. Mevsim ve formalite uygunluğuna dikkat et
6. Kullanıcı talebini karşıla

SADECE şu JSON formatında yanıt ver:
{
  "outfits": [
    {
      "name": "Kombin adı",
      "top": "üst kıyafet adı",
      "bottom": "alt kıyafet adı",
      "shoes": "ayakkabı adı",
      "accessory": "aksesuar adı veya yok",
      "explanation": "Bu kombini neden seçtim",
      "style_analysis": "Renk ve stil analizi",
      "occasion_match": "Hangi durumlara uygun",
      "confidence": 90,
      "season_suitability": "Mevsim uygunluğu"
    }
  ]
}''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Sen çok deneyimli bir moda danışmanısın. Kıyafet analizlerini kullanarak mükemmel kombinler öneriyorsun.'
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.8,
          'max_tokens': 3000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return _parseSmartOutfits(content, analyzedItems);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Smart AI hatası: ${response.statusCode} - ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Smart kombin önerisi alınamadı: $e');
    }
  }

  // Akıllı gardırop açıklaması
  static String _buildSmartWardrobeDescription(List<ClothingItem> items) {
    StringBuffer buffer = StringBuffer();
    
    // Kategorilere ayır
    Map<String, List<ClothingItem>> categories = {};
    for (final item in items) {
      if (!categories.containsKey(item.category)) {
        categories[item.category] = [];
      }
      categories[item.category]!.add(item);
    }
    
    categories.forEach((category, categoryItems) {
      buffer.writeln('\n🏷️ $category kategorisi (${categoryItems.length} adet):');
      for (final item in categoryItems) {
        buffer.writeln('  • ${item.aiDescription}');
      }
    });
    
    return buffer.toString();
  }

  // Smart outfit parsing
  static List<SmartOutfitSuggestion> _parseSmartOutfits(String response, List<ClothingItem> wardrobe) {
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
      final outfits = data['outfits'] as List;
      
      return outfits.map((outfit) => SmartOutfitSuggestion(
        name: outfit['name'] ?? 'Kombin',
        top: _findClothingByName(wardrobe, outfit['top']),
        bottom: _findClothingByName(wardrobe, outfit['bottom']),
        shoes: _findClothingByName(wardrobe, outfit['shoes']),
        accessory: _findClothingByName(wardrobe, outfit['accessory']),
        explanation: outfit['explanation'] ?? '',
        styleAnalysis: outfit['style_analysis'] ?? '',
        occasionMatch: outfit['occasion_match'] ?? '',
        confidence: (outfit['confidence'] as num?)?.toInt() ?? 80,
        seasonSuitability: outfit['season_suitability'] ?? '',
      )).toList();
      
    } catch (e) {
      print('Smart outfit parse hatası: $e');
      throw Exception('Smart outfit parse hatası: $e');
    }
  }

  // Gelişmiş kıyafet bulma
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
    
    // 2. Kısmi eşleşme
    for (final item in wardrobe) {
      if (item.name.toLowerCase().contains(name) || name.contains(item.name.toLowerCase())) {
        return item;
      }
    }
    
    return null;
  }
}

// Smart outfit suggestion model
class SmartOutfitSuggestion {
  final String name;
  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? accessory;
  final String explanation;
  final String styleAnalysis;
  final String occasionMatch;
  final int confidence;
  final String seasonSuitability;

  SmartOutfitSuggestion({
    required this.name,
    this.top,
    this.bottom,
    this.shoes,
    this.accessory,
    required this.explanation,
    required this.styleAnalysis,
    required this.occasionMatch,
    required this.confidence,
    required this.seasonSuitability,
  });
}