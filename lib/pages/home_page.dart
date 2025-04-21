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
  List<Folder> _folders = [];
  List<Note> _currentNotes = [];
  String _currentFolderName = '';
  Note? _selectedNote;
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await _apiService.getFolders();
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
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
        final notes = response['notes'] as List<Note>;
        _currentNotes = notes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _selectedNote = _currentNotes.isNotEmpty ? _currentNotes.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _selectNote(Note note) {
    setState(() {
      _selectedNote = note;
    });
    
    // 在窄螢幕上選擇筆記後關閉抽屜
    if (MediaQuery.of(context).size.width <= 600) {
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildNoteList({bool inDrawer = false}) {
    if (_currentNotes.isEmpty) {
      return const Center(child: Text('此資料夾中沒有筆記'));
    }

    return ListView.builder(
      itemCount: _currentNotes.length,
      itemBuilder: (context, index) {
        final note = _currentNotes[index];
        return ListTile(
          title: Text(
            note.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatDate(note.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          selected: _selectedNote?.id == note.id,
          onTap: () => _selectNote(note),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_currentFolderName.isEmpty ? 'Note GPT' : _currentFolderName),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (!isWideScreen && _currentNotes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _currentFolderName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const Divider(),
                        Expanded(child: _buildNoteList(inDrawer: true)),
                      ],
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _apiService.logout();
              if (mounted) {
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
                  'Note GPT',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                if (isWideScreen) ...[
                  SizedBox(
                    width: 300,
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: _buildNoteList(),
                    ),
                  ),
                ],
                Expanded(
                  child: _selectedNote == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.note,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '選擇一個筆記來查看內容',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Card(
                          margin: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedNote!.title,
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatDate(_selectedNote!.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: MarkdownViewer(
                                    markdownData: _selectedNote!.content,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
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