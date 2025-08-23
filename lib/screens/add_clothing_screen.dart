import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';


import '../models/clothing_item.dart';
import '../services/database_helper.dart';
import '../services/remove_bg_service.dart';

class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({super.key});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();

  ClothingCategory? _selectedCategory;
  File? _selectedImage; // Kullanıcının seçtiği veya çektiği fotoğraf
  bool _isLoading = false;
  bool _isOptimizing = false; // _isRemovingBg yerine

  // _AddClothingScreenState sınıfına yeni değişken ekle
  List<String> _customCategories = [];

  // initState'e kategori yükleme ekle
  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        
        // Otomatik optimize et
        await _optimizeImage();
      }
    } catch (e) {
      _showSnackBar('Fotoğraf seçilirken hata oluştu: $e', isError: true);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        
        // Otomatik optimize et
        await _optimizeImage();
      }
    } catch (e) {
      _showSnackBar('Fotoğraf seçilirken hata oluştu: $e', isError: true);
    }
  }

  Future<String> _saveImage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/clothing_images');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final savedImage = await imageFile.copy('${imagesDir.path}/$fileName');
    
    return savedImage.path;
  }

  // Özel kategorileri yükle
  Future<void> _loadCustomCategories() async {
    try {
      final categories = await _databaseHelper.getCategories();
      setState(() {
        _customCategories = categories;
      });
    } catch (e) {
      print('Kategoriler yüklenemedi: $e');
    }
  }

  // Yeni kategori ekleme dialog'u
  Future<void> _showAddCategoryDialog() async {
    String newCategoryName = '';
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yeni Kategori Ekle'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Kategori adını girin (örn: Spor Ayakkabı)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => newCategoryName = value,
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
                if (newCategoryName.trim().isNotEmpty) {
                  Navigator.of(context).pop(newCategoryName.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2a6a73),
              ),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Yeni kategoriyi listeye ekle
      setState(() {
        if (!_customCategories.contains(result)) {
          _customCategories.add(result);
          // Yeni eklenen kategoriyi seç
          _selectedCategory = null; // Dropdown'u resetle
          _selectedCategoryString = result; // String olarak seç
        }
      });
      
      _showSnackBar('Kategori "$result" eklendi', isError: false);
    }
  }

  // String kategorisi için yeni değişken ekle
  String? _selectedCategoryString;

  // Kategori dropdown'ını değiştir
  Widget _buildCategoryDropdown() {
    // Varsayılan kategoriler + özel kategoriler
    final List<String> allCategories = [
      ...ClothingCategory.values.map((e) => e.displayName),
      ..._customCategories,
      '+ Kategori Ekle' // Özel seçenek
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DropdownButtonFormField<String>(
          value: _selectedCategoryString,
          decoration: InputDecoration(
            labelText: 'Kategori',
            prefixIcon: const Icon(
              Icons.category_outlined,
              color: Color(0xFF2a6a73),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            labelStyle: TextStyle(color: Colors.grey[700]),
          ),
          items: allCategories.map((category) {
            return DropdownMenuItem(
              value: category == '+ Kategori Ekle' ? null : category,
              child: Row(
                children: [
                  if (category == '+ Kategori Ekle') ...[
                    const Icon(
                      Icons.add,
                      color: Color(0xFF2a6a73),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    category,
                    style: TextStyle(
                      color: category == '+ Kategori Ekle' 
                          ? const Color(0xFF2a6a73)
                          : Colors.black87,
                      fontWeight: category == '+ Kategori Ekle'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (category) async {
            if (category == null) {
              // "Kategori Ekle" seçildi
              await _showAddCategoryDialog();
            } else {
              setState(() {
                _selectedCategoryString = category;
                _selectedCategory = null; // Eski enum'u temizle
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Kategori seçimi gerekli';
            }
            return null;
          },
        ),
      ),
    );
  }

  Future<void> _saveClothingItem() async {
    if (!_formKey.currentState!.validate() || 
        (_selectedCategory == null && _selectedCategoryString == null) || 
        _selectedImage == null) {
      _showSnackBar('Lütfen tüm alanları doldurun', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // _selectedImage artık optimize edilmiş fotoğraf (varsa)
      final imagePath = await _saveImage(_selectedImage!);
      
      // Kategori adını belirle
      final categoryName = _selectedCategoryString ?? _selectedCategory?.displayName ?? '';
      
      final clothingItem = ClothingItem(
        name: _nameController.text.trim(),
        category: categoryName,
        imagePath: imagePath, // Optimize edilmiş fotoğrafın path'i
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        // createdAt: DateTime.now(), // Artık burada yok
      );

      await _databaseHelper.insertClothingItem(clothingItem);
      
      if (mounted) {
        _showSnackBar('Kıyafet başarıyla eklendi! (Optimize edilmiş fotoğraf kullanıldı)', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Kıyafet kaydedilirken hata oluştu: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // _optimizeImage metodunu güncelleyelim
  Future<void> _optimizeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isOptimizing = true);

    try {
      final processedImage = await RemoveBgService.removeBackground(_selectedImage!);
      
      if (processedImage != null) {
        setState(() {
          _selectedImage = processedImage; // Bu optimize edilmiş fotoğraf artık varsayılan
        });
        
        _showSnackBar('Resim başarıyla optimize edildi - Bu fotoğraf kaydedilecek', isError: false);
      } else {
        // API hata verirse orijinal fotoğraf kalır
        _showSnackBar('Resim optimize edilemedi - Orijinal fotoğraf kullanılacak', isError: true);
      }
    } catch (e) {
      // Hata durumunda orijinal fotoğraf korunur
      _showSnackBar('Optimize hatası: $e - Orijinal fotoğraf kullanılacak', isError: true);
    } finally {
      setState(() => _isOptimizing = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2a6a73),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fotoğraf Seç',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Kamera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeri',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2a6a73).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF2a6a73),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF2a6a73),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Kıyafet Ekle',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Fotoğraf Seçimi - Optimize indicator ile
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: GestureDetector(
                onTap: _isOptimizing ? null : _showImageSourceDialog, // Optimize sırasında devre dışı
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2a6a73).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              Image.file(
                                _selectedImage!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              
                              // Optimize overlay
                              if (_isOptimizing)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2a6a73).withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2a6a73),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'Resim optimize ediliyor...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2a6a73).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo_outlined,
                                size: 40,
                                color: Color(0xFF2a6a73),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Fotoğraf Ekle',
                              style: TextStyle(
                                color: Color(0xFF2a6a73),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Seçilen fotoğraf otomatik optimize edilecek',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Optimize bilgi kartı
            if (_selectedImage != null && !_isOptimizing)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resim başarıyla optimize edildi',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Bu optimize edilmiş fotoğraf kaydedilecek',
                            style: TextStyle(
                              color: Colors.green[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Diğer form alanları aynı kalacak...
            // İsim - Modern Input
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Kıyafet Adı',
                    prefixIcon: const Icon(
                      Icons.label_outline,
                      color: Color(0xFF2a6a73),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: TextStyle(color: Colors.grey[700]),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kıyafet adı gerekli';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Kategori - Modern Dropdown
            _buildCategoryDropdown(),
            const SizedBox(height: 16),

            // Açıklama - Modern TextArea
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Açıklama (Opsiyonel)',
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF2a6a73),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: TextStyle(color: Colors.grey[700]),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Kaydet Butonu - Optimize sırasında devre dışı
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: (_isLoading || _isOptimizing) ? null : _saveClothingItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2a6a73),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: (_isLoading || _isOptimizing)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Kıyafeti Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
