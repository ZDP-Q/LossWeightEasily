import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food.dart';
import '../models/food_log.dart';
import '../models/user.dart';
import '../models/weight_record.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://xiaosong.fucku.top',
  );
  
  static const Duration _timeout = Duration(seconds: 30);
  static const String _tokenKey = 'auth_token';

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ---------------------------------------------------------------------------
  // Auth & User Management
  // ---------------------------------------------------------------------------

  Future<void> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        _token = data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _token!);
        return;
      }
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw ApiException(error['detail'] ?? '登录失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> register(String username, String password, {String? email}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username, 
              'password': password,
              'email': email,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) return;
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw ApiException(error['detail'] ?? '注册失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<UserProfile> getMe() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/user/me'), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return UserProfile.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      throw ApiException('获取用户信息失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserProfile> updateProfile({
    String? nickname,
    int? age,
    String? gender,
    double? height,
    double? initialWeight,
    double? targetWeight,
    String? activityLevel,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (nickname != null) body['nickname'] = nickname;
      if (age != null) body['age'] = age;
      if (gender != null) body['gender'] = gender;
      if (height != null) body['height_cm'] = height;
      if (initialWeight != null) body['initial_weight_kg'] = initialWeight;
      if (targetWeight != null) body['target_weight_kg'] = targetWeight;
      if (activityLevel != null) body['activity_level'] = activityLevel;
      
      final response = await http
          .put(
            Uri.parse('$baseUrl/user/profile'),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
          
      if (response.statusCode == 200) {
        return UserProfile.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw ApiException(error['detail'] ?? '更新个人资料失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // 其余代码保持不变...
  // ---------------------------------------------------------------------------
  
  Future<List<FoodSearchResult>> searchFood(String query) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/food/search?query=${Uri.encodeComponent(query)}'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((j) => FoodSearchResult.fromJson(j)).toList();
      }
      throw ApiException('搜索失败 (${response.statusCode})');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<FoodLog>> getTodayFoodLogs() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/food-logs/today'), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((j) => FoodLog.fromJson(j)).toList();
      }
      throw ApiException('获取饮食记录失败 (${response.statusCode})');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<FoodLog> addFoodLog(String foodName, double calories, {String? mealType}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/food-logs'),
            headers: _headers,
            body: json.encode({
              'food_name': foodName,
              'calories': calories,
              'meal_type': mealType ?? 'unknown',
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return FoodLog.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      throw ApiException('记录饮食失败 (${response.statusCode})');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<WeightRecord>> getWeightHistory() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/weight'), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((j) => WeightRecord.fromJson(j)).toList();
      }
      throw ApiException('获取体重历史失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<WeightRecord> addWeight(double weight, String? notes) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/weight'),
            headers: _headers,
            body: json.encode({
              'weight_kg': weight,
              'notes': notes ?? '',
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return WeightRecord.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      throw ApiException('记录体重失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<WeightRecord> updateWeight(int id, double? weight, String? notes) async {
    try {
      final Map<String, dynamic> body = {};
      if (weight != null) body['weight_kg'] = weight;
      if (notes != null) body['notes'] = notes;
      
      final response = await http
          .put(
            Uri.parse('$baseUrl/weight/$id'),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return WeightRecord.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
      throw ApiException('更新失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteWeight(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/weight/$id'), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw ApiException('删除失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 20}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/chat/history?limit=$limit'), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(utf8.decode(response.bodyBytes)));
      }
      throw ApiException('获取聊天历史失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> chatWithCoach(String message) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: _headers,
            body: json.encode({'message': message}),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['content'];
      }
      throw ApiException('对话失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> generateMealPlan({
    List<String>? ingredients,
    String? preferences,
    String? restrictions,
    double? calorieGoal,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (ingredients != null) body['ingredients'] = ingredients;
      if (preferences != null) body['preferences'] = preferences;
      if (restrictions != null) body['restrictions'] = restrictions;
      if (calorieGoal != null) body['calorie_goal'] = calorieGoal;
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/meal-plan/generate'),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      throw ApiException('生成食谱失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Stream<ChatStreamEvent> chatWithCoachStream(String message) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/chat/stream'));
      request.headers.addAll(_headers);
      request.body = json.encode({'message': message});

      final response = await client.send(request);
      if (response.statusCode != 200) throw ApiException('连接失败');

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk.replaceAll('\r\n', '\n');
        while (buffer.contains('\n\n')) {
          final index = buffer.indexOf('\n\n');
          final eventString = buffer.substring(0, index);
          buffer = buffer.substring(index + 2);
          yield _parseEvent(eventString);
        }
      }
    } catch (e) {
      throw _handleError(e);
    } finally {
      client.close();
    }
  }

  ChatStreamEvent _parseEvent(String eventString) {
    final lines = eventString.split('\n');
    String eventType = 'text';
    final dataLines = <String>[];
    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    final data = dataLines.join('\n');
    if (eventType == 'done') return ChatStreamEvent(type: 'done');
    if (eventType == 'action_result') return ChatStreamEvent(type: 'action_result', data: json.decode(data));
    return ChatStreamEvent(type: eventType, text: data);
  }

  Future<Map<String, dynamic>> recognizeFood(List<int> imageBytes) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/food-analysis/recognize'));
      request.headers.addAll(_headers);
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'food.jpg'));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) return json.decode(utf8.decode(response.bodyBytes));
      throw ApiException('识别失败');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is ApiException) return e;
    if (e is TimeoutException) return const ApiException('请求超时');
    return ApiException('网络请求出错: $e');
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ChatStreamEvent {
  final String type;
  final String? text;
  final Map<String, dynamic>? data;
  ChatStreamEvent({required this.type, this.text, this.data});
}
