class ClothingItem {
  final int? id;
  final String name;
  final String category;
  final String imagePath;
  final String? description;
  final bool isFavorite;
  
  // AI ETİKETLERİ
  final bool aiAnalyzed;
  final String? aiColors;
  final String? aiPatterns;
  final String? aiStyle;
  final String? aiSeason;
  final String? aiFormality;
  final String? aiMaterial;
  final int? aiConfidence;
  final DateTime? aiAnalysisDate;

  ClothingItem({
    this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    this.description,
    this.isFavorite = false,
    this.aiAnalyzed = false,
    this.aiColors,
    this.aiPatterns,
    this.aiStyle,
    this.aiSeason,
    this.aiFormality,
    this.aiMaterial,
    this.aiConfidence,
    this.aiAnalysisDate,
  });

  // AI etiketli kıyafet açıklaması
  String get aiDescription {
    if (!aiAnalyzed) return '$name ($category)';
    
    return '''$name ($category)
    • Renkler: ${aiColors ?? 'Bilinmiyor'}
    • Desen: ${aiPatterns ?? 'Düz'}
    • Stil: ${aiStyle ?? 'Casual'}
    • Mevsim: ${aiSeason ?? 'Her mevsim'}
    • Formalite: ${aiFormality ?? 'Orta'}
    • Materyal: ${aiMaterial ?? 'Bilinmiyor'}''';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'imagePath': imagePath,
      'description': description,
      'is_favorite': isFavorite ? 1 : 0,
      'ai_analyzed': aiAnalyzed ? 1 : 0,
      'ai_colors': aiColors,
      'ai_patterns': aiPatterns,
      'ai_style': aiStyle,
      'ai_season': aiSeason,
      'ai_formality': aiFormality,
      'ai_material': aiMaterial,
      'ai_confidence': aiConfidence,
      'ai_analysis_date': aiAnalysisDate?.toIso8601String(),
    };
  }

  factory ClothingItem.fromMap(Map<String, dynamic> map) {
    return ClothingItem(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      imagePath: map['imagePath'] ?? '',
      description: map['description'],
      isFavorite: (map['is_favorite'] ?? 0) == 1,
      aiAnalyzed: (map['ai_analyzed'] ?? 0) == 1,
      aiColors: map['ai_colors'],
      aiPatterns: map['ai_patterns'],
      aiStyle: map['ai_style'],
      aiSeason: map['ai_season'],
      aiFormality: map['ai_formality'],
      aiMaterial: map['ai_material'],
      aiConfidence: map['ai_confidence']?.toInt(),
      aiAnalysisDate: map['ai_analysis_date'] != null ? DateTime.parse(map['ai_analysis_date']) : null,
    );
  }

  ClothingItem copyWith({
    int? id,
    String? name,
    String? category,
    String? imagePath,
    String? description,
    bool? isFavorite,
    bool? aiAnalyzed,
    String? aiColors,
    String? aiPatterns,
    String? aiStyle,
    String? aiSeason,
    String? aiFormality,
    String? aiMaterial,
    int? aiConfidence,
    DateTime? aiAnalysisDate,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      isFavorite: isFavorite ?? this.isFavorite,
      aiAnalyzed: aiAnalyzed ?? this.aiAnalyzed,
      aiColors: aiColors ?? this.aiColors,
      aiPatterns: aiPatterns ?? this.aiPatterns,
      aiStyle: aiStyle ?? this.aiStyle,
      aiSeason: aiSeason ?? this.aiSeason,
      aiFormality: aiFormality ?? this.aiFormality,
      aiMaterial: aiMaterial ?? this.aiMaterial,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      aiAnalysisDate: aiAnalysisDate ?? this.aiAnalysisDate,
    );
  }
}

enum ClothingCategory {
  gomlek('Gömlek'),
  tshirt('T-shirt'),
  pantolon('Pantolon'),
  jean('Jean'),
  ceket('Ceket'),
  kazak('Kazak'),
  sweatshirt('Sweatshirt'),
  ayakkabi('Ayakkabı'),
  esofman('Eşofman'),
  sort('Şort'),
  elbise('Elbise'),
  etek('Etek'),
  blazer('Blazer'),
  mont('Mont');

  final String displayName;
  const ClothingCategory(this.displayName);
}
