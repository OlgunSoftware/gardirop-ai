class CustomCategory {
  final int? id;
  final String name;
  final String icon; // Icon property'si eklendi
  final String? description;
  final DateTime createdAt;

  CustomCategory({
    this.id,
    required this.name,
    required this.icon, // Icon zorunlu alan
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon, // Icon map'e eklendi
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CustomCategory.fromMap(Map<String, dynamic> map) {
    return CustomCategory(
      id: map['id'],
      name: map['name'],
      icon: map['icon'] ?? '👕', // Default icon
      description: map['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

// Varsayılan kategoriler
class DefaultCategories {
  static final List<CustomCategory> categories = [
    CustomCategory(
      name: 'Gömlek',
      icon: 'business_center',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'T-shirt',
      icon: 'local_mall',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Pantolon',
      icon: 'straighten',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Jean',
      icon: 'fitness_center',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Ceket',
      icon: 'ac_unit',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Kazak',
      icon: 'child_friendly',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Sweatshirt',
      icon: 'sports',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Ayakkabı',
      icon: 'directions_walk',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Eşofman',
      icon: 'directions_run',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Şort',
      icon: 'beach_access',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Elbise',
      icon: 'person',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Etek',
      icon: 'accessibility',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Blazer',
      icon: 'work',
      createdAt: DateTime.now(),
    ),
    CustomCategory(
      name: 'Mont',
      icon: 'severe_cold',
      createdAt: DateTime.now(),
    ),
  ];
}
