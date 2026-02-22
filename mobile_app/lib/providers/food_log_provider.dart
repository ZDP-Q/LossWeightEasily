import 'package:flutter/foundation.dart';
import '../models/food_log.dart';
import '../services/api_service.dart';

class FoodLogProvider extends ChangeNotifier {
  final ApiService _api;

  List<FoodLog> _todayLogs = [];
  bool _isLoading = false;
  String? _error;

  FoodLogProvider(this._api);

  List<FoodLog> get todayLogs => _todayLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void reset() {
    _todayLogs = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  double get totalCalories => _todayLogs.fold(0, (sum, item) => sum + item.calories);

  Future<void> loadTodayLogs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _todayLogs = await _api.getTodayFoodLogs();
    } catch (e) {
      _error = '加载记录失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLog(String foodName, double calories, {String? mealType}) async {
    try {
      final newLog = await _api.addFoodLog(foodName, calories, mealType: mealType);
      _todayLogs.add(newLog);
      notifyListeners();
    } catch (e) {
      _error = '添加记录失败: $e';
      rethrow;
    }
  }
}
