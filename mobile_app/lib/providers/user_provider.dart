import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _api;

  UserProfile? _user;
  bool _isLoading = false;
  String? _error;

  UserProvider(this._api);

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get hasUser => _user != null;
  String? get error => _error;

  void reset() {
    _user = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // 这里的 displayName 将会自动调用 UserProfile 内部的逻辑（优先昵称，后账号名）
  String get displayName => _user?.displayName ?? '新用户';
  
  double? get bmr => _user?.bmr;
  double? get tdee => _user?.tdee;
  double? get dailyCalorieGoal => _user?.dailyCalorieGoal;
  double? get targetWeight => _user?.targetWeightKg;
  double? get initialWeight => _user?.initialWeightKg;

  Future<void> loadUser({bool forceRefresh = false}) async {
    // 如果已经有数据且不是强制刷新，直接返回
    if (_user != null && !forceRefresh) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.getMe();
    } catch (e) {
      _error = '加载用户信息失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? nickname,
    int? age,
    String? gender,
    double? height,
    double? initialWeight,
    double? targetWeight,
    String? activityLevel,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.updateProfile(
        nickname: nickname,
        age: age,
        gender: gender,
        height: height,
        initialWeight: initialWeight,
        targetWeight: targetWeight,
        activityLevel: activityLevel,
      );
    } catch (e) {
      _error = '更新个人资料失败: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
