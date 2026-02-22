import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/navigation_provider.dart';
import '../providers/user_provider.dart';
import '../providers/weight_provider.dart';
import '../providers/food_log_provider.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/bmr_calculator.dart';
import '../widgets/glass_card.dart';
import 'recognition_result_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isRecognizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationProvider>().onHomeRefreshed = _refreshData;
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await Future.wait([
      context.read<UserProvider>().loadUser(),
      context.read<WeightProvider>().loadHistory(),
      context.read<FoodLogProvider>().loadTodayLogs(),
    ]);
  }

  Future<void> _takePhotoAndRecognize() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (photo == null) return;

    setState(() => _isRecognizing = true);
    _showRecognitionLoading(); // 显示增强版加载弹窗

    try {
      final imageBytes = await photo.readAsBytes();
      final result = await ApiService().recognizeFood(imageBytes);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载弹窗

      final foodName = result['final_food_name'] ?? '未知食物';
      final calories = (result['final_estimated_calories'] as num).toDouble();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecognitionResultScreen(
            imagePath: photo.path,
            foodName: foodName,
            calories: calories,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 确保关闭弹窗
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  void _showRecognitionLoading() {
    final List<String> tips = [
      '正在把照片发给小松...',
      '正在仔细观察食物细节...',
      '正在翻阅卡路里百科全书...',
      '正在努力估算份量...',
      '结果马上就要出来啦...',
    ];
    int currentTipIndex = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 设置定时器切换文案
            Timer(const Duration(seconds: 4), () {
              if (context.mounted) {
                setDialogState(() {
                  currentTipIndex = (currentTipIndex + 1) % tips.length;
                });
              }
            });

            return PopScope(
              canPop: false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        tips[currentTipIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AI 识别可能需要约 15-20 秒',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.textTheme.bodySmall?.color ?? AppColors.textSecondary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, secondaryColor),
              const SizedBox(height: 16),
              _buildSummaryCards(context, secondaryColor),
              const SizedBox(height: 16),
              RepaintBoundary(child: _buildWeightChart(context)),
              const SizedBox(height: 16),
              Expanded(child: RepaintBoundary(child: _buildFoodLogTable(context, secondaryColor))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color secondaryColor) {
    return Selector<UserProvider, String>(
      selector: (_, p) => p.displayName,
      builder: (context, displayName, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你好, $displayName',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text('今天也是元气满满的一天 🌟', 
                    style: TextStyle(fontSize: 13, color: secondaryColor)),
              ],
            ),
            _buildHeaderAction(
              icon: FontAwesomeIcons.plus,
              label: '记录体重',
              onTap: () => _showWeightInputDialog(context),
            ),
          ],
        ).animate().fadeIn().slideX();
      },
    );
  }

  Widget _buildHeaderAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.bold, 
                color: AppColors.primary
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, Color secondaryColor) {
    final weightProvider = context.watch<WeightProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentWeight = weightProvider.latestWeight ?? (userProvider.user?.initialWeightKg ?? 0);
    
    double targetGoal = 0;
    final user = userProvider.user;
    if (user != null && user.targetWeightKg != null && user.heightCm != null && user.age != null && user.gender != null) {
      final bmr = BmrCalculator.calculateBmr(
        weight: user.targetWeightKg!,
        height: user.heightCm!,
        age: user.age!,
        gender: user.gender!,
      );
      targetGoal = BmrCalculator.calculateTdee(bmr, user.activityLevel ?? 'sedentary');
    }

    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            '当前体重',
            currentWeight.toStringAsFixed(1),
            'kg',
            FontAwesomeIcons.weightScale,
            Colors.blue,
            secondaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            '目标摄入',
            targetGoal.toStringAsFixed(0),
            'kcal',
            FontAwesomeIcons.fire,
            Colors.orange,
            secondaryColor,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).scale();
  }

  Widget _buildInfoCard(String title, String value, String unit, IconData icon, Color color, Color secondaryColor) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 11, color: secondaryColor)),
            ],
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: secondaryColor)),
        ],
      ),
    );
  }

  Widget _buildWeightChart(BuildContext context) {
    final weightProvider = context.watch<WeightProvider>();
    final history = weightProvider.records.reversed.toList();
    final hintColor = Theme.of(context).hintColor;

    if (history.isEmpty) {
      return const GlassCard(
        height: 140,
        child: Center(child: Text('暂无体重数据')),
      );
    }

    DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
    final firstDate = normalizeDate(history.first.recordedAt);

    Map<int, List<double>> groupedByDay = {};
    for (var record in history) {
      final dayOffset = normalizeDate(record.recordedAt).difference(firstDate).inDays;
      groupedByDay.putIfAbsent(dayOffset, () => []).add(record.weightKg);
    }

    List<FlSpot> maxSpots = [];
    List<FlSpot> minSpots = [];
    var sortedDays = groupedByDay.keys.toList()..sort();
    for (var day in sortedDays) {
      var weights = groupedByDay[day]!;
      double maxW = weights.reduce((a, b) => a > b ? a : b);
      double minW = weights.reduce((a, b) => a < b ? a : b);
      maxSpots.add(FlSpot(day.toDouble(), maxW));
      minSpots.add(FlSpot(day.toDouble(), minW));
    }

    double rawMinY = history.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    double rawMaxY = history.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    
    double minY = (rawMinY - 1).floorToDouble();
    double maxY = (rawMaxY + 2).ceilToDouble();
    if (minY < 0) minY = 0;
    
    double yInterval = ((maxY - minY) / 5).clamp(1.0, 20.0);

    double minX = sortedDays.first.toDouble();
    double maxX = sortedDays.last.toDouble();
    
    if (minX == maxX) {
      minX -= 0.5;
      maxX += 0.5;
    } else {
      double delta = (maxX - minX) * 0.05;
      if (delta < 0.2) delta = 0.2;
      minX -= delta;
      maxX += delta;
    }

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('体重曲线', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _buildLegendItem('最高', AppColors.accent),
                  const SizedBox(width: 8),
                  _buildLegendItem('最低', AppColors.primary),
                  const SizedBox(width: 8),
                  Text('单位: kg', style: TextStyle(fontSize: 9, color: hintColor.withValues(alpha: 0.5))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: ((maxX - minX) / 4).clamp(1.0, 30.0),
                      getTitlesWidget: (value, meta) {
                        final date = firstDate.add(Duration(days: value.toInt()));
                        if (value < sortedDays.first || value > sortedDays.last) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(date),
                            style: TextStyle(fontSize: 8, color: hintColor),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value < minY + (yInterval * 0.2)) {
                          return const SizedBox();
                        }
                        if (value > maxY - (yInterval * 0.2)) {
                          return const SizedBox();
                        }
                        return Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(fontSize: 8, color: hintColor),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: maxSpots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.accent,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 2.5,
                        color: Colors.white,
                        strokeWidth: 1.5,
                        strokeColor: AppColors.accent,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: minSpots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.primary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 2.5,
                        color: Colors.white,
                        strokeWidth: 1.5,
                        strokeColor: AppColors.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Theme.of(context).hintColor),
        ),
      ],
    );
  }

  Widget _buildFoodLogTable(BuildContext context, Color secondaryColor) {
    return Consumer<FoodLogProvider>(
      builder: (context, foodLogProvider, child) {
        final logs = foodLogProvider.todayLogs;
        final total = foodLogProvider.totalCalories;

        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('今日摄入', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  Row(
                    children: [
                      _buildActionIcon(
                        icon: _isRecognizing ? FontAwesomeIcons.spinner : FontAwesomeIcons.camera,
                        onTap: _isRecognizing ? null : _takePhotoAndRecognize,
                        isLoading: _isRecognizing,
                      ),
                      const SizedBox(width: 8),
                      _buildActionIcon(
                        icon: FontAwesomeIcons.plus,
                        onTap: () => _showFoodInputDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('总计摄入', style: TextStyle(fontSize: 12, color: secondaryColor)),
                  Text('${total.toStringAsFixed(0)} kcal', 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: logs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text('今日暂无饮食记录', style: TextStyle(color: secondaryColor)),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: logs.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border, indent: 0),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(FontAwesomeIcons.utensils, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${log.foodName} (${_getMealName(log.mealType)})', 
                                      style: const TextStyle(fontSize: 14)
                                    ),
                                  ),
                                  Text('${log.calories.toStringAsFixed(0)} kcal', 
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0);
      },
    );
  }

  Widget _buildActionIcon({required IconData icon, required VoidCallback? onTap, bool isLoading = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: isLoading 
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 14, color: AppColors.primary),
        ),
      ),
    );
  }

  void _showFoodInputDialog(BuildContext context) {
    final nameController = TextEditingController();
    final calorieController = TextEditingController();
    String selectedMeal = 'breakfast';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('手动记录饮食'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '食物名称', hintText: '例如: 苹果'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: calorieController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '热量 (kcal)', hintText: '例如: 52'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMeal,
                    decoration: const InputDecoration(labelText: '餐次'),
                    items: const [
                      DropdownMenuItem(value: 'breakfast', child: Text('早餐')),
                      DropdownMenuItem(value: 'lunch', child: Text('午餐')),
                      DropdownMenuItem(value: 'dinner', child: Text('晚餐')),
                      DropdownMenuItem(value: 'snack', child: Text('加餐')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedMeal = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty && calorieController.text.isNotEmpty) {
                      final cal = double.tryParse(calorieController.text);
                      if (cal != null) {
                        Navigator.pop(context);
                        try {
                          await context.read<FoodLogProvider>().addLog(
                            nameController.text, 
                            cal, 
                            mealType: selectedMeal
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: $e')));
                          }
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getMealName(String mealType) {
    switch (mealType) {
      case 'breakfast': return '早餐';
      case 'lunch': return '午餐';
      case 'dinner': return '晚餐';
      case 'snack': return '加餐';
      default: return '未知';
    }
  }

  void _showWeightInputDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('记录今日体重'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '当前体重 (kg)', 
              hintText: '例如: 65.5',
              suffixText: 'kg'
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('取消', style: TextStyle(color: AppColors.textSecondary))
            ),
            ElevatedButton(
              onPressed: () async {
                final weightStr = controller.text.trim();
                if (weightStr.isNotEmpty) {
                  final weight = double.tryParse(weightStr);
                  if (weight != null) {
                    Navigator.pop(context);
                    try {
                      await context.read<WeightProvider>().addRecord(weight);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('体重记录成功！'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('记录失败: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('保存记录'),
            ),
          ],
        );
      },
    );
  }
}
