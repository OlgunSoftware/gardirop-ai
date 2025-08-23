// models/outfit.dart
class Outfit {
  final int? id;
  final String name;
  final String description;
  final Map<String, int> clothingItems; // kategori -> clothing_item_id
  final DateTime createdAt;

  Outfit({
    this.id,
    required this.name,
    required this.description,
    required this.clothingItems,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'clothing_items': clothingItems.entries.map((e) => '${e.key}:${e.value}').join(','),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Outfit.fromMap(Map<String, dynamic> map) {
    Map<String, int> clothingItems = {};
    if (map['clothing_items'] != null && map['clothing_items'].isNotEmpty) {
      final pairs = map['clothing_items'].split(',');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          clothingItems[parts[0]] = int.parse(parts[1]);
        }
      }
    }

    return Outfit(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      clothingItems: clothingItems,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}