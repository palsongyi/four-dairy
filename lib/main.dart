import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '네컷일기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8D6),
      ),
      home: const MainScreen(),
    );
  }
}

class DiaryEntry {
  final String id;
  final String title;
  final String dateText;
  final List<String> imagePaths;
  final String memo;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.dateText,
    required this.imagePaths,
    required this.memo,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateText': dateText,
    'imagePaths': imagePaths,
    'memo': memo,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      dateText: json['dateText'] as String,
      imagePaths: List<String>.from(json['imagePaths'] as List),
      memo: (json['memo'] ?? '') as String,
    );
  }
}

class DiaryStorage {
  static const _key = 'four_diary_entries';

  Future<List<DiaryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DiaryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveEntries(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<String> copyImageToAppDir(XFile source) async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${dir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().microsecondsSinceEpoch}_${source.name}';
    final saved = File('${imageDir.path}/$fileName');
    return (await File(source.path).copy(saved.path)).path;
  }

  Future<void> deleteImageIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final DiaryStorage _storage = DiaryStorage();
  final List<DiaryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final loaded = await _storage.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(loaded.reversed);
      _isLoading = false;
    });
  }

  Future<void> _openWriteScreen({DiaryEntry? entry}) async {
    final result = await Navigator.push<DiaryEntry?>(
      context,
      MaterialPageRoute(
        builder: (_) => WriteScreen(entry: entry, storage: _storage),
      ),
    );

    if (result == null) return;

    final index = _entries.indexWhere((e) => e.id == result.id);
    setState(() {
      if (index >= 0) {
        _entries[index] = result;
      } else {
        _entries.insert(0, result);
      }
    });
    await _storage.saveEntries(_entries.reversed.toList());
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    for (final path in entry.imagePaths) {
      await _storage.deleteImageIfExists(path);
    }
    _entries.removeWhere((e) => e.id == entry.id);
    await _storage.saveEntries(_entries.reversed.toList());
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('일기를 삭제했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '네컷일기',
          style: GoogleFonts.nanumMyeongjo(
            textStyle: const TextStyle(
              fontSize: 22,
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const _EmptyView()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return DiaryCard(
            entry: entry,
            onEdit: () => _openWriteScreen(entry: entry),
            onDelete: () => _deleteEntry(entry),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWriteScreen,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              '첫 네컷일기를 만들어보세요',
              style: GoogleFonts.nanumMyeongjo(
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '사진 4장과 제목만 넣어도 저장할 수 있어요.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DiaryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFFFF176),
            padding: const EdgeInsets.all(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entry.imagePaths.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(entry.imagePaths[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          ListTile(
            title: Text(
              entry.title,
              style: GoogleFonts.nanumMyeongjo(
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            subtitle: Text('${entry.dateText}\n${entry.memo}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('수정하기')),
                PopupMenuItem(value: 'delete', child: Text('삭제하기')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WriteScreen extends StatefulWidget {
  final DiaryEntry? entry;
  final DiaryStorage storage;

  const WriteScreen({super.key, this.entry, required this.storage});

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late List<String?> _imagePaths;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.entry?.title ?? '';
    _memoController.text = widget.entry?.memo ?? '';
    _imagePaths = List<String?>.filled(4, null);
    if (widget.entry != null) {
      for (int i = 0; i < widget.entry!.imagePaths.length && i < 4; i++) {
        _imagePaths[i] = widget.entry!.imagePaths[i];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int index) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    final savedPath = await widget.storage.copyImageToAppDir(image);
    final oldPath = _imagePaths[index];

    setState(() {
      _imagePaths[index] = savedPath;
    });

    if (oldPath != null && widget.entry != null && oldPath != savedPath) {
      await widget.storage.deleteImageIfExists(oldPath);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagePaths.any((e) => e == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 4장을 모두 선택해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final dateText = '${now.year}.${now.month}.${now.day}';
    final entry = DiaryEntry(
      id: widget.entry?.id ?? now.microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      dateText: widget.entry?.dateText ?? dateText,
      imagePaths: _imagePaths.cast<String>(),
      memo: _memoController.text.trim(),
    );

    if (!mounted) return;
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entry == null ? '네컷일기 작성하기' : '네컷일기 수정하기',
          style: GoogleFonts.nanumMyeongjo(
            textStyle: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    return SelectImg(
                      imagePath: _imagePaths[index],
                      onTap: () => _pickImage(index),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memoController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '한 줄 메모',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? '저장 중...' : '저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectImg extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onTap;

  const SelectImg({super.key, required this.imagePath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF0F0F0),
        ),
        child: imagePath == null
            ? const Icon(Icons.add_photo_alternate_outlined, size: 40)
            : ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(imagePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}
