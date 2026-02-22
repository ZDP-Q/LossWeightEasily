/// Markdown 结构化纠偏与流式补全工具类
class MarkdownUtil {
  static final _thinkRegExp = RegExp(r'<think>[\s\S]*?(?:</think>|$)', caseSensitive: false);

  /// 核心格式化逻辑 (终极结构化纠偏版 v2)
  static String format(String raw, {bool isStreaming = false}) {
    if (raw.isEmpty) return raw;

    // 0. 预处理：移除思维链标签
    String text = raw.replaceAll(_thinkRegExp, '').replaceAll('</think>', '');

    // 0.1 中文加粗渲染修复：当 ** 紧邻中文且后接引号时（如：而是**“吃对”），强制插入空格
    // 原因：CommonMark 规范要求此时左侧需有空格才能被识别为开始标记
    text = text.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5])(\*\*)([“"‘])'),
      (match) => '${match.group(1)} ${match.group(2)}${match.group(3)}'
    );

    final lines = text.split('\n');
    final processed = <String>[];

    // 状态机变量
    bool inTable = false;
    // 记录上一行列表的缩进级别 (用于推断子列表)
    int lastListIndentLevel = 0; 
    // 记录上一行是否为列表项
    bool lastLineWasList = false;
    // 记录上一行的列表符号 (用于区分父子级: • vs -)
    String lastListBullet = '';

    // 正则预编译
    final tableRowRegex = RegExp(r'^\s*\|.*\|\s*$');
    // 匹配看起来像表格行，但被列表符污染的行 (e.g. "• | data |")
    final dirtyTableRegex = RegExp(r'^\s*[-*+•]\s*(\|.*\|)\s*$');
    // 匹配标准列表行 (group1: indent, group2: bullet, group3: content)
    final listRegex = RegExp(r'^(\s*)([-*+•]|\d+\.)\s+(.*)');
    // 匹配紧凑列表行 (e.g. "-Text", "-**Text") -> group1: indent, group2: bullet, group3: content
    final tightListRegex = RegExp(r'^(\s*)([-*+])([^\s].*)');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      String trimmed = line.trim();

      if (trimmed.isEmpty) {
        // 空行重置表格和列表状态
        inTable = false;
        lastLineWasList = false;
        lastListIndentLevel = 0;
        lastListBullet = '';
        processed.add('');
        continue;
      }

      // --- 1. 表格逻辑 (修复 t.jpg 溢出问题) ---
      // 如果当前行本身就是表格行，或者被污染的表格行
      bool isDirtyTable = dirtyTableRegex.hasMatch(line);
      bool isCleanTable = tableRowRegex.hasMatch(line);
      
      // 如果处于表格上下文中，或者检测到明确的表格行
      if (inTable || isCleanTable || isDirtyTable) {
        if (isDirtyTable) {
          // 强力吸附：去除行首列表符，还原为表格行
          var match = dirtyTableRegex.firstMatch(line);
          if (match != null) {
              line = match.group(1)!;
              inTable = true;
          }
        } else if (isCleanTable) {
          inTable = true;
        } else if (trimmed.startsWith('|')) {
           // 可能是表格的分隔线或不完整的行
           inTable = true;
        } else {
          // 如果不再像表格，且之前在表格中，则退出表格模式
          inTable = false;
        }
        
        if (inTable) {
           processed.add(line);
           lastLineWasList = false; // 表格打断列表连续性
           continue; // 表格行处理完毕，跳过后续逻辑
        }
      }

      // --- 2. 列表逻辑 (修复 tt.jpg 缩进与格式问题) ---
      
      // A. 修复紧凑格式 (-text -> - text)
      var tightMatch = tightListRegex.firstMatch(line);
      if (tightMatch != null) {
        line = '${tightMatch.group(1)}${tightMatch.group(2)} ${tightMatch.group(3)}';
      }

      // B. 缩进与层级调整
      var listMatch = listRegex.firstMatch(line);
      if (listMatch != null) {
        String currentIndentStr = listMatch.group(1) ?? '';
        String bullet = listMatch.group(2) ?? '';
        // String content = listMatch.group(3) ?? ''; // Unused for logic, kept for clarity
        
        int currentIndentLevel = currentIndentStr.length;

        // 智能缩进策略：
        // 如果上一行是列表，且当前行是短横线 (-)，且当前无缩进
        // 而上一行是不同类型的符号 (如 •, *, 1.)，则极大可能是子项，强制缩进。
        // tt.jpg 案例: 父项 •, 子项 - (无缩进) -> 强制缩进
        if (lastLineWasList && currentIndentLevel == 0 && bullet == '-') {
           if (lastListBullet != '-' || lastListIndentLevel > 0) {
             // 如果上一行不是 - (是父级)，或者上一行本身就是有缩进的子级
             // 此时这个无缩进的 - 应该是同级或子级。
             // 结合 AI 习惯，父项 • 后的无缩进 - 通常是子项。
             if (lastListBullet != '-') {
                 line = '  $line'; // 强制加 2 空格
                 currentIndentLevel = 2;
             }
           }
        }
        
        // 记录状态供下一行使用
        lastLineWasList = true;
        lastListIndentLevel = currentIndentLevel;
        lastListBullet = bullet;
      } else {
        // 普通文本行
        lastLineWasList = false;
        lastListIndentLevel = 0;
        lastListBullet = '';
        
        // C. 标题美化 (加空格 #Title -> # Title)
        if (line.startsWith('#')) {
             line = line.replaceFirstMapped(RegExp(r'^(#+)([^\s#])'), (m) => '${m[1]} ${m[2]}');
        }
      }

      processed.add(line);
    }

    String result = processed.join('\n');

    if (isStreaming) {
      result = _applyStreamingFixes(result, inTable);
    }

    return result.replaceAll('\r\n', '\n');
  }

  static String _applyStreamingFixes(String text, bool inTable) {
    if (inTable && !text.trim().endsWith('|')) {
      text = '$text |';
    }
    final codeFenceCount = '```'.allMatches(text).length;
    if (codeFenceCount.isOdd) {
      text = '$text\n```';
    }
    if (text.endsWith('\n') || text.endsWith(' ')) return '$text▊';
    return '$text ▊';
  }
}
