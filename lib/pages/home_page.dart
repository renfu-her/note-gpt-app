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
    try {
      setState(() => _isLoading = true);
      final response = await _apiService.getFolderNotes(folderId);
      
      if (!mounted) return;
      
      setState(() {
        _currentFolderId = folderId.toString();
        _currentFolderName = response['name'] as String;
        _currentNotes = List<Map<String, dynamic>>.from(response['notes']);
        _currentNotes.sort((a, b) => (b['created_at'] as DateTime)
            .compareTo(a['created_at'] as DateTime));
        _selectedNote = null;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentFolderId = '';
          _currentFolderName = '';
          _currentNotes = [];
          _selectedNote = null;
          _isLoading = false;
        });
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: Text(_currentFolderName.isEmpty ? '雲端筆記' : _currentFolderName),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_currentFolderName.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.note_add),
              onPressed: () => _showCreateNoteDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: () => _showCreateFolderDialog(context),
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
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Center(
                child: Text(
                  '雲端筆記',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
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
        child: Container(
          color: Colors.white,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : buildNoteContent(),
        ),
      ),
    );
  }

  Widget _buildFolderTree(List<Folder> folders, {double indent = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: folders.map((folder) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: () => _loadFolderNotes(folder.id),
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

  // 展平成帶縮排的資料夾清單
  List<Map<String, dynamic>> _flattenFolders(List<Folder> folders, {int level = 0}) {
    List<Map<String, dynamic>> result = [];
    for (final folder in folders) {
      result.add({
        'folder': folder,
        'indent': level,
      });
      if (folder.children.isNotEmpty) {
        result.addAll(_flattenFolders(folder.children, level: level + 1));
      }
    }
    return result;
  }

  Future<void> _showCreateNoteDialog(BuildContext context) async {
    Folder? selectedFolder = _folders.isNotEmpty
        ? _folders.firstWhere(
            (f) => f.id.toString() == _currentFolderId,
            orElse: () => _folders.first,
          )
        : null;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final scaffoldContext = ScaffoldMessenger.of(context);
    final flatFolders = _flattenFolders(_folders);
    File? selectedFile;
    bool useFile = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('新增筆記', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
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
                    selectedFolder = folder;
                  },
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '內容',
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();
                        if (title.isEmpty) {
                          scaffoldContext.showSnackBar(
                            const SnackBar(
                              content: Text('請輸入標題'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (selectedFolder == null) {
                          scaffoldContext.showSnackBar(
                            const SnackBar(
                              content: Text('請選擇資料夾'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (!useFile && content.isEmpty) {
                          scaffoldContext.showSnackBar(
                            const SnackBar(
                              content: Text('請輸入內容或選擇檔案'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (useFile && selectedFile == null) {
                          scaffoldContext.showSnackBar(
                            const SnackBar(
                              content: Text('請選擇 .md 檔案'),
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
                            folderId: selectedFolder!.id,
                            title: title,
                            content: !useFile ? content : null,
                            file: useFile ? selectedFile : null,
                          );
                          if (!mounted) return;
                          if (_currentFolderId == selectedFolder!.id.toString()) {
                            setState(() {
                              _currentNotes.insert(0, {
                                'id': newNote['id'],
                                'title': newNote['title'],
                                'created_at': newNote['created_at'],
                              });
                            });
                          }
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
                      child: const Text('創建'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // 清理控制器
    titleController.dispose();
    contentController.dispose();
  }

  void _showEditNoteDialog(BuildContext context, Map<String, dynamic> note) async {
    final titleController = TextEditingController(text: note['title'] as String);
    final contentController = TextEditingController(text: note['content'] as String);
    final scaffoldContext = ScaffoldMessenger.of(context);
    File? selectedFile;
    bool useFile = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('編輯筆記', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
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
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '內容',
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();
                        if (title.isEmpty) {
                          scaffoldContext.showSnackBar(
                            const SnackBar(
                              content: Text('請輸入標題'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (!useFile && content.isEmpty) {
                          scaffoldContext.showSnackBar(
                            const SnackBar(
                              content: Text('請輸入內容或選擇檔案'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (useFile && selectedFile == null) {
                          scaffoldContext.showSnackBar(
                            const SnackBar(
                              content: Text('請選擇 .md 檔案'),
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
                            content: !useFile ? content : null,
                            file: useFile ? selectedFile : null,
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
                          Navigator.of(context).pop(); // 關閉 loading
                          Navigator.of(context).pop(); // 關閉 bottom sheet
                          scaffoldContext.showSnackBar(
                            const SnackBar(content: Text('筆記已更新')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.of(context).pop(); // 關閉 loading
                          scaffoldContext.showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('儲存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    titleController.dispose();
    contentController.dispose();
  }
} 