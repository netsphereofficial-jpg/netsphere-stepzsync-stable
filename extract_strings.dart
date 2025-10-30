import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

void main() async {
  print('🔍 Starting string extraction from Flutter codebase...\n');

  final extractor = StringExtractor();
  await extractor.extractAllStrings();

  print('\n✅ String extraction complete!');
  print('📄 Output file: translation_strings.json');
}

class StringExtractor {
  final List<ExtractedString> allStrings = [];
  final Set<String> processedFiles = {};

  // Directories to scan
  final List<String> targetDirectories = [
    'lib/screens',
    'lib/widgets',
    'lib/controllers',
    'lib/services',
    'lib/core',
    'lib/utils',
  ];

  // Pattern matchers for different string types
  final RegExp textWidgetPattern = RegExp(
    r'''Text\s*\(\s*['"](.+?)['"]''',
    multiLine: true,
  );

  final RegExp appBarTitlePattern = RegExp(
    r'''(?:title|appBarTitle)\s*:\s*(?:Text\s*\(\s*)?['"](.+?)['"]''',
    multiLine: true,
  );

  final RegExp hintTextPattern = RegExp(
    r'''(?:hintText|labelText|helperText|label)\s*:\s*['"](.+?)['"]''',
    multiLine: true,
  );

  final RegExp buttonTextPattern = RegExp(
    r'''(?:ElevatedButton|TextButton|OutlinedButton|MaterialButton|GestureDetector|InkWell).*?child\s*:\s*Text\s*\(\s*['"](.+?)['"]''',
    multiLine: true,
    dotAll: true,
  );

  final RegExp snackBarPattern = RegExp(
    r'''(?:SnackBar|showSnackbar|Get\.snackbar).*?['"](.+?)['"]''',
    multiLine: true,
  );

  final RegExp dialogPattern = RegExp(
    r'''(?:AlertDialog|showDialog|Get\.dialog).*?(?:title|content).*?['"](.+?)['"]''',
    multiLine: true,
    dotAll: true,
  );

  final RegExp stringLiteralPattern = RegExp(
    r'''['"]([^'"]{3,})['"]''',
    multiLine: true,
  );

  Future<void> extractAllStrings() async {
    final baseDir = Directory.current.path;

    for (final dirPath in targetDirectories) {
      final dir = Directory(path.join(baseDir, dirPath));
      if (await dir.exists()) {
        print('📂 Scanning: $dirPath');
        await _scanDirectory(dir, dirPath);
      }
    }

    print('\n📊 Statistics:');
    print('   Total strings found: ${allStrings.length}');
    print('   Files processed: ${processedFiles.length}');

    // Group by category
    final byCategory = <String, int>{};
    for (final str in allStrings) {
      byCategory[str.category] = (byCategory[str.category] ?? 0) + 1;
    }

    print('\n📈 By Category:');
    byCategory.forEach((category, count) {
      print('   $category: $count strings');
    });

    // Save to JSON
    await _saveToJson();
  }

  Future<void> _scanDirectory(Directory dir, String relativePath) async {
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        await _processFile(entity, relativePath);
      } else if (entity is Directory) {
        final newRelativePath = path.join(relativePath, path.basename(entity.path));
        await _scanDirectory(entity, newRelativePath);
      }
    }
  }

  Future<void> _processFile(File file, String directoryContext) async {
    if (processedFiles.contains(file.path)) return;
    processedFiles.add(file.path);

    final content = await file.readAsString();
    final fileName = path.basenameWithoutExtension(file.path);
    final fileCategory = _categorizeFile(file.path, fileName);

    // Extract different types of strings
    _extractTextWidgets(content, file.path, fileName, fileCategory);
    _extractAppBarTitles(content, file.path, fileName, fileCategory);
    _extractHintText(content, file.path, fileName, fileCategory);
    _extractSnackBars(content, file.path, fileName, fileCategory);
    _extractDialogs(content, file.path, fileName, fileCategory);

    // Extract any remaining string literals that might be user-facing
    _extractRemainingStrings(content, file.path, fileName, fileCategory);
  }

  String _categorizeFile(String filePath, String fileName) {
    if (filePath.contains('screens/login') || filePath.contains('screens/signup') ||
        fileName.contains('login') || fileName.contains('auth')) {
      return 'Authentication';
    } else if (filePath.contains('screens/profile') || fileName.contains('profile')) {
      return 'Profile & Settings';
    } else if (filePath.contains('screens/race') || filePath.contains('screens/races') ||
               filePath.contains('create_race') || filePath.contains('quick_race')) {
      return 'Race Management';
    } else if (filePath.contains('screens/active_races') || filePath.contains('race_map')) {
      return 'Active Races';
    } else if (filePath.contains('screens/friends') || filePath.contains('screens/chat') ||
               fileName.contains('friend') || fileName.contains('chat')) {
      return 'Social Features';
    } else if (filePath.contains('screens/leaderboard') || filePath.contains('hall_of_fame')) {
      return 'Leaderboard & Stats';
    } else if (filePath.contains('screens/home') || filePath.contains('homepage') ||
               fileName.contains('navigation')) {
      return 'Home & Navigation';
    } else if (filePath.contains('dialog') || fileName.contains('dialog')) {
      return 'Dialogs & Popups';
    } else if (filePath.contains('subscription') || fileName.contains('premium')) {
      return 'Subscription/Premium';
    } else if (filePath.contains('screens/admin')) {
      return 'Admin Dashboard';
    } else if (filePath.contains('constants') || fileName.contains('error') ||
               fileName.contains('validation')) {
      return 'Errors & Validation';
    } else {
      return 'Common/Shared';
    }
  }

  void _extractTextWidgets(String content, String filePath, String fileName, String category) {
    final matches = textWidgetPattern.allMatches(content);
    for (final match in matches) {
      final text = match.group(1);
      if (text != null && _isUserFacingString(text)) {
        _addString(text, filePath, fileName, category, 'Text Widget');
      }
    }
  }

  void _extractAppBarTitles(String content, String filePath, String fileName, String category) {
    final matches = appBarTitlePattern.allMatches(content);
    for (final match in matches) {
      final text = match.group(1);
      if (text != null && _isUserFacingString(text)) {
        _addString(text, filePath, fileName, category, 'AppBar Title');
      }
    }
  }

  void _extractHintText(String content, String filePath, String fileName, String category) {
    final matches = hintTextPattern.allMatches(content);
    for (final match in matches) {
      final text = match.group(1);
      if (text != null && _isUserFacingString(text)) {
        _addString(text, filePath, fileName, category, 'Form Input');
      }
    }
  }

  void _extractSnackBars(String content, String filePath, String fileName, String category) {
    final matches = snackBarPattern.allMatches(content);
    for (final match in matches) {
      final text = match.group(1);
      if (text != null && _isUserFacingString(text)) {
        _addString(text, filePath, fileName, category, 'Snackbar/Toast');
      }
    }
  }

  void _extractDialogs(String content, String filePath, String fileName, String category) {
    final matches = dialogPattern.allMatches(content);
    for (final match in matches) {
      final text = match.group(1);
      if (text != null && _isUserFacingString(text)) {
        _addString(text, filePath, fileName, category, 'Dialog');
      }
    }
  }

  void _extractRemainingStrings(String content, String filePath, String fileName, String category) {
    final matches = stringLiteralPattern.allMatches(content);
    for (final match in matches) {
      final text = match.group(1);
      if (text != null && _isUserFacingString(text)) {
        // Check if we haven't already captured this string
        final exists = allStrings.any((s) =>
          s.text == text && s.filePath == filePath
        );
        if (!exists) {
          _addString(text, filePath, fileName, category, 'String Literal');
        }
      }
    }
  }

  bool _isUserFacingString(String text) {
    // Filter out non-user-facing strings
    if (text.length < 2) return false;
    if (text.startsWith(RegExp(r'[a-z_]+\.'))) return false; // Likely a property access
    if (text.contains(RegExp(r'^[A-Z_]+$'))) return false; // All caps constants
    if (text.contains('http://') || text.contains('https://')) return false; // URLs
    if (text.contains('@')) return false; // Email-like strings
    if (text.contains('/') && text.length < 20) return false; // Paths
    if (RegExp(r'^[0-9]+$').hasMatch(text)) return false; // Pure numbers
    if (text.contains('firebase') || text.contains('firestore')) return false;
    if (text.contains('collection') || text.contains('document')) return false;
    if (text == 'data' || text == 'id' || text == 'uid') return false;

    // Must have at least one letter
    if (!text.contains(RegExp(r'[a-zA-Z]'))) return false;

    return true;
  }

  void _addString(String text, String filePath, String fileName, String category, String type) {
    // Clean up the text
    text = text
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) return;

    final screenContext = _getScreenContext(fileName, category);
    final notes = _generateNotes(type, text);

    allStrings.add(ExtractedString(
      text: text,
      screenContext: screenContext,
      notes: notes,
      filePath: filePath,
      fileName: fileName,
      category: category,
      type: type,
    ));
  }

  String _getScreenContext(String fileName, String category) {
    // Convert file name to readable screen name
    final readable = fileName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return '$readable ($category)';
  }

  String _generateNotes(String type, String text) {
    final notes = <String>[];

    notes.add(type);

    // Detect placeholders
    if (text.contains(r'$') || text.contains('{')) {
      notes.add('Contains variable placeholder');
    }

    // Detect questions
    if (text.endsWith('?')) {
      notes.add('Question');
    }

    // Detect short strings (likely buttons)
    if (text.split(' ').length <= 3 && type != 'Form Input') {
      notes.add('Likely button label - keep concise');
    }

    // Detect errors
    if (text.toLowerCase().contains('error') ||
        text.toLowerCase().contains('failed') ||
        text.toLowerCase().contains('invalid')) {
      notes.add('Error message');
    }

    // Detect success messages
    if (text.toLowerCase().contains('success') ||
        text.toLowerCase().contains('complete')) {
      notes.add('Success message');
    }

    return notes.join(', ');
  }

  Future<void> _saveToJson() async {
    final output = {
      'metadata': {
        'extractedAt': DateTime.now().toIso8601String(),
        'totalStrings': allStrings.length,
        'filesProcessed': processedFiles.length,
      },
      'strings': allStrings.map((s) => s.toJson()).toList(),
    };

    final file = File('translation_strings.json');
    await file.writeAsString(
      JsonEncoder.withIndent('  ').convert(output)
    );
  }
}

class ExtractedString {
  final String text;
  final String screenContext;
  final String notes;
  final String filePath;
  final String fileName;
  final String category;
  final String type;

  ExtractedString({
    required this.text,
    required this.screenContext,
    required this.notes,
    required this.filePath,
    required this.fileName,
    required this.category,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'screenContext': screenContext,
    'notes': notes,
    'filePath': filePath,
    'fileName': fileName,
    'category': category,
    'type': type,
  };
}
