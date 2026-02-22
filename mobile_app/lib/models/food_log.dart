class FoodLog {
  final int id;
  final String foodName;
  final double calories;
  final String mealType;
  final DateTime timestamp;

  FoodLog({
    required this.id,
    required this.foodName,
    required this.calories,
    required this.mealType,
    required this.timestamp,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'],
      foodName: json['food_name'],
      calories: (json['calories'] as num).toDouble(),
      mealType: json['meal_type'] ?? 'unknown',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_name': foodName,
      'calories': calories,
      'meal_type': mealType,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
