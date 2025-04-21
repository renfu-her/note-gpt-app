import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../services/api_service.dart';
import '../widgets/markdown_viewer.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _currentFolderName = '';
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
      
      // 關閉抽屜
      Navigator.pop(context);
      
      setState(() {
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
          _currentFolderName = '';
          _currentNotes = [];
          _selectedNote = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('無法載入資料夾內容：${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
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
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _selectedNote!['content'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
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

                await _apiService.logout();

                if (!mounted) return;
                // 關閉載入指示器
                Navigator.pop(context);
                
                // 返回登入頁面
                Navigator.pushReplacementNamed(context, '/login');
              } catch (e) {
                // 如果載入指示器還在顯示，就關閉它
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }

                // 顯示錯誤訊息
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('登出失敗：${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
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
                      child: _buildFolderTree(_folders),
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
            InkWell(
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
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        folder.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
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
} 