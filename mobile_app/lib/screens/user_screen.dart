import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/food_log_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/search_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../providers/weight_provider.dart';
import '../utils/app_colors.dart';
import '../utils/bmr_calculator.dart';
import '../widgets/glass_card.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final weightProvider = context.watch<WeightProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    
    final theme = Theme.of(context);
    final secondaryColor = theme.textTheme.bodySmall?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await userProvider.loadUser();
                await weightProvider.loadHistory();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProfileHeader(userProvider, secondaryColor),
                    const SizedBox(height: 24),
                    _buildInfoSection(context, userProvider, secondaryColor),
                    const SizedBox(height: 24),
                    _buildGoalSection(context, userProvider, weightProvider, secondaryColor),
                    const SizedBox(height: 24),
                    _buildSettingsSection(context, themeProvider, secondaryColor),
                    const SizedBox(height: 32),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(UserProvider provider, Color secondaryColor) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _showEditDialog(context, provider, null, 'nickname', '修改昵称'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.displayName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  ],
                ),
                Text(
                  '@${provider.user?.username ?? "unknown"}',
                  style: TextStyle(color: secondaryColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          provider.hasUser ? '已开启减重之旅' : '暂未设置资料',
          style: TextStyle(color: secondaryColor, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context, UserProvider provider, Color secondaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(' 基本信息',
            style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildListTile(
                context,
                '年龄',
                '${provider.user?.age ?? "--"} 岁',
                FontAwesomeIcons.calendar,
                () => _showEditDialog(context, provider, null, 'age', '修改年龄'),
                secondaryColor,
              ),
              _buildDivider(),
              _buildListTile(
                context,
                '身高',
                '${provider.user?.heightCm ?? "--"} cm',
                FontAwesomeIcons.arrowsUpDown,
                () => _showEditDialog(context, provider, null, 'height_cm', '修改身高'),
                secondaryColor,
              ),
              _buildDivider(),
              _buildListTile(
                context,
                '性别',
                provider.user?.gender == 'male' ? '男' : '女',
                FontAwesomeIcons.venusMars,
                () => _showGenderDialog(context, provider),
                secondaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalSection(BuildContext context, UserProvider provider, WeightProvider weightProvider, Color secondaryColor) {
    final user = provider.user;
    final currentWeight = weightProvider.latestWeight ?? user?.initialWeightKg;
    final targetWeight = user?.targetWeightKg;

    double? currentTdee;
    double? targetTdee;

    if (user != null && user.heightCm != null && user.age != null && user.gender != null) {
      if (currentWeight != null) {
        final bmr = BmrCalculator.calculateBmr(
          weight: currentWeight,
          height: user.heightCm!,
          age: user.age!,
          gender: user.gender!,
        );
        currentTdee = BmrCalculator.calculateTdee(bmr, user.activityLevel ?? 'sedentary');
      }

      if (targetWeight != null) {
        final bmr = BmrCalculator.calculateBmr(
          weight: targetWeight,
          height: user.heightCm!,
          age: user.age!,
          gender: user.gender!,
        );
        targetTdee = BmrCalculator.calculateTdee(bmr, user.activityLevel ?? 'sedentary');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(' 目标与代谢',
            style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildListTile(
                context,
                '当前体重',
                '${currentWeight?.toStringAsFixed(1) ?? "--"} kg',
                FontAwesomeIcons.weightScale,
                () => _showEditDialog(context, provider, weightProvider, 'current_weight', '记录当前体重'),
                secondaryColor,
              ),
              _buildDivider(),
              _buildListTile(
                context,
                '目标体重',
                '${targetWeight?.toStringAsFixed(1) ?? "--"} kg',
                FontAwesomeIcons.bullseye,
                () => _showEditDialog(context, provider, weightProvider, 'target_weight_kg', '修改目标体重'),
                secondaryColor,
              ),
              _buildDivider(),
              _buildListTile(
                context,
                '活动水平',
                _formatActivity(provider.user?.activityLevel),
                FontAwesomeIcons.personRunning,
                () => _showActivityDialog(context, provider),
                secondaryColor,
              ),
              _buildDivider(),
              _buildListTile(
                context,
                '当前 TDEE',
                '${currentTdee?.toStringAsFixed(0) ?? "--"} kcal',
                FontAwesomeIcons.bolt,
                null,
                secondaryColor,
              ),
              _buildDivider(),
              _buildListTile(
                context,
                '目标 TDEE',
                '${targetTdee?.toStringAsFixed(0) ?? "--"} kcal',
                FontAwesomeIcons.flagCheckered,
                null,
                secondaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, UserProvider provider, WeightProvider? weightProvider, String field, String title) {
    final controller = TextEditingController();
    String? currentVal;

    if (field == 'nickname') currentVal = provider.user?.nickname;
    if (field == 'age') currentVal = provider.user?.age?.toString();
    if (field == 'height_cm') currentVal = provider.user?.heightCm?.toString();
    if (field == 'target_weight_kg') currentVal = provider.user?.targetWeightKg?.toString();
    if (field == 'current_weight') {
      currentVal = weightProvider?.latestWeight?.toString() ?? provider.user?.initialWeightKg?.toString();
    }

    controller.text = currentVal ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: '请输入新的$title'),
          keyboardType: field == 'nickname' ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              try {
                if (field == 'current_weight') {
                  final val = double.tryParse(controller.text);
                  if (val != null && weightProvider != null) {
                    await weightProvider.addRecord(val);
                  }
                } else if (field == 'nickname') {
                  final val = controller.text.trim();
                  if (val.isNotEmpty) {
                    await provider.updateProfile(nickname: val);
                  }
                } else {
                   final val = double.tryParse(controller.text);
                   if (val != null) {
                      await provider.updateProfile(
                        age: field == 'age' ? val.toInt() : null,
                        height: field == 'height_cm' ? val : null,
                        targetWeight: field == 'target_weight_kg' ? val : null,
                      );
                   }
                }
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showGenderDialog(BuildContext context, UserProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择性别'),
        children: [
          SimpleDialogOption(
            onPressed: () => _updateSimpleField(context, provider, 'gender', 'male'),
            child: const Text('男'),
          ),
          SimpleDialogOption(
            onPressed: () => _updateSimpleField(context, provider, 'gender', 'female'),
            child: const Text('女'),
          ),
        ],
      ),
    );
  }

  void _showActivityDialog(BuildContext context, UserProvider provider) {
    final options = {
      'sedentary': '久坐 (几乎不运动)',
      'light': '轻度 (每周 1-3 次)',
      'moderate': '中度 (每周 3-5 次)',
      'active': '活跃 (每周 6-7 次)',
    };

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择活动水平'),
        children: options.entries
            .map((e) => SimpleDialogOption(
                  onPressed: () => _updateSimpleField(context, provider, 'activity_level', e.key),
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _updateSimpleField(BuildContext context, UserProvider provider, String field, String value) async {
    try {
      await provider.updateProfile(
        gender: field == 'gender' ? value : null,
        activityLevel: field == 'activity_level' ? value : null,
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  String _formatActivity(String? level) {
    switch (level) {
      case 'sedentary':
        return '久坐';
      case 'light':
        return '轻度活动';
      case 'moderate':
        return '中度活动';
      case 'active':
        return '活跃';
      default:
        return '未设置';
    }
  }

  Widget _buildSettingsSection(BuildContext context, ThemeProvider themeProvider, Color secondaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(' 系统设置',
            style: TextStyle(fontWeight: FontWeight.bold, color: secondaryColor)),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined, size: 18, color: AppColors.primary),
                title: const Text('外观显示', style: TextStyle(fontSize: 15)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(themeProvider.themeName, style: TextStyle(color: secondaryColor)),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.border),
                  ],
                ),
                onTap: () => _showThemeDialog(context, themeProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择外观'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(context, themeProvider, ThemeMode.system, '跟随系统', Icons.brightness_auto),
            _buildThemeOption(context, themeProvider, ThemeMode.light, '浅色模式', Icons.light_mode),
            _buildThemeOption(context, themeProvider, ThemeMode.dark, '深色模式', Icons.dark_mode),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
      BuildContext context, ThemeProvider provider, ThemeMode mode, String title, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: provider.themeMode == mode ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () {
        provider.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildListTile(BuildContext context, String title, String value, IconData icon, VoidCallback? onTap, Color secondaryColor) {
    return ListTile(
      leading: Icon(icon, size: 18, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: secondaryColor)),
          if (onTap != null) const Icon(Icons.chevron_right, size: 20, color: AppColors.border),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 50, color: AppColors.border.withValues(alpha: 0.1));
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => _handleLogout(context),
          child: const Text('退出登录', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 1. 先重置所有用户数据相关的 Provider
    context.read<UserProvider>().reset();
    context.read<WeightProvider>().reset();
    context.read<ChatProvider>().reset();
    context.read<FoodLogProvider>().reset();
    context.read<MealPlanProvider>().reset();
    context.read<SearchProvider>().reset();
    context.read<NavigationProvider>().reset();

    // 2. 执行真正的登出
    await context.read<AuthProvider>().logout();

    // 3. 兜底操作：显式回到根路由并清空栈
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}
