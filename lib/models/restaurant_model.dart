class RestaurantModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final String imageUrl;
  final double rating;
  final int deliveryTime; // en minutos
  final double deliveryCost;
  final double minimumOrder;
  final bool isOpen;
  final List<String> coverageZones;
  final Map<String, String>? schedule; // día: horario

  RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.rating = 0.0,
    required this.deliveryTime,
    required this.deliveryCost,
    required this.minimumOrder,
    this.isOpen = true,
    required this.coverageZones,
    this.schedule,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> map, String id) {
    return RestaurantModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      rating: map['rating']?.toDouble() ?? 0.0,
      deliveryTime: map['deliveryTime'] ?? 30,
      deliveryCost: map['deliveryCost']?.toDouble() ?? 0.0,
      minimumOrder: map['minimumOrder']?.toDouble() ?? 0.0,
      isOpen: map['isOpen'] ?? true,
      coverageZones: List<String>.from(map['coverageZones'] ?? []),
      schedule: map['schedule'] != null 
          ? Map<String, String>.from(map['schedule']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'rating': rating,
      'deliveryTime': deliveryTime,
      'deliveryCost': deliveryCost,
      'minimumOrder': minimumOrder,
      'isOpen': isOpen,
      'coverageZones': coverageZones,
      'schedule': schedule,
    };
  }
}
