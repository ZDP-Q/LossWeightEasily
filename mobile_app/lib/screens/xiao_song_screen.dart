import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/streaming_markdown.dart';

class XiaoSongScreen extends StatefulWidget {
  const XiaoSongScreen({super.key});

  @override
  State<XiaoSongScreen> createState() => _XiaoSongScreenState();
}

class _XiaoSongScreenState extends State<XiaoSongScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  StreamSubscription? _eventSubscription;
  Timer? _streamScrollTimer;
  bool _scrollPostFrameQueued = false;
  late MarkdownStyleSheet _userMarkdownStyle;
  late MarkdownStyleSheet _assistantMarkdownStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      
      // Listen to events from provider
      _eventSubscription = chatProvider.events.listen(_handleChatEvent);

      if (chatProvider.messages.isEmpty) {
        chatProvider.loadHistory().then((_) {
          if (chatProvider.messages.isEmpty) {
            chatProvider.addSystemMessage('''你好！我是你的减重助手小松。你可以通过以下方式与我互动：

1. 🥗 **添加食材**：输入食材列表（如：鸡蛋, 西红柿），我为你开食谱。
2. 📸 **拍食物**：点击相机图标拍照，我帮你估算卡路里。
3. 💬 **问建议**：直接提问关于减重的问题。''');
          }
          _scrollToBottom(isInitial: true);
        });
      } else {
        _scrollToBottom(isInitial: true);
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _streamScrollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleChatEvent(ChatEvent event) {
    if (event.type == 'action_result') {
      _showActionResult(event.data);
    } else if (event.type == 'recognition_success') {
      _scrollToBottom();
    }
  }

  void _showActionResult(Map<String, dynamic>? result) {
    if (result == null || !mounted) return;
    
    final success = result['success'] == true;
    final message = result['message'] as String? ?? (success ? '操作成功' : '操作失败');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  void _scrollToBottom({bool isInitial = false, bool immediate = false}) {
    if (_scrollPostFrameQueued && !isInitial) return;
    _scrollPostFrameQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollPostFrameQueued = false;
      if (_scrollController.hasClients) {
        if (isInitial) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
        } else if (immediate) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _scheduleStreamingAutoScroll() {
    if (_streamScrollTimer?.isActive ?? false) return;

    _streamScrollTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        _scrollToBottom(immediate: true);
      }
    });
  }

  Future<void> _handleSend({String? textOverride}) async {
    final text = textOverride ?? _controller.text.trim();
    if (text.isEmpty) return;

    if (textOverride == null) {
      _controller.clear();
    }
    
    final chatProvider = context.read<ChatProvider>();
    
    // Use provider to send message
    await chatProvider.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (!mounted || image == null) return;

    final chatProvider = context.read<ChatProvider>();
    final bytes = await File(image.path).readAsBytes();
    
    _scrollToBottom();
    await chatProvider.recognizeFood(bytes);
    _scrollToBottom();
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 20),
              child: Text(
                '工具箱',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 20,
              crossAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildActionItem(
                  icon: FontAwesomeIcons.basketShopping,
                  label: '添加食材',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    context.read<ChatProvider>().toggleIngredientMode();
                  },
                ),
                _buildActionItem(
                  icon: FontAwesomeIcons.magnifyingGlass,
                  label: '热量查询',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _showFoodQueryDialog();
                  },
                ),
                _buildActionItem(
                  icon: FontAwesomeIcons.camera,
                  label: '拍照识别',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildActionItem(
                  icon: FontAwesomeIcons.image,
                  label: '相册选择',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                // 可以在这里轻松添加更多功能...
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _submitIngredients() {
    final chatProvider = context.read<ChatProvider>();
    if (chatProvider.selectedIngredients.isEmpty) {
      if (_controller.text.trim().isNotEmpty) {
        chatProvider.addIngredient(_controller.text);
      } else {
        return;
      }
    }
    
    final text = chatProvider.selectedIngredients.join(', ');
    _handleSend(textOverride: text);
    chatProvider.toggleIngredientMode(); // Turn off mode after submit
  }

  void _showFoodQueryDialog() {
     showDialog(
       context: context,
       builder: (context) {
         final controller = TextEditingController();
         return AlertDialog(
           title: const Text('热量查询'),
           content: TextField(
             controller: controller,
             decoration: const InputDecoration(labelText: '食物名称', hintText: '如：一个苹果'),
             autofocus: true,
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
             TextButton(
               onPressed: () {
                 final food = controller.text.trim();
                 if (food.isNotEmpty) {
                   Navigator.pop(context);
                   _handleSend(textOverride: '$food 的热量是多少？');
                 }
               },
               child: const Text('查询'),
             ),
           ],
         );
       },
     );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white : Colors.black87);
    
    _userMarkdownStyle = _buildMarkdownStyle(true, textPrimary);
    _assistantMarkdownStyle = _buildMarkdownStyle(false, textPrimary);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(FontAwesomeIcons.tree, size: 18, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('小松 AI 助手'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                   return const Center(child: CircularProgressIndicator());
                }
                
                // Trigger scroll when last message is streaming
                if (chatProvider.messages.isNotEmpty &&
                    chatProvider.messages.last.isStreaming) {
                  _scheduleStreamingAutoScroll();
                }

                return ListView.builder(
                  controller: _scrollController,
                  cacheExtent: 500, // 增加缓存区域提升滚动流畅度
                  padding: const EdgeInsets.all(16),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(chatProvider.messages[index]);
                  },
                );
              },
            ),
          ),
          RepaintBoundary(child: _buildInputArea()),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final chatProvider = context.read<ChatProvider>();
    final isIngredientMode = context.select<ChatProvider, bool>((p) => p.isIngredientMode);
    final selectedIngredients = context.select<ChatProvider, List<String>>((p) => p.selectedIngredients);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isIngredientMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                color: AppColors.primary.withValues(alpha: 0.05),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🥗 已选食材', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Row(
                          children: [
                            TextButton(
                              onPressed: chatProvider.toggleIngredientMode,
                              child: const Text('退出模式', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            if (selectedIngredients.isNotEmpty)
                              TextButton(
                                onPressed: _submitIngredients,
                                child: const Text('生成食谱', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedIngredients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('在下方输入框添加食材，点击右侧按钮加入列表', 
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedIngredients.asMap().entries.map((e) => Chip(
                          label: Text(
                            e.value, 
                            style: const TextStyle(
                              fontSize: 12, 
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500
                            )
                          ),
                          onDeleted: () => chatProvider.removeIngredient(e.key),
                          deleteIcon: const Icon(
                            Icons.close, 
                            size: 14, 
                            color: AppColors.primary
                          ),
                          backgroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        )).toList(),
                      ),
                  ],
                ),
              ),
            ),

          Row(
            children: [
              _buildIconButton(
                icon: FontAwesomeIcons.circlePlus,
                onTap: _showActionSheet,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: isIngredientMode ? '输入食材名称...' : '输入食材或提问...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: AppColors.border.withValues(alpha: 0.1),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onSubmitted: (_) {
                    if (isIngredientMode) {
                      chatProvider.addIngredient(_controller.text);
                      _controller.clear();
                    } else {
                      _handleSend();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildIconButton(
                icon: isIngredientMode ? Icons.add : Icons.send,
                onTap: () {
                   if (isIngredientMode) {
                      chatProvider.addIngredient(_controller.text);
                      _controller.clear();
                    } else {
                      _handleSend();
                    }
                },
                color: AppColors.primary,
                isFilled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap, required Color color, bool isFilled = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isFilled ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isFilled ? Colors.white : color,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final markdownStyle = isUser ? _userMarkdownStyle : _assistantMarkdownStyle;

    return RepaintBoundary(
      child: Align(
        key: ValueKey('msg_${msg.id}'),
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: (!isUser && msg.isStreaming)
                    ? StreamingMarkdownWidget(
                        key: ValueKey('md_${msg.id}'),
                        text: msg.text,
                        isStreaming: true,
                        selectable: true,
                        styleSheet: markdownStyle,
                      )
                    : MarkdownBody(
                        key: ValueKey('md_static_${msg.id}'),
                        data: msg.formattedText,
                        selectable: true,
                        styleSheet: markdownStyle,
                        fitContent: true,
                        softLineBreak: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(bool isUser, Color textPrimary) {
    final baseColor = isUser ? Colors.white : textPrimary;
    final accentColor = isUser ? Colors.white : AppColors.primary;

    return MarkdownStyleSheet(
      p: TextStyle(color: baseColor, fontSize: 15.5, height: 1.6),
      strong: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
      h1: TextStyle(color: accentColor, fontSize: 19, fontWeight: FontWeight.bold),
      h2: TextStyle(color: accentColor, fontSize: 17, fontWeight: FontWeight.bold),
      h3: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold),
      listBullet: TextStyle(color: accentColor, fontSize: 15),
      listIndent: 28, // 增加缩进，让子列表更明显
      blockquoteDecoration: BoxDecoration(
        color: isUser ? Colors.white12 : AppColors.primary.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: isUser ? Colors.white38 : AppColors.primary, width: 4)),
      ),
      code: TextStyle(
        backgroundColor: isUser ? Colors.black.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.08),
        color: isUser ? Colors.white : AppColors.primary,
        fontFamily: 'monospace',
        fontSize: 13.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: isUser ? Colors.black.withValues(alpha: 0.26) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      tableBorder: TableBorder.all(color: (isUser ? Colors.white : AppColors.border).withValues(alpha: 0.6), width: 1), // 提高边框对比度
      tableBody: TextStyle(color: baseColor, fontSize: 13),
      tableHead: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
