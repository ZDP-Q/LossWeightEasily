class UserProfile {
  final int? id;
  final String username;
  final String? nickname;
  final String? email;
  final String? fullName;
  final int? age;
  final String? gender; 
  final double? heightCm;
  final double? initialWeightKg;
  final double? targetWeightKg;
  final String? activityLevel;
  final double? bmr;
  final double? tdee;
  final double? dailyCalorieGoal;
  final DateTime? createdAt;

  UserProfile({
    this.id,
    required this.username,
    this.nickname,
    this.email,
    this.fullName,
    this.age,
    this.gender,
    this.heightCm,
    this.initialWeightKg,
    this.targetWeightKg,
    this.activityLevel = 'sedentary',
    this.bmr,
    this.tdee,
    this.dailyCalorieGoal,
    this.createdAt,
  });

  // 显示名称逻辑：优先显示昵称，没有则显示账号名
  String get displayName => (nickname != null && nickname!.isNotEmpty) ? nickname! : username;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'] ?? '',
      nickname: json['nickname'],
      email: json['email'],
      fullName: json['full_name'],
      age: json['age'],
      gender: json['gender'],
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      initialWeightKg: (json['initial_weight_kg'] as num?)?.toDouble(),
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      activityLevel: json['activity_level'] as String? ?? 'sedentary',
      bmr: (json['bmr'] as num?)?.toDouble(),
      tdee: (json['tdee'] as num?)?.toDouble(),
      dailyCalorieGoal: (json['daily_calorie_goal'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'nickname': nickname,
      'email': email,
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'initial_weight_kg': initialWeightKg,
      'target_weight_kg': targetWeightKg,
      'activity_level': activityLevel,
      'bmr': bmr,
      'tdee': tdee,
      'daily_calorie_goal': dailyCalorieGoal,
    };
  }

  UserProfile copyWith({
    int? id,
    String? username,
    String? nickname,
    String? email,
    String? fullName,
    int? age,
    String? gender,
    double? heightCm,
    double? initialWeightKg,
    double? targetWeightKg,
    String? activityLevel,
    double? bmr,
    double? tdee,
    double? dailyCalorieGoal,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      initialWeightKg: initialWeightKg ?? this.initialWeightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
