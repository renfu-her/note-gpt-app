import 'package:flutter/material.dart';
import '../widgets/markdown_viewer.dart';
import '../services/api_service.dart';

class NotePage extends StatefulWidget {
  const NotePage({Key? key}) : super(key: key);

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  String _markdownContent = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 這裡可以加載筆記內容
    _loadNoteContent();
  }

  Future<void> _loadNoteContent() async {
    // 這裡示範一些 Markdown 內容
    setState(() {
      _markdownContent = '''
# 我的筆記

這是一個 Markdown 筆記示例。

## 功能特點

- 支援基本 Markdown 語法
- 可以顯示程式碼區塊
- 支援表格

### 程式碼示例

```dart
void main() {
  print('Hello, Markdown!');
}
```

### 表格示例

| 欄位1 | 欄位2 |
|-------|-------|
| 內容1 | 內容2 |
| 內容3 | 內容4 |
''';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('筆記'),
      ),
      body: MarkdownViewer(
        markdownData: _markdownContent,
        scrollController: _scrollController,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 