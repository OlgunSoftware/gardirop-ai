// screens/outfit_screen.dart
import 'package:combiner_ai/screens/saved_outfits_screen.dart';
import 'package:combiner_ai/services/advanced_ai_service.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/clothing_item.dart';
import '../services/database_helper.dart';
import '../models/saved_outfit.dart';

import '../services/enhanced_chatgpt_service.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  // Seçili kıyafetler
  ClothingItem? _selectedTop;
  ClothingItem? _selectedBottom;
  ClothingItem? _selectedShoes;
  ClothingItem? _selectedAccessory;
  
  // Kategori listesi
  List<ClothingItem> _allItems = [];
  List<String> _availableCategories = [];
  
  // Aktif kategori ve alt kategori
  String _activeCategory = 'Üst';
  String? _selectedSubCategory; // Alt kategori seçimi
  
  // Görünüm modu: 'categories' veya 'items'
  String _viewMode = 'categories';

  // ChatGPT AI durumu - sadece Vision AI kalsın
  bool _isVisionLoading = false;

  // Gardırop analizi durumu
  bool _isAnalyzing = false;

  // Akıllı kombin yükleniyor durumu
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClothingItems();
  }

  Future<void> _loadClothingItems() async {
    final allItems = await _databaseHelper.getAllClothingItems();
    
    setState(() {
      _allItems = allItems;
      // Tüm benzersiz kategorileri al
      _availableCategories = allItems
          .map((item) => item.category)
          .toSet()
          .toList();
      _availableCategories.sort(); // Alfabetik sırala
    });
    
    print('=== MEVCUT KATEGORİLER ===');
    for (var category in _availableCategories) {
      final count = _allItems.where((item) => item.category == category).length;
      print('$category: $count adet');
    }
  }

  // Kategori değiştiğinde view mode'u categories yap
  void _onCategoryChanged(String category) {
    setState(() {
      _activeCategory = category;
      _viewMode = 'categories';
      _selectedSubCategory = null;
    });
  }

  // Alt kategori seçildiğinde view mode'u items yap
  void _onSubCategorySelected(String subCategory) {
    setState(() {
      _selectedSubCategory = subCategory;
      _viewMode = 'items';
    });
  }

  // Aktif kategori ve alt kategoriye göre kıyafetleri getir
  List<ClothingItem> _getCurrentCategoryItems() {
    if (_viewMode == 'categories' || _selectedSubCategory == null) {
      return [];
    }
    
    return _allItems.where((item) => item.category == _selectedSubCategory).toList();
  }

  void _selectClothingItem(ClothingItem item) {
    setState(() {
      // Aktif kategoriye göre hangi slot'a yerleştirileceğini belirle
      switch (_activeCategory) {
        case 'Üst':
          _selectedTop = item;
          break;
        case 'Alt':
          _selectedBottom = item;
          break;
        case 'Ayakkabı':
          _selectedShoes = item;
          break;
        case 'Aksesuar':
          _selectedAccessory = item;
          break;
      }
    });
    
    print('Seçilen: ${item.name} (${item.category}) -> $_activeCategory kategorisine yerleştirildi');
  }

  void _clearOutfit() {
    setState(() {
      _selectedTop = null;
      _selectedBottom = null;
      _selectedShoes = null;
      _selectedAccessory = null;
    });
  }

  void _randomOutfit() {
    if (_allItems.isEmpty) return;
    
    setState(() {
      // Rastgele kıyafetler seç
      final random = DateTime.now().millisecond;
      _selectedTop = _allItems.isNotEmpty ? 
        _allItems[random % _allItems.length] : null;
      _selectedBottom = _allItems.isNotEmpty ? 
        _allItems[(random + 1) % _allItems.length] : null;
      _selectedShoes = _allItems.isNotEmpty ? 
        _allItems[(random + 2) % _allItems.length] : null;
      _selectedAccessory = _allItems.isNotEmpty ? 
        _allItems[(random + 3) % _allItems.length] : null;
    });
  }

  // Kombin kaydetme metodu
  Future<void> _saveOutfit() async {
    // En az bir kıyafet seçili olmalı
    if (_selectedTop == null && _selectedBottom == null && 
        _selectedShoes == null && _selectedAccessory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaydetmek için en az bir kıyafet seçmelisiniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Kombin adı alma dialog'u
    String? outfitName = await _showSaveDialog();
    if (outfitName == null || outfitName.trim().isEmpty) return;

    try {
      final outfit = SavedOutfit(
        name: outfitName.trim(),
        topItemId: _selectedTop?.id,
        bottomItemId: _selectedBottom?.id,
        shoesItemId: _selectedShoes?.id,
        accessoryItemId: _selectedAccessory?.id,
        // createdAt kaldırıldı
      );

      await _databaseHelper.saveOutfit(outfit);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kombin "$outfitName" kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Kombin kaydetme hatası: $e'); // Debug için
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kombin kaydedilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Kombin adı alma dialog'u
  Future<String?> _showSaveDialog() async {
    String outfitName = '';
    
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kombini Kaydet'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Kombin adını girin',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => outfitName = value,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(context).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (outfitName.trim().isNotEmpty) {
                  Navigator.of(context).pop(outfitName.trim());
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  // Kaydedilen kombinleri görüntüleme
  void _showSavedOutfits() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedOutfitsScreen(
          onOutfitSelected: (outfit) async {
            // Seçilen kombini yükle
            final items = await _databaseHelper.loadOutfitItems(outfit);
            setState(() {
              _selectedTop = items['top'];
              _selectedBottom = items['bottom'];
              _selectedShoes = items['shoes'];
              _selectedAccessory = items['accessory'];
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kombin "${outfit.name}" yüklendi'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kombin Oluştur'),
        backgroundColor: const Color(0xFF2a6a73),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ChatGPT AI bölümü - Kompakt sabit boyut
            _buildChatGPTSection(),
            
            // Seçili kıyafetler - Sabit yükseklik
            Container(
              height: MediaQuery.of(context).size.height * 0.66, // Ekranın %60'ı
              child: _buildAvatarSection(),
            ),
            
            // Kategori seçici - Minimal boyut
            _buildCategorySelector(),
            
            // Kıyafet listesi - İçeriğe göre boyut
            Container(
              constraints: const BoxConstraints(
                minHeight: 400, // Minimum yükseklik
                maxHeight: double.infinity, // Maksimum sınır yok
              ),
              child: _buildClothingList(),
            ),
            
            // Alt boşluk
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Avatar bölümünü tam ekran yapmak için optimize edin
  Widget _buildAvatarSection() {
    return Container(
      // height satırını kaldır, çünkü artık parent Container'dan geliyor
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Başlık - Kompakt
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seçili Kombin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                _buildSelectedItemsInfo(),
              ],
            ),
            const SizedBox(height: 12),
            
            // Alt alta 4 slot - Expanded kullan
            Expanded(
              child: Column(
                children: [
                  // Üst kıyafet
                  Expanded(
                    child: _buildSimpleClothingSlot(_selectedTop),
                  ),
                  const SizedBox(height: 6),
                  
                  // Alt kıyafet
                  Expanded(
                    child: _buildSimpleClothingSlot(_selectedBottom),
                  ),
                  const SizedBox(height: 6),
                  
                  // Ayakkabı
                  Expanded(
                    child: _buildSimpleClothingSlot(_selectedShoes),
                  ),
                  const SizedBox(height: 6),
                  
                  // Aksesuar
                  Expanded(
                    child: _buildSimpleClothingSlot(_selectedAccessory),
                  ),
                ],
              ),
            ),
            
            // Alt butonlar
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.clear_all,
                  label: 'Temizle',
                  color: Colors.red,
                  onTap: _clearOutfit,
                ),
                
                _buildActionButton(
                  icon: Icons.save,
                  label: 'Kaydet',
                  color: Colors.green,
                  onTap: _saveOutfit,
                ),
                _buildActionButton(
                  icon: Icons.folder_open,
                  label: 'Kombinler',
                  color: Colors.orange,
                  onTap: _showSavedOutfits,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Aksiyon butonları için helper
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Basit kıyafet slot'u - Sadece resim
  Widget _buildSimpleClothingSlot(ClothingItem? item) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: item != null 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(item.imagePath),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                  );
                },
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: Colors.grey[400],
                size: 48,
              ),
            ),
    );
  }

  Widget _buildSelectedItemsInfo() {
    final selectedCount = [
      _selectedTop,
      _selectedBottom, 
      _selectedShoes,
      _selectedAccessory
    ].where((item) => item != null).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2a6a73).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checkroom,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '$selectedCount/4',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Kategori seçiciyi sabit tutun
  Widget _buildCategorySelector() {
    final categories = ['Üst', 'Alt', 'Ayakkabı', 'Aksesuar'];
    
    return Column(
      children: [
        // Ana kategori seçici
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isActive = _activeCategory == category;
              
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _onCategoryChanged(category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF2a6a73) : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isActive ? const Color(0xFF2a6a73) : Colors.grey[300]!,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: const Color(0xFF2a6a73).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Seçili alt kategori göstergesi (varsa)
        if (_selectedSubCategory != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2a6a73).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2a6a73).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category,
                  size: 16,
                  color: const Color(0xFF2a6a73),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedSubCategory!,
                  style: const TextStyle(
                    color: Color(0xFF2a6a73),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _viewMode = 'categories';
                      _selectedSubCategory = null;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: const Color(0xFF2a6a73),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // _buildClothingList metodunu değiştirin
  Widget _buildClothingList() {
    if (_viewMode == 'categories') {
      return _buildCategoryList();
    } else {
      return _buildItemList();
    }
  }

  // Kategori listesi widget'ı
  Widget _buildCategoryList() {
    if (_availableCategories.isEmpty) {
      return Container(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz kıyafet eklenmemiş',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(_availableCategories.length, (index) {
          final category = _availableCategories[index];
          final itemsCount = _allItems.where((item) => item.category == category).length;
          final firstItem = _allItems.firstWhere((item) => item.category == category);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => _onSubCategorySelected(category),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Kategori önizleme resmi
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: Image.file(
                            File(firstItem.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.checkroom,
                                  color: Colors.grey[400],
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Kategori bilgileri
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$itemsCount adet kıyafet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Ok işareti
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // Öğe listesi widget'ı
  Widget _buildItemList() {
    final items = _getCurrentCategoryItems();
    
    if (items.isEmpty) {
      return Container(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.checkroom_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Bu kategoride kıyafet bulunamadı',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Grid yüksekliğini dinamik hesapla
    final rows = (items.length / 3).ceil();
    final gridHeight = rows * 160.0 + (rows - 1) * 12.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: gridHeight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(), // Ana scroll'a bırak
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = _isItemSelected(item);
          
          return GestureDetector(
            onTap: () => _selectClothingItem(item),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF2a6a73) 
                      : Colors.grey[200]!,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Kıyafet resmi
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: Image.file(
                        File(item.imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[100],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // Kıyafet adı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isItemSelected(ClothingItem item) {
    return item == _selectedTop || 
           item == _selectedBottom || 
           item == _selectedShoes || 
           item == _selectedAccessory;
  }

  // Yeni horizontal empty slot
  Widget _buildEmptySlotHorizontal(IconData icon, Color color, String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: color.withOpacity(0.5),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Debug için kategori sayılarını gösterelim
  void _debugCategoryCounts() {
    print('=== KATEGORI SAYILARI ===');
    print('Toplam kıyafet: ${_allItems.length}');
    print('Mevcut kategoriler: ${_availableCategories.join(", ")}');
    
    // Kategori başına sayıları yazdır
    for (var category in _availableCategories) {
      final count = _allItems.where((item) => item.category == category).length;
      print('$category: $count adet');
    }
    
    print('=== TÜM KIYAFETLERİN KATEGORİLERİ ===');
    for (var item in _allItems) {
      print('${item.name} - ${item.category}');
    }
  }

  // ChatGPT section'ı güncelle
  Widget _buildChatGPTSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2a6a73), Color(0xFF1e5a5f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2a6a73).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 0),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        width: 400,
                        height: 100,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Custom prompt input
          Container(
            margin: const EdgeInsets.only(top: 0),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ne tür kombin istiyorsunuz? (örn: "İş toplantısı için şık kombin", "Rahat günlük kombin")',
                hintStyle: TextStyle(color: Colors.white70, fontSize: 12),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Tek Vision AI butonu - Tam genişlik
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isVisionLoading ? null : _getVisionRecommendation,
              icon: _isVisionLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF2a6a73)),
                      ),
                    )
                  : const Icon(Icons.visibility, color: Color(0xFF2a6a73), size: 20),
              label: Text(
                _isVisionLoading ? 'Gardırop AI Analiz Ediyor...' : 'Gardırop AI ile Kombin Öner',
                style: const TextStyle(
                  color: Color(0xFF2a6a73),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.orange, width: 2),
                ),
                elevation: 2,
              ),
            ),
          ),
          
          // Bilgi metni
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gardırop AI kıyafet fotoğraflarınızı analiz ederek size özel kombin önerir',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // State'e controller ekle
  final TextEditingController _promptController = TextEditingController();

  // Vision recommendation metodu - güncellendi
  Future<void> _getVisionRecommendation() async {
    if (_allItems.isEmpty) {
      _showSnackBar('Vision AI için kıyafet eklemelisiniz!');
      return;
    }
    
    if (_promptController.text.trim().isEmpty) {
      _showSnackBar('Lütfen ne tür kombin istediğinizi yazın!');
      return;
    }
    
    setState(() => _isVisionLoading = true);
    
    try {
      final suggestion = await EnhancedChatGPTService.getVisionOutfitRecommendation(
        wardrobe: _allItems,
        customPrompt: _promptController.text.trim(),
      );
      
      setState(() {
        _selectedTop = suggestion.top;
        _selectedBottom = suggestion.bottom;
        _selectedShoes = suggestion.shoes;
        _selectedAccessory = suggestion.accessory;
      });
      
      _showVisionResultDialog(suggestion);
      
    } catch (e) {
      _showSnackBar('Vision AI önerisi alınamadı: $e');
      print('Vision AI Error: $e');
    } finally {
      setState(() => _isVisionLoading = false);
    }
  }

  // Gardırop analizini başlat
  Future<void> _analyzeWardrobe() async {
    setState(() => _isAnalyzing = true);
    
    try {
      await AdvancedAIService.analyzeWardrobe();
      _showSnackBar('✅ Gardırop analizi tamamlandı!');
    } catch (e) {
      _showSnackBar('❌ Analiz hatası: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // Akıllı kombin öner
  Future<void> _getSmartOutfits() async {
    if (_promptController.text.trim().isEmpty) {
      _showSnackBar('Lütfen ne tür kombin istediğinizi yazın!');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final outfits = await AdvancedAIService.generateSmartOutfits(
        customPrompt: _promptController.text.trim(),
        outfitCount: 3,
      );
      
      _showMultipleOutfitsDialog(outfits);
      
    } catch (e) {
      _showSnackBar('❌ Smart kombin hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Vision result dialog
  void _showVisionResultDialog(VisionOutfitSuggestion suggestion) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.visibility,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vision AI Önerisi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Fotoğraf Analizi • Güven: ${suggestion.confidence}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Güven skoru
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.1),
                      Colors.deepOrange.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircularProgressIndicator(
                      value: suggestion.confidence / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation(Colors.orange),
                      strokeWidth: 3,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bu kombin ${suggestion.confidence}% görsel uyumlu',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Görsel açıklama
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.camera_alt, size: 16, color: Colors.orange),
                        SizedBox(width: 6),
                        Text(
                          'Görsel Analiz:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.explanation,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              
              // Renk analizi
              if (suggestion.colorAnalysis.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.palette, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Text(
                            'Renk Analizi:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.colorAnalysis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Stil önerileri
              if (suggestion.styleTips != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'Stil Önerileri:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.styleTips!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kapat'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveCurrentOutfit();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
    }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2a6a73),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveCurrentOutfit() async {
    // Kombin kaydetme kodunu buraya ekle
    _showSnackBar('Kombin kaydedildi! 🎉');
  }

  // Çoklu kombin gösterme dialog'u
  void _showMultipleOutfitsDialog(List<SmartOutfitSuggestion> outfits) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2a6a73), Color(0xFF1e5a5f)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart AI Kombin Önerileri',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${outfits.length} farklı kombin önerisi',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Kombin listesi
              Expanded(
                child: ListView.builder(
                  itemCount: outfits.length,
                  itemBuilder: (context, index) {
                    final outfit = outfits[index];
                    return _buildOutfitCard(outfit, index);
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Alt buton
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2a6a73),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Kapat',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tek kombin card'ı
  Widget _buildOutfitCard(SmartOutfitSuggestion outfit, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            // Kombin başlığı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2a6a73).withOpacity(0.8),
                    const Color(0xFF2a6a73).withOpacity(0.6),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      outfit.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(outfit.confidence).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${outfit.confidence}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Kombin içeriği
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kıyafet listesi
                  _buildOutfitItems(outfit),
                  
                  const SizedBox(height: 12),
                  
                  // Açıklama
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Stil Analizi:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outfit.explanation,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  
                  // Durum uygunluğu
                  if (outfit.occasionMatch.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, size: 12, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Uygun Durumlar: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.green[700],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              outfit.occasionMatch,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Aksiyon butonları
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _applyOutfit(outfit);
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Uygula', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(color: const Color(0xFF2a6a73)),
                            foregroundColor: const Color(0xFF2a6a73),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _saveSmartOutfit(outfit);
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Kaydet', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2a6a73),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Kombin kıyafetlerini göster
  Widget _buildOutfitItems(SmartOutfitSuggestion outfit) {
    final items = [
      {'label': 'Üst', 'item': outfit.top, 'icon': Icons.checkroom},
      {'label': 'Alt', 'item': outfit.bottom, 'icon': Icons.straighten},
      {'label': 'Ayakkabı', 'item': outfit.shoes, 'icon': Icons.directions_walk},
      {'label': 'Aksesuar', 'item': outfit.accessory, 'icon': Icons.watch},
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((itemData) {
        final item = itemData['item'] as ClothingItem?;
        final label = itemData['label'] as String;
        final icon = itemData['icon'] as IconData;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: item != null ? const Color(0xFF2a6a73).withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: item != null ? const Color(0xFF2a6a73).withOpacity(0.3) : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: item != null ? const Color(0xFF2a6a73) : Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                item?.name ?? 'Yok',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: item != null ? const Color(0xFF2a6a73) : Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Kombini uygula
  void _applyOutfit(SmartOutfitSuggestion outfit) {
    setState(() {
      _selectedTop = outfit.top;
      _selectedBottom = outfit.bottom;
      _selectedShoes = outfit.shoes;
      _selectedAccessory = outfit.accessory;
    });
    
    _showSnackBar('✅ ${outfit.name} kombini uygulandı!');
  }

  // Smart kombin kaydet
  Future<void> _saveSmartOutfit(SmartOutfitSuggestion outfit) async {
    try {
      final savedOutfit = SavedOutfit(
        name: outfit.name,
        topItemId: outfit.top?.id,
        bottomItemId: outfit.bottom?.id,
        shoesItemId: outfit.shoes?.id,
        accessoryItemId: outfit.accessory?.id,
      );

      await _databaseHelper.saveOutfit(savedOutfit);
      _showSnackBar('💾 ${outfit.name} kombini kaydedildi!');
      
    } catch (e) {
      _showSnackBar('❌ Kombin kaydedilirken hata oluştu: $e');
    }
  }
}