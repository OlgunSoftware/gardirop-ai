import 'package:combiner_ai/screens/add_clothing_screen.dart';
import 'package:combiner_ai/widgets/topbar.dart';
import 'package:combiner_ai/widgets/clothing_card.dart'; // ← Bu satırı ekleyin
import 'package:flutter/material.dart';
import '../models/clothing_item.dart';
import '../services/database_helper.dart';
// Açık path ile import

import 'edit_clothing_screen.dart'; // EditClothingScreen için import eklendi
import 'outfit_screen.dart'; // Yeni ekran için import eklendi
import 'favorites_screen.dart'; // Import ekleyin
import 'settings_screen.dart'; // Import ekleyin

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<ClothingItem> _allItems = [];
  List<ClothingItem> _filteredItems = [];
  String _selectedCategory = 'Tümü';

  // Kategori listesini güncelle
  List<String> _customCategories = [];
  List<String> _allCategories = []; // Tüm kategorileri tutan liste

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _loadCustomCategories();
  }

  Future<void> _initializeDatabase() async {
    // Database'i kontrol et ve gerekirse güncelle
    await _databaseHelper.checkAndUpdateDatabase();
    // Sonra verileri yükle
    _loadClothingItems();
  }

  Future<void> _loadClothingItems() async {
    final items = await _databaseHelper.getAllClothingItems();
    setState(() {
      _allItems = items;
      // İlk yüklemede tüm itemları göster
      _filteredItems = items;
      _selectedCategory = 'Tümü'; // Kategoriyi de sıfırla
    });
    
    // Kategorileri de yenile
    await _loadCustomCategories();
  }

  // Özel kategorileri yükle ve tüm kategorileri birleştir
  Future<void> _loadCustomCategories() async {
    try {
      final categories = await _databaseHelper.getCategories();
      setState(() {
        _customCategories = categories;
        // Varsayılan kategoriler + kullanıcı kategorileri
        _allCategories = [
          ...ClothingCategory.values.map((e) => e.displayName),
          ...categories,
        ].toSet().toList(); // Tekrarları önlemek için Set kullan
      });
    } catch (e) {
      print('Kategoriler yüklenemedi: $e');
    }
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'Tümü') {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems
            .where((item) => item.category == category)
            .toList();
      }
    });
  }

  // Favori toggle metodunu ekleyin
  Future<void> _toggleFavorite(ClothingItem item) async {
    try {
      await _databaseHelper.updateFavoriteStatus(item.id!, !item.isFavorite);
      _showSnackBar(
        item.isFavorite 
            ? '${item.name} favorilerden kaldırıldı' 
            : '${item.name} favorilere eklendi',
        isError: false,
      );
      
      // Kategori filtresini koruyarak listeyi yenile
      await _refreshItemsWithCategoryFilter();
    } catch (e) {
      _showSnackBar('Favori durumu güncellenirken hata oluştu: $e', isError: true);
    }
  }

  // Yeni metod: Kategori filtresini koruyarak refresh
  Future<void> _refreshItemsWithCategoryFilter() async {
    final items = await _databaseHelper.getAllClothingItems();
    setState(() {
      _allItems = items;
      // Mevcut kategori filtresini koru
      if (_selectedCategory == 'Tümü') {
        _filteredItems = items;
      } else {
        _filteredItems = items
            .where((item) => item.category == _selectedCategory)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TopBar(),
      body: Column(
        children: [
          // Kategori seçici - Kullanıcı kategorileri dahil
          Container(
            height: 48,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryText('Tümü'),
                // Varsayılan kategoriler
                ...ClothingCategory.values.map(
                  (category) => _buildCategoryText(category.displayName),
                ),
                // Kullanıcı kategorileri
                ..._customCategories.map(
                  (category) => _buildCategoryText(category),
                ),
              ],
            ),
          ),
          
          // İnce Divider
          Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          
          // Kıyafet Listesi
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: _filteredItems.isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.checkroom_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz kıyafet eklenmemiş',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'İlk kıyafetinizi eklemek için + butonuna tıklayın',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      key: ValueKey('grid_$_selectedCategory'),
                      padding: const EdgeInsets.only(top: 8),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          return ClothingCard(
                            item: _filteredItems[index],
                            onDelete: () => _deleteClothingItem(_filteredItems[index]),
                            onFavoriteToggle: () => _toggleFavorite(_filteredItems[index]), // Bu satırı ekleyin
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditClothingScreen(clothingItem: _filteredItems[index]),
                                ),
                              );
                              
                              if (result == true) {
                                // Kategori filtresini koruyarak yenile
                                await _refreshItemsWithCategoryFilter();
                              }
                            },
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final sideWidth = (screenWidth - 55 - 32) / 2; // 55: kamera butonu, 32: padding
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Sol taraf - en sola ve ikinci icon
                  SizedBox(
                    width: sideWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // En sol - kenardan başla
                        Padding(
                          padding: const EdgeInsets.only(left: 0), // Sol kenarda
                          child: _buildBottomBarItem(Icons.home_outlined, 'Anasayfa', true),
                        ),
                        // İkinci icon - ortaya yakın ama biraz mesafeli
                        Padding(
                          padding: const EdgeInsets.only(right: 31), // Orta butona mesafe
                          child: _buildBottomBarItem(Icons.favorite_outline, 'Favoriler', false),
                        ),
                      ],
                    ),
                  ),
                  
                  // Orta - Kamera butonu (sabit genişlik)
                  SizedBox(
                    width: 55,
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2a6a73),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2a6a73).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.white),
                        onPressed: () => _navigateToAddClothing(),
                      ),
                    ),
                  ),
                  
                  // Sağ taraf - üçüncü icon ve en sağa
                  SizedBox(
                    width: sideWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Üçüncü icon - ortaya yakın ama biraz mesafeli
                        Padding(
                          padding: const EdgeInsets.only(left: 33), // Orta butona mesafe
                          child: _buildBottomBarItem(Icons.auto_awesome_outlined, 'Kombin', false),
                        ),
                        // En sağ - kenardan bitir
                        Padding(
                          padding: const EdgeInsets.only(right: 0), // Sağ kenarda
                          child: _buildBottomBarItem(Icons.settings_outlined, 'Ayarlar', false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Kategori metin widget'ı
  Widget _buildCategoryText(String category) {
    final isSelected = _selectedCategory == category;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _filterByCategory(category),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected 
                      ? const Color(0xFF2a6a73) // #2a6a73 renk kodu
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
                child: Text(category),
              ),
              const SizedBox(height: 4),
              // Seçili kategori için altta çizgi - Animasyonlu
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                height: 3,
                width: isSelected ? _getTextWidth(category, const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                )) : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF2a6a73), // #2a6a73 renk kodu
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Metin genişliğini hesaplama metodu
  double _getTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }

  // Bottom bar item widget'ı
  Widget _buildBottomBarItem(IconData icon, String label, bool isSelected) {
    return InkWell(
      onTap: () {
        if (label == 'Favoriler') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FavoritesScreen(),
            ),
          );
        } else if (label == 'Kombin') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OutfitScreen(),
            ),
          );
        } else if (label == 'Ayarlar') { // Yeni eklenen kısım
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected 
                ? const Color(0xFF2a6a73)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected 
                  ? const Color(0xFF2a6a73)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddClothing() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddClothingScreen(),
      ),
    );

    if (result == true) {
      // Kategori filtresini koruyarak yenile
      await _refreshItemsWithCategoryFilter();
      // Kategorileri de yenile
      await _loadCustomCategories();
    }
  }

  Future<void> _deleteClothingItem(ClothingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kıyafeti Sil'),
        content: Text('${item.name} kıyafetini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && item.id != null) {
      await _databaseHelper.deleteClothingItem(item.id!);
      // Kategori filtresini koruyarak yenile
      await _refreshItemsWithCategoryFilter();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final color = isError ? Colors.red : const Color(0xFF2a6a73); // Kamera butonu rengi ile aynı
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/* class ClothingCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onTap; // Yeni parametre eklendi
  final VoidCallback? onFavoriteToggle; // Yeni parametre eklendi

  const ClothingCard({
    Key? key,
    required this.item,
    this.onDelete,
    this.onTap, // Yeni parametre
    this.onFavoriteToggle, // Yeni parametre
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Tıklama işlevini ekle
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resim kısmı
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[100], // Şeffaf arkaplan için
                  child: Image.file(
                    File(item.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Bilgi kısmı
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} */
