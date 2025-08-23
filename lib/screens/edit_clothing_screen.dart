import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/clothing_item.dart';
import '../services/database_helper.dart';
import '../services/remove_bg_service.dart';

class EditClothingScreen extends StatefulWidget {
  final ClothingItem clothingItem;
  
  const EditClothingScreen({
    super.key,
    required this.clothingItem,
  });

  @override
  State<EditClothingScreen> createState() => _EditClothingScreenState();
}

class _EditClothingScreenState extends State<EditClothingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();

  ClothingCategory? _selectedCategory;
  String? _selectedCategoryString; // String kategoriler için
  File? _selectedImage;
  bool _isLoading = false;
  bool _isProcessingImage = false;
  bool _isBackgroundRemoved = false;
  bool _imageChanged = false;
  
  // Kategori listesi
  List<String> _customCategories = [];

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadCustomCategories(); // Kategorileri yükle
    _validateRemoveBgApiKey();
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

  /// Mevcut ürün bilgilerini form alanlarına yükle
  void _initializeFields() {
    _nameController.text = widget.clothingItem.name;
    _descriptionController.text = widget.clothingItem.description ?? '';
    
    final currentCategory = widget.clothingItem.category;
    
    // Önce enum kategorilerde ara
    try {
      _selectedCategory = ClothingCategory.values.firstWhere(
        (category) => category.displayName == currentCategory,
      );
      _selectedCategoryString = null; // Enum bulundu, string'i temizle
    } catch (e) {
      // Enum'da yoksa string kategori olarak ayarla
      _selectedCategory = null;
      _selectedCategoryString = currentCategory;
    }
    
    // Mevcut resim dosyasını yükle
    if (widget.clothingItem.imagePath.isNotEmpty) {
      _selectedImage = File(widget.clothingItem.imagePath);
      _isBackgroundRemoved = true;
    }
  }

  /// Remove.bg API anahtarını kontrol et
  Future<void> _validateRemoveBgApiKey() async {
    final isValid = await RemoveBgService.validateApiKey();
    if (!isValid) {
      print('⚠️ Remove.bg API anahtarı geçersiz veya tanımlanmamış');
    }
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
          _isBackgroundRemoved = false;
          _imageChanged = true; // Resim değişti
        });
        
        // Otomatik arkaplan kaldırma
        await _removeBackgroundWithApi();
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
          _isBackgroundRemoved = false;
          _imageChanged = true; // Resim değişti
        });
        
        // Otomatik arkaplan kaldırma
        await _removeBackgroundWithApi();
      }
    } catch (e) {
      _showSnackBar('Fotoğraf seçilirken hata oluştu: $e', isError: true);
    }
  }

  /// Remove.bg API ile arkaplan kaldırma
  Future<void> _removeBackgroundWithApi() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessingImage = true;
    });

    try {
      _showSnackBar('🔄 Arkaplan kaldırılıyor...', isError: false);
      
      // Remove.bg API'yi kullan
      final processedImage = await RemoveBgService.removeBackground(_selectedImage!);

      if (processedImage != null) {
        setState(() {
          _selectedImage = processedImage; // Arkaplanı kaldırılmış resmi göster
          _isProcessingImage = false;
          _isBackgroundRemoved = true;
        });
        
        _showSnackBar('✅ Arkaplan başarıyla kaldırıldı!', isError: false);
      } else {
        throw Exception('Arkaplan kaldırma başarısız');
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
      });
      _showSnackBar('❌ Arkaplan kaldırma hatası: $e', isError: true);
    }
  }

  /// Manuel arkaplan kaldırma butonu
  Future<void> _manualRemoveBackground() async {
    if (_selectedImage == null) return;
    await _removeBackgroundWithApi();
  }

  Future<String> _saveImage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/clothing_images');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // PNG olarak kaydet (şeffaflık korunur)
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final savedImage = await imageFile.copy('${imagesDir.path}/$fileName');
    
    return savedImage.path;
  }

  Future<void> _updateClothingItem() async {
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
      String imagePath = widget.clothingItem.imagePath;
      
      // Eğer resim değiştiyse, yeni resmi kaydet
      if (_imageChanged && _selectedImage != null) {
        imagePath = await _saveImage(_selectedImage!);
        
        // Eski resim dosyasını sil
        if (widget.clothingItem.imagePath.isNotEmpty) {
          try {
            final oldFile = File(widget.clothingItem.imagePath);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          } catch (e) {
            print('Eski resim silinemedi: $e');
          }
        }
      }
      
      // Kategori adını belirle
      final categoryName = _selectedCategoryString ?? _selectedCategory?.displayName ?? '';
      
      final updatedClothingItem = ClothingItem(
        id: widget.clothingItem.id,
        name: _nameController.text.trim(),
        category: categoryName, // String olarak kategori
        imagePath: imagePath,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        // createdAt kaldırıldı
      );

      await _databaseHelper.updateClothingItem(updatedClothingItem);
      
      if (mounted) {
        _showSnackBar('Kıyafet başarıyla güncellendi!', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Kıyafet güncellenirken hata oluştu: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteClothingItem() async {
    // Silme onayı iste
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text('${widget.clothingItem.name} ürünü kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _databaseHelper.deleteClothingItem(widget.clothingItem.id!);
        
        // Resim dosyasını da sil
        if (widget.clothingItem.imagePath.isNotEmpty) {
          try {
            final imageFile = File(widget.clothingItem.imagePath);
            if (await imageFile.exists()) {
              await imageFile.delete();
            }
          } catch (e) {
            print('Resim dosyası silinemedi: $e');
          }
        }
        
        if (mounted) {
          _showSnackBar('Kıyafet başarıyla silindi!', isError: false);
          Navigator.pop(context, true); // Silindiğini belirt
        }
      } catch (e) {
        _showSnackBar('Kıyafet silinirken hata oluştu: $e', isError: true);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
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
                'Fotoğraf Değiştir',
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
              child: const Text('Ekle', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Enum kategorilerde aynı isim var mı kontrol et
      final enumCategories = ClothingCategory.values.map((e) => e.displayName).toList();
      
      if (enumCategories.contains(result)) {
        _showSnackBar('Bu kategori zaten mevcut', isError: true);
        return;
      }
      
      // Özel kategorilerde aynı isim var mı kontrol et
      if (_customCategories.contains(result)) {
        _showSnackBar('Bu kategori zaten mevcut', isError: true);
        return;
      }
      
      // Yeni kategoriyi listeye ekle
      setState(() {
        _customCategories.add(result);
        // Yeni eklenen kategoriyi seç
        _selectedCategory = null;
        _selectedCategoryString = result;
      });
      
      _showSnackBar('Kategori "$result" eklendi', isError: false);
    }
  }

  // Kategori dropdown'ı
  Widget _buildCategoryDropdown() {
    // Varsayılan kategoriler + özel kategoriler
    final List<String> enumCategories = ClothingCategory.values.map((e) => e.displayName).toList();
    final List<String> allCategories = [
      ...enumCategories,
      ..._customCategories.where((custom) => !enumCategories.contains(custom)), // Duplicate'leri önle
    ];

    // Mevcut seçili kategoriyi belirle
    String? currentSelection;
    if (_selectedCategoryString != null && allCategories.contains(_selectedCategoryString)) {
      currentSelection = _selectedCategoryString;
    } else if (_selectedCategory != null) {
      currentSelection = _selectedCategory!.displayName;
    }

    // Eğer seçili kategori listede yoksa null yap
    if (currentSelection != null && !allCategories.contains(currentSelection)) {
      currentSelection = null;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DropdownButtonFormField<String>(
          value: currentSelection,
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
          items: [
            // Mevcut kategoriler
            ...allCategories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
            
            // Kategori ekleme seçeneği - değeri null
            const DropdownMenuItem<String>(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.add,
                    color: Color(0xFF2a6a73),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '+ Kategori Ekle',
                    style: TextStyle(
                      color: Color(0xFF2a6a73),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            if ((_selectedCategoryString == null || _selectedCategoryString!.isEmpty) && 
                _selectedCategory == null) {
              return 'Kategori seçimi gerekli';
            }
            return null;
          },
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
          'Kıyafet Düzenle',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteClothingItem,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Fotoğraf Düzenleme - Remove.bg entegrasyonu ile
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: GestureDetector(
                onTap: _isProcessingImage ? null : _showImageSourceDialog,
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2a6a73).withOpacity(0.2),
                      width: 2,
                    ),
                    // Şeffaf arkaplan için basit gri
                    color: _isBackgroundRemoved ? Colors.grey[100] : null,
                  ),
                  child: _isProcessingImage
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF2a6a73),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'işleniyor...',
                                style: TextStyle(
                                  color: Color(0xFF2a6a73),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _selectedImage != null
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
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  // Arkaplan kaldırıldı badge'i
                                  if (_isBackgroundRemoved)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2a6a73),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _imageChanged ? 'Yeni Resim' : 'Mevcut Resim',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Manuel arkaplan kaldırma butonu
                                  if (_selectedImage != null && !_isBackgroundRemoved)
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: ElevatedButton.icon(
                                        onPressed: _manualRemoveBackground,
                                        icon: const Icon(Icons.auto_fix_high, size: 16),
                                        label: const Text('Arkaplan Kaldır'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2a6a73),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          textStyle: const TextStyle(fontSize: 12),
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
                                  'Fotoğraf Değiştir',
                                  style: TextStyle(
                                    color: Color(0xFF2a6a73),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),

            const SizedBox(height: 24),

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

            // Kategori dropdown'ını yeni widget ile değiştir
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

            // Güncelle Butonu - Modern Design
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateClothingItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2a6a73),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Değişiklikleri Kaydet',
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