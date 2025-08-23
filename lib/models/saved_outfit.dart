class SavedOutfit {
  final int? id;
  final String name;
  final int? topItemId;
  final int? bottomItemId;
  final int? shoesItemId;
  final int? accessoryItemId;

  SavedOutfit({
    this.id,
    required this.name,
    this.topItemId,
    this.bottomItemId,
    this.shoesItemId,
    this.accessoryItemId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'top_item_id': topItemId,
      'bottom_item_id': bottomItemId,
      'shoes_item_id': shoesItemId,
      'accessory_item_id': accessoryItemId,
    };
  }

  factory SavedOutfit.fromMap(Map<String, dynamic> map) {
    return SavedOutfit(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      topItemId: map['top_item_id']?.toInt(),
      bottomItemId: map['bottom_item_id']?.toInt(),
      shoesItemId: map['shoes_item_id']?.toInt(),
      accessoryItemId: map['accessory_item_id']?.toInt(),
    );
  }
}