import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../services/api_service.dart';
import '../widgets/markdown_viewer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_html/flutter_html.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:markdown_toolbar/markdown_toolbar.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:ui';

// 新增：Dialog 內容 StatefulWidget
class NoteEditDialog extends StatefulWidget {
  final String title;
  final String? initialTitle;
  final String? initialContent;
  final bool isEdit;
  final Function(String, String, File?, Folder?) onSave;
  final List<Folder> folders;
  final Folder? selectedFolder;

  const NoteEditDialog({
    Key? key,
    required this.title,
    this.initialTitle,
    this.initialContent,
    required this.isEdit,
    required this.onSave,
    required this.folders,
    this.selectedFolder,
  }) : super(key: key);

  @override
  State<NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<NoteEditDialog> {
  late TextEditingController titleController;
  late TextEditingController contentController;
  late FocusNode contentFocusNode;
  File? selectedFile;
  bool useFile = false;
  Folder? selectedFolder;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle ?? '');
    contentController = TextEditingController(text: widget.initialContent ?? '');
    contentFocusNode = FocusNode();
    selectedFolder = widget.selectedFolder ?? (widget.folders.isNotEmpty ? widget.folders.first : null);
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> flatFolders = [];
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows;
    
    void flattenFolders(List<Folder> folders, int level) {
      for (final folder in folders) {
        flatFolders.add({
          'folder': folder,
          'indent': level,
        });
        if (folder.children.isNotEmpty) {
          flattenFolders(folder.children, level + 1);
        }
      }
    }
    
    flattenFolders(widget.folders, 0);
    
    return Container(
      height: isDesktop 
          ? MediaQuery.of(context).size.height * 0.9  // Windows 版本使用 90% 的螢幕高度
          : MediaQuery.of(context).size.height * 0.95,
      width: isDesktop 
          ? MediaQuery.of(context).size.width * 0.8   // Windows 版本使用 80% 的螢幕寬度
          : null,
      margin: isDesktop
          ? EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.1,
              vertical: MediaQuery.of(context).size.height * 0.05,
            )
          : null,
      decoration: BoxDecoration(
        color: Theme.of(context).dialogBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(24),
          bottom: isDesktop ? const Radius.circular(24) : Radius.zero,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (!widget.isEdit) ...[
                  if (flatFolders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        '請先創建資料夾',
                        style: TextStyle(color: Colors.red),
                      ),
                    )
                  else
                    DropdownButtonFormField<Folder>(
                      value: selectedFolder,
                      decoration: const InputDecoration(
                        labelText: '選擇資料夾',
                        border: OutlineInputBorder(),
                      ),
                      items: flatFolders.map((item) {
                        final folder = item['folder'] as Folder;
                        final indent = item['indent'] as int;
                        return DropdownMenuItem<Folder>(
                          value: folder,
                          child: Padding(
                            padding: EdgeInsets.only(left: indent * 20.0),
                            child: Text(folder.name),
                          ),
                        );
                      }).toList(),
                      onChanged: (folder) {
                        setState(() {
                          selectedFolder = folder;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: useFile,
                      onChanged: (v) async {
                        if (v == true) {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['md']);
                          if (result != null && result.files.single.path != null) {
                            setState(() {
                              selectedFile = File(result.files.single.path!);
                              useFile = true;
                            });
                          }
                        } else {
                          setState(() {
                            useFile = false;
                            selectedFile = null;
                          });
                        }
                      },
                    ),
                    const Text('上傳 .md 檔案'),
                    if (selectedFile != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            selectedFile!.path.split('/').last,
                            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                children: [
                  if (!useFile)
                    MarkdownToolbar(
                      useIncludedTextField: false,
                      controller: contentController,
                      focusNode: contentFocusNode,
                      iconSize: 20,
                      height: 36,
                      spacing: 2,
                      runSpacing: 0,
                      backgroundColor: Colors.grey[100]!,
                      iconColor: Colors.blueGrey,
                    ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: TextField(
                      controller: contentController,
                      focusNode: contentFocusNode,
                      decoration: const InputDecoration(
                        labelText: '內容（Markdown 格式）',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      enabled: !useFile,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('請輸入標題'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (!useFile && content.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('請輸入內容或選擇檔案'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (useFile && selectedFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('請選擇 .md 檔案'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          widget.onSave(title, content, useFile ? selectedFile : null, selectedFolder);
                        },
                        child: Text(widget.isEdit ? '儲存' : '創建'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _currentFolderName = '';
  String _currentFolderId = '';
  List<Map<String, dynamic>> _currentNotes = [];
  Map<String, dynamic>? _selectedNote;
  List<Folder> _folders = [];
  bool _isLoading = false;
  bool _isLoadingNote = false;
  final FocusNode contentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      setState(() => _isLoading = true);
      final folders = await _apiService.getFolders();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _loadFolderNotes(int folderId) async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getFolderNotes(folderId);
      print('DEBUG: response = $response');

      if (!mounted) return;
      
      setState(() {
        _currentFolderId = folderId.toString();
        _currentFolderName = response['name'] as String;
        _currentNotes = List<Map<String, dynamic>>.from(response['notes']);
        if (_currentNotes.isNotEmpty) {
          _currentNotes.sort((a, b) => (b['created_at'] as DateTime)
              .compareTo(a['created_at'] as DateTime));
        }
        _selectedNote = null;
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: error = $e');
      if (mounted) {
        // 清空當前資料夾狀態
        setState(() {
          _currentFolderId = '';
          _currentFolderName = '';
          _currentNotes = [];
          _selectedNote = null;
          _isLoading = false;
        });

        // 如果是找不到資料夾，重新載入資料夾列表
        if (e.toString().contains('找不到此資料夾')) {
          _loadFolders();  // 重新載入資料夾列表
        }

        // 顯示錯誤訊息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: e.toString().contains('找不到此資料夾') ? SnackBarAction(
              label: '確定',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ) : null,
          ),
        );
      }
    }
  }

  Future<void> _loadNote(int noteId) async {
    try {
      setState(() => _isLoadingNote = true);
      final note = await _apiService.getNote(noteId);
      if (!mounted) return;
      setState(() {
        _selectedNote = note;
        _isLoadingNote = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNote = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('無法載入筆記內容：${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectNote(Map<String, dynamic> note) {
    _loadNote(note['id'] as int);
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildNoteList() {
    if (_currentNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '此資料夾中沒有筆記',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.note_add),
              label: const Text('新增筆記'),
              onPressed: () => _showCreateNoteDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _currentNotes.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final note = _currentNotes[index];
        return ListTile(
          title: Text(
            note['title'] as String,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: Text(
            _formatDate(note['created_at'] as DateTime),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          onTap: () => _selectNote(note),
        );
      },
    );
  }

  Widget buildNoteContent() {
    if (_selectedNote == null) {
      return _buildNoteList();
    }

    if (_isLoadingNote) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedNote!['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(_selectedNote!['created_at'] as DateTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: '編輯',
                  onPressed: () => _showEditNoteDialog(context, _selectedNote!),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) {
                    final htmlContent = md.markdownToHtml(_selectedNote!['content'] as String);
                    print('DEBUG: markdownToHtml =\n$htmlContent');
                    return Html(
                      data: htmlContent,
                      style: {
                        "pre": Style(
                          backgroundColor: Colors.grey.shade200,
                          padding: HtmlPaddings.all(8),
                          fontFamily: 'monospace',
                          fontSize: FontSize(14),
                          whiteSpace: WhiteSpace.pre,
                        ),
                        "code": Style(
                          backgroundColor: Colors.grey.shade100,
                          padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                          fontFamily: 'monospace',
                          fontSize: FontSize(14),
                        ),
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: Text(_currentFolderName.isEmpty ? '雲端筆記' : _currentFolderName),
        leading: isDesktop ? null : IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_currentFolderName.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'new_note':
                    _showCreateNoteDialog(context);
                    break;
                  case 'new_folder':
                    _showCreateFolderDialog(context);
                    break;
                  case 'delete_folder':
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('確認刪除'),
                        content: Text('確定要刪除「$_currentFolderName」資料夾嗎？\n此操作無法復原。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('刪除'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    try {
                      // 顯示載入指示器
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      await _apiService.deleteFolder(int.parse(_currentFolderId));
                      
                      if (!mounted) return;
                      
                      // 關閉載入指示器
                      Navigator.pop(context);
                      
                      // 清空當前資料夾
                      setState(() {
                        _currentFolderId = '';
                        _currentFolderName = '';
                        _currentNotes = [];
                        _selectedNote = null;
                      });
                      
                      // 重新載入資料夾列表
                      await _loadFolders();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('資料夾已刪除')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      
                      // 關閉載入指示器
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'new_note',
                  child: Row(
                    children: [
                      Icon(Icons.note_add, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('新增筆記'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'new_folder',
                  child: Row(
                    children: [
                      Icon(Icons.create_new_folder, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('新增資料夾'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete_folder',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        '刪除資料夾',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                // 顯示確認對話框
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('確認登出'),
                    content: const Text('確定要登出嗎？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('確定'),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                // 顯示載入指示器
                if (!mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  await _apiService.logout();
                } catch (e) {
                  // 忽略登出錯誤
                  print('登出錯誤：$e');
                } finally {
                  // 無論如何都清除本地 token
                  await _storage.delete(key: 'token');
                  
                  if (!mounted) return;
                  // 關閉載入指示器
                  Navigator.pop(context);
                  // 返回登入頁面
                  Navigator.pushReplacementNamed(context, '/login');
                }
              } catch (e) {
                // 如果載入指示器還在顯示，就關閉它
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                
                // 返回登入頁面
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      drawer: isDesktop ? null : Drawer(
        child: Column(
          children: [
            Container(
              height: 48,
              color: Theme.of(context).primaryColor,
              alignment: Alignment.center,
              child: const Text(
                '雲端筆記',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: _buildFolderTree(_folders),
                      ),
                    ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(
                        right: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 48,
                          color: Theme.of(context).primaryColor,
                          alignment: Alignment.center,
                          child: const Text(
                            '雲端筆記',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16.0),
                                    child: _buildFolderTree(_folders),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : buildNoteContent(),
                    ),
                  ),
                ],
              )
            : Container(
                color: Colors.white,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : buildNoteContent(),
              ),
      ),
    );
  }

  Widget _buildFolderTree(List<Folder> folders, {double indent = 0}) {
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: folders.map((folder) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: () {
                  _loadFolderNotes(folder.id);
                  // 只在非桌面版（使用 Drawer）時關閉抽屜
                  if (!isDesktop) {
                    Navigator.of(context).pop();
                  }
                },
                child: Container(
                  padding: EdgeInsets.only(
                    left: indent,
                    top: 12,
                    bottom: 12,
                    right: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        folder.children.isEmpty
                            ? Icons.folder_outlined
                            : Icons.folder,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          folder.name,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (folder.children.isNotEmpty)
              _buildFolderTree(folder.children, indent: indent + 24),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    Folder? selectedParent;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('創建資料夾'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '資料夾名稱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Folder?>(
                    value: selectedParent,
                    decoration: const InputDecoration(
                      labelText: '上層資料夾',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Folder?>(
                        value: null,
                        child: Text('沒有上層資料夾'),
                      ),
                      ..._folders.map((folder) => DropdownMenuItem<Folder>(
                        value: folder,
                        child: Text(folder.name),
                      )).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedParent = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '描述（選填）',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('請輸入資料夾名稱'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    final navigatorContext = Navigator.of(context);
                    final scaffoldContext = ScaffoldMessenger.of(context);
                    
                    // 顯示載入指示器
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    await _apiService.createFolder(
                      name: name,
                      parentId: selectedParent?.id,
                      description: descriptionController.text.trim(),
                      sortOrder: 0,
                      isActive: true,
                    );
                    
                    if (!mounted) return;

                    // 關閉載入指示器和對話框
                    navigatorContext.pop();  // 關閉載入指示器
                    navigatorContext.pop();  // 關閉創建對話框
                    
                    // 重新載入資料夾列表
                    await _loadFolders();
                    
                    scaffoldContext.showSnackBar(
                      const SnackBar(content: Text('資料夾創建成功')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.of(context).pop();  // 關閉載入指示器
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('創建資料夾失敗：${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('創建'),
              ),
            ],
          );
        },
      ),
    );

    // 清理控制器
    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showCreateNoteDialog(BuildContext context) async {
    final scaffoldContext = ScaffoldMessenger.of(context);
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows;

    if (isDesktop) {
      // Windows 版本使用普通對話框
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: NoteEditDialog(
            title: '新增筆記',
            isEdit: false,
            folders: _folders,
            selectedFolder: _folders.isNotEmpty
                ? _folders.firstWhere(
                    (f) => f.id.toString() == _currentFolderId,
                    orElse: () => _folders.first,
                  )
                : null,
            onSave: (title, content, file, folder) async {
              if (title.isEmpty || folder == null) {
                scaffoldContext.showSnackBar(
                  const SnackBar(
                    content: Text('請輸入標題並選擇資料夾'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                final newNote = await _apiService.createNote(
                  folderId: folder.id,
                  title: title,
                  content: file == null ? content : null,
                  file: file,
                );

                if (!mounted) return;

                if (_currentFolderId == folder.id.toString()) {
                  setState(() {
                    _currentNotes.insert(0, {
                      'id': newNote['id'],
                      'title': newNote['title'],
                      'created_at': newNote['created_at'],
                    });
                  });
                }

                Navigator.of(context).pop(); // 關閉載入指示器
                Navigator.of(context).pop(); // 關閉對話框
                scaffoldContext.showSnackBar(
                  const SnackBar(content: Text('筆記創建成功')),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop(); // 關閉載入指示器
                scaffoldContext.showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
    } else {
      // 手機版使用底部彈出
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => NoteEditDialog(
          title: '新增筆記',
          isEdit: false,
          folders: _folders,
          selectedFolder: _folders.isNotEmpty
              ? _folders.firstWhere(
                  (f) => f.id.toString() == _currentFolderId,
                  orElse: () => _folders.first,
                )
              : null,
          onSave: (title, content, file, folder) async {
            if (title.isEmpty || folder == null) {
              scaffoldContext.showSnackBar(
                const SnackBar(
                  content: Text('請輸入標題並選擇資料夾'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            try {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              final newNote = await _apiService.createNote(
                folderId: folder.id,
                title: title,
                content: file == null ? content : null,
                file: file,
              );

              if (!mounted) return;

              if (_currentFolderId == folder.id.toString()) {
                setState(() {
                  _currentNotes.insert(0, {
                    'id': newNote['id'],
                    'title': newNote['title'],
                    'created_at': newNote['created_at'],
                  });
                });
              }

              Navigator.of(context).pop(); // 關閉載入指示器
              Navigator.of(context).pop(); // 關閉 bottom sheet
              scaffoldContext.showSnackBar(
                const SnackBar(content: Text('筆記創建成功')),
              );
            } catch (e) {
              if (!mounted) return;
              Navigator.of(context).pop(); // 關閉載入指示器
              scaffoldContext.showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      );
    }
  }

  void _showEditNoteDialog(BuildContext context, Map<String, dynamic> note) async {
    final scaffoldContext = ScaffoldMessenger.of(context);
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows;

    if (isDesktop) {
      // Windows 版本使用普通對話框
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: NoteEditDialog(
            title: '編輯筆記',
            isEdit: true,
            folders: _folders,
            initialTitle: note['title'] as String,
            initialContent: note['content'] as String,
            onSave: (title, content, file, folder) async {
              if (title.isEmpty) {
                scaffoldContext.showSnackBar(
                  const SnackBar(
                    content: Text('請輸入標題'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                final updatedNote = await _apiService.updateNote(
                  noteId: note['id'] as int,
                  title: title,
                  content: file == null ? content : null,
                  file: file,
                );

                if (!mounted) return;

                setState(() {
                  _selectedNote = updatedNote;
                  // 同步更新 _currentNotes
                  final idx = _currentNotes.indexWhere((n) => n['id'] == updatedNote['id']);
                  if (idx != -1) {
                    _currentNotes[idx]['title'] = updatedNote['title'];
                    _currentNotes[idx]['created_at'] = updatedNote['created_at'];
                  }
                });

                Navigator.of(context).pop(); // 關閉載入指示器
                Navigator.of(context).pop(); // 關閉對話框
                scaffoldContext.showSnackBar(
                  const SnackBar(content: Text('筆記已更新')),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop(); // 關閉載入指示器
                scaffoldContext.showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
    } else {
      // 手機版使用底部彈出
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => NoteEditDialog(
          title: '編輯筆記',
          isEdit: true,
          folders: _folders,
          initialTitle: note['title'] as String,
          initialContent: note['content'] as String,
          onSave: (title, content, file, folder) async {
            if (title.isEmpty) {
              scaffoldContext.showSnackBar(
                const SnackBar(
                  content: Text('請輸入標題'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            try {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              final updatedNote = await _apiService.updateNote(
                noteId: note['id'] as int,
                title: title,
                content: file == null ? content : null,
                file: file,
              );

              if (!mounted) return;

              setState(() {
                _selectedNote = updatedNote;
                // 同步更新 _currentNotes
                final idx = _currentNotes.indexWhere((n) => n['id'] == updatedNote['id']);
                if (idx != -1) {
                  _currentNotes[idx]['title'] = updatedNote['title'];
                  _currentNotes[idx]['created_at'] = updatedNote['created_at'];
                }
              });

              Navigator.of(context).pop(); // 關閉載入指示器
              Navigator.of(context).pop(); // 關閉 bottom sheet
              scaffoldContext.showSnackBar(
                const SnackBar(content: Text('筆記已更新')),
              );
            } catch (e) {
              if (!mounted) return;
              Navigator.of(context).pop(); // 關閉載入指示器
              scaffoldContext.showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      );
    }
  }
} 