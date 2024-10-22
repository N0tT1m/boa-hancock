import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, Process;

// Update the FileItem class to include share_name
class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedTime;
  final String share_name;    // Added this field
  final String display_name;  // Added this field

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedTime,
    required this.share_name,    // Added this parameter
    required this.display_name,  // Added this parameter
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'],
      path: json['path'],
      isDirectory: json['is_directory'],
      size: json['size'],
      modifiedTime: DateTime.parse(json['modified_time']),
      share_name: json['share_name'],       // Parse from JSON
      display_name: json['display_name'],   // Parse from JSON
    );
  }
}

// Update the ImageSearchResult class
class ImageSearchResult {
  final String title;
  final String link;
  final String thumbnailLink;
  final String displayLink;
  final String mime;
  final String? fileFormat;
  final String? contextLink;

  ImageSearchResult({
    required this.title,
    required this.link,
    required this.thumbnailLink,
    required this.displayLink,
    required this.mime,
    this.fileFormat,
    this.contextLink,
  });

  factory ImageSearchResult.fromJson(Map<String, dynamic> json) {
    return ImageSearchResult(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      thumbnailLink: json['thumbnailLink'] ?? '',
      displayLink: json['displayLink'] ?? '',
      mime: json['mime'] ?? '',
      fileFormat: json['fileFormat'],
      contextLink: json['contextLink'],
    );
  }
}

// Update the WebSearchResult class
class WebSearchResult {
  final String title;
  final String link;
  final String snippet;

  WebSearchResult({
    required this.title,
    required this.link,
    required this.snippet,
  });

  factory WebSearchResult.fromJson(Map<String, dynamic> json) {
    return WebSearchResult(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      snippet: json['snippet'] ?? '',
    );
  }
}

// Update the DocumentAnalysisResult class
class DocumentAnalysisResult {
  final String filename;
  final String content;
  final DocumentMetadata metadata;
  final List<List<dynamic>>? excelData;

  DocumentAnalysisResult({
    required this.filename,
    required this.content,
    required this.metadata,
    this.excelData,
  });

  factory DocumentAnalysisResult.fromJson(Map<String, dynamic> json) {
    return DocumentAnalysisResult(
      filename: json['filename'] ?? '',
      content: json['content'] ?? '',
      metadata: DocumentMetadata.fromJson(json['metadata'] ?? {}),
      excelData: json['excel_data'] != null
          ? List<List<dynamic>>.from(json['excel_data']
          .map((row) => List<dynamic>.from(row)))
          : null,
    );
  }
}

class DocumentMetadata {
  final int numRows;
  final int numColumns;
  final List<String> columnNames;
  final int numPages;
  final String? author;
  final String? creator;
  final String? producer;
  final String? subject;
  final String? title;
  final String? creationDate;
  final String? modificationDate;
  final String? language;
  final String? summary;
  final String? complexity;
  final List<String>? suggestions;

  DocumentMetadata({
    this.numRows = 0,
    this.numColumns = 0,
    this.columnNames = const [],
    this.numPages = 0,
    this.author,
    this.creator,
    this.producer,
    this.subject,
    this.title,
    this.creationDate,
    this.modificationDate,
    this.language,
    this.summary,
    this.complexity,
    this.suggestions,
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      numRows: json['num_rows'] ?? 0,
      numColumns: json['num_columns'] ?? 0,
      columnNames: List<String>.from(json['column_names'] ?? []),
      numPages: json['num_pages'] ?? 0,
      author: json['author'],
      creator: json['creator'],
      producer: json['producer'],
      subject: json['subject'],
      title: json['title'],
      creationDate: json['creation_date'],
      modificationDate: json['modification_date'],
      language: json['language'],
      summary: json['summary'],
      complexity: json['complexity'],
      suggestions: json['suggestions'] != null ? List<String>.from(json['suggestions']) : null,
    );
  }
}

class FinancialAnalysis {
  final List<Expense> expenses;
  final List<Income> incomes;
  final String analysis;

  FinancialAnalysis({
    required this.expenses,
    required this.incomes,
    required this.analysis,
  });

  factory FinancialAnalysis.fromJson(Map<String, dynamic> json) {
    return FinancialAnalysis(
      expenses: (json['expenses'] as List).map((e) => Expense.fromJson(e)).toList(),
      incomes: (json['incomes'] as List).map((i) => Income.fromJson(i)).toList(),
      analysis: json['analysis'],
    );
  }
}

class Expense {
  final double amount;
  final String category;
  final String description;
  final String date;

  Expense({
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      amount: json['amount'],
      category: json['category'],
      description: json['description'],
      date: json['date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
    };
  }
}

class Income {
  final double amount;
  final String source;
  final String date;

  Income({
    required this.amount,
    required this.source,
    required this.date,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      amount: json['amount'],
      source: json['source'],
      date: json['date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'source': source,
      'date': date,
    };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ai Bitch',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),
      ),
      home: ChatScreen(prefs: prefs),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const ChatScreen({Key? key, required this.prefs}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class WebSocketManager {
  WebSocketChannel? _channel;
  Timer? _reconnectionTimer;
  final String _wsUrl;
  final Function(dynamic) _onMessage;
  final Function(dynamic) _onError;
  final Function() _onReconnect;

  WebSocketManager(this._wsUrl, this._onMessage, this._onError, this._onReconnect);

  void connect() {
    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          print('WebSocket error: $error');
          _onError(error);
          _scheduleReconnection();
        },
        onDone: () {
          print('WebSocket connection closed');
          _scheduleReconnection();
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _scheduleReconnection();
    }
  }

  void _scheduleReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(Duration(seconds: 5), () {
      print('Attempting to reconnect...');
      connect();
      _onReconnect();
    });
  }

  void send(String message) {
    _channel?.sink.add(message);
  }

  void dispose() {
    _channel?.sink.close();
    _reconnectionTimer?.cancel();
  }
}


class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  late String _conversationId;
  final FocusNode _focusNode = FocusNode();
  WebSocketChannel? _channel;
  Timer? _reconnectionTimer;
  late WebSocketManager _wsManager;

  String get apiUrl {
    return 'http://192.168.1.78:8000/api/chat';
  }

  String get searchApiUrl {
    return 'http://192.168.1.78:8000/api/search';
  }

  String get documentAnalysisUrl {
    return 'http://192.168.1.78:8000/api/analyze-document';
  }

  String get expenseApiUrl {
    return 'http://192.168.1.78:8000/api/expense';
  }

  String get incomeApiUrl {
    return 'http://192.168.1.78:8000/api/income';
  }

  String get expensesApiUrl {
    return 'http://192.168.1.78:8000/api/expenses';
  }

  String get calendarApiUrl {
    return 'http://192.168.1.78:8000/api/calendar';
  }

  String get financialApiUrl {
    return 'http://192.168.1.78:8000/api/financial-analysis';
  }

  String get capitalOneLoginApiUrl {
    return 'http://192.168.1.78:8000/api/login-capital-one';
  }

  // Remove WebSocket-related code
  // late WebSocketManager _wsManager;

  @override
  void initState() {
    super.initState();
    _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
    _sendInitialMessage();
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    setState(() {
      _messages.insert(0, ChatMessage(
        text: text,
        isUser: true,
      ));
      _isLoading = true;
    });

    if (text.toLowerCase().startsWith('image search ')) {
      final query = text.substring('image search '.length);
      _performImageSearch(query);
    } else if (text.toLowerCase().startsWith('search for ')) {
      final query = text.substring('search for '.length);
      _performWebSearch(query);
    } else {
      _sendMessage(text);
    }
  }

  // Update the sendMessage method to handle the response properly
  Future<void> _sendMessage(String text) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': text,
          'conversation_id': _conversationId,
          'client_id': _conversationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Add a type field if it's missing
        if (data['message'] != null && !data.containsKey('type')) {
          data['type'] = 'chat';
        }

        _handleIncomingMessage(data);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: Unable to send message. Please try again.',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  void _handleIncomingMessage(dynamic message) {
    print('Received message: $message'); // Debug print

    // Handle both String and Map messages
    final data = message is String ? json.decode(message) : message;

    setState(() {
      if (data['type'] == 'chat' || data['message'] != null) {
        // Handle both old and new message formats
        final messageText = data['message'] ?? data['content'];
        _messages.insert(0, ChatMessage(
          text: messageText,
          isUser: false,
        ));
      } else if (data['type'] == 'search') {
        if (data['search_type'] == 'image') {
          final imageResults = (data['results'] as List)
              .map((item) => ImageSearchResult.fromJson(item))
              .toList();
          _messages.insert(0, ImageSearchResultMessage(results: imageResults));
        } else if (data['search_type'] == 'web') {
          final webResults = (data['results'] as List)
              .map((item) => WebSearchResult.fromJson(item))
              .toList();
          _messages.insert(0, WebSearchResultMessage(results: webResults));
        }
      } else {
        // Fallback case for unhandled message types
        print('Unknown message format: $data');
        _messages.insert(0, ChatMessage(
          text: data['message'] ?? 'Received response in unknown format',
          isUser: false,
        ));
      }
      _isLoading = false;
    });
  }

  Future<void> _performImageSearch(String query) async {
    try {
      final response = await http.get(Uri.parse('$searchApiUrl?q=$query&type=image'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _handleIncomingMessage({
          'type': 'search',
          'search_type': 'image',
          'results': data['images'],
        });
      } else {
        throw Exception('Failed to perform image search');
      }
    } catch (e) {
      print('Error performing image search: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: Unable to perform image search. Please try again.',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  Future<void> _performWebSearch(String query) async {
    try {
      final response = await http.get(Uri.parse('$searchApiUrl?q=$query&type=web'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _handleIncomingMessage({
          'type': 'search',
          'search_type': 'web',
          'results': data['results'],
        });
      } else {
        throw Exception('Failed to perform web search');
      }
    } catch (e) {
      print('Error performing web search: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: Unable to perform web search. Please try again.',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  void _handleWebSocketError(dynamic error) {
    setState(() {
      _messages.insert(0, ChatMessage(
        text: "Connection error. Attempting to reconnect...",
        isUser: false,
      ));
    });
  }

  void _handleWebSocketReconnect() {
    setState(() {
      _messages.insert(0, ChatMessage(
        text: "Reconnected to server.",
        isUser: false,
      ));
    });
  }

  void _connectWebSocket() {
    final wsUrl = 'ws://192.168.1.90:8000/ws/$_conversationId';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (error) {
          print('WebSocket error: $error');
          _scheduleReconnection();
        },
        onDone: () {
          print('WebSocket connection closed');
          _scheduleReconnection();
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _scheduleReconnection();
    }
  }

  void _scheduleReconnection() {
    Timer(Duration(seconds: 5), _connectWebSocket);
  }

  Future<void> _loginToCapitalOne() async {
    final username = await _showInputDialog('Enter Capital One Username');
    if (username == null) return;

    final password = await _showInputDialog('Enter Capital One Password');
    if (password == null) return;

    setState(() {
      _isLoading = true;
    });

    final success = await loginToCapitalOne(username, password);

    setState(() {
      _isLoading = false;
      _messages.insert(0, ChatMessage(
        text: success ? 'Successfully logged into Capital One!' : 'Failed to log into Capital One. Please try again.',
        isUser: false,
      ));
    });
  }

  Future<bool> loginToCapitalOne(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(capitalOneLoginApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Login successful: ${responseData['message']}');
        return true;
      } else {
        print('Login failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  void _loadPreviousConversation() {
    final messagesJson = widget.prefs.getString('messages') ?? '[]';
    final List<dynamic> messagesList = jsonDecode(messagesJson);
    setState(() {
      _messages.clear();
      _messages.addAll(messagesList.map((m) => Message.fromJson(m)).toList());
    });
  }

  void _saveConversation() {
    widget.prefs.setString('conversation_id', _conversationId);
    widget.prefs.setString('messages', jsonEncode(_messages.map((m) => m.toJson()).toList()));
  }

  void _sendInitialMessage() {
    setState(() {
      _messages.insert(0, ChatMessage(
        text: "Hello! I'm your Ai Bitch. How may I please you today?",
        isUser: false,
      ));
    });
    _saveConversation();
  }

  // Add these methods to your _ChatScreenState class

  Future<void> _uploadAndAnalyzeSourceCode() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['py', 'js', 'java', 'cpp', 'cs', 'go', 'rb', 'php', 'swift', 'kt'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes != null) {
        String code = utf8.decode(fileBytes);
        await _sendCodeForRefactoring(code, file.name);
      } else {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: 'Error: Unable to read file content.',
            isUser: false,
          ));
        });
      }
    }
  }

  Future<void> _pasteAndAnalyzeSourceCode() async {
    final code = await _showCodeInputDialog();
    if (code != null && code.isNotEmpty) {
      await _sendCodeForRefactoring(code, 'Pasted Code');
    }
  }

  Future<void> _sendCodeForRefactoring(String code, String filename) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final refactoringInstructions = await _showRefactoringInstructionsDialog();
      if (refactoringInstructions == null || refactoringInstructions.isEmpty) {
        throw Exception('Refactoring instructions are required');
      }

      final prompt = '''Please refactor the following code based on these instructions:

Instructions: $refactoringInstructions

Here's the code to refactor:

```
$code
```

Please provide:
1. The refactored code
2. A summary of changes made
3. Any potential improvements or suggestions for further refactoring
''';

      _sendMessage(prompt);

      setState(() {
        _messages.insert(0, ChatMessage(
          text: "Source code from $filename has been sent for refactoring. The results will be in the upcoming message.",
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error sending code for refactoring: ${e.toString()}',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _showRefactoringInstructionsDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String instructions = '';
        return AlertDialog(
          title: Text('Enter Refactoring Instructions'),
          content: TextField(
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(hintText: 'E.g., Improve performance, apply SOLID principles, etc.'),
            onChanged: (value) {
              instructions = value;
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Refactor'),
              onPressed: () => Navigator.of(context).pop(instructions),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showCodeInputDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String code = '';
        return AlertDialog(
          title: Text('Paste Your Code'),
          content: TextField(
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(hintText: 'Paste your code here'),
            onChanged: (value) {
              code = value;
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Analyze'),
              onPressed: () => Navigator.of(context).pop(code),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getFinancialAnalysis() async {
    try {
      final expensesResponse = await http.get(Uri.parse(expensesApiUrl));
      final incomesResponse = await http.get(Uri.parse(incomeApiUrl));

      if (expensesResponse.statusCode == 200 && incomesResponse.statusCode == 200) {
        final expenses = (json.decode(expensesResponse.body) as List)
            .map((e) => Expense.fromJson(e))
            .toList();
        final incomes = (json.decode(incomesResponse.body) as List)
            .map((i) => Income.fromJson(i))
            .toList();

        final analysisResponse = await http.post(
          Uri.parse('$financialApiUrl'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'expenses': expenses.map((e) => e.toJson()).toList(),
            'incomes': incomes.map((i) => i.toJson()).toList(),
          }),
        );

        if (analysisResponse.statusCode == 200) {
          final analysis = FinancialAnalysis.fromJson(json.decode(analysisResponse.body));
          setState(() {
            _messages.insert(0, FinancialAnalysisMessage(analysis: analysis));
          });
        } else {
          throw Exception('Failed to get financial analysis');
        }
      } else {
        throw Exception('Failed to retrieve expenses or income');
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error getting financial analysis: $e',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _addExpense() async {
    final amount = await _showExpenseDialog('Enter Expense Amount');
    if (amount == null) return;

    final category = await _showExpenseDialog('Enter Expense Category');
    if (category == null) return;

    final description = await _showExpenseDialog('Enter Expense Description');
    if (description == null) return;

    final date = DateTime.now().toIso8601String();

    try {
      final response = await http.post(
        Uri.parse(expenseApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amount,
          'category': category,
          'description': description,
          'date': date,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: 'Expense added successfully!',
            isUser: false,
          ));
        });
      } else {
        throw Exception('Failed to add expense');
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error adding expense: $e',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _addIncome() async {
    final amount = await _showExpenseDialog('Enter Income Amount');
    if (amount == null) return;

    final source = await _showExpenseDialog('Enter Income Source');
    if (source == null) return;

    final date = DateTime.now().toIso8601String();

    try {
      final response = await http.post(
        Uri.parse(incomeApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amount,
          'source': source,
          'date': date,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: 'Income added successfully!',
            isUser: false,
          ));
        });
      } else {
        throw Exception('Failed to add income');
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error adding income: $e',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _getExpenses() async {
    try {
      final response = await http.get(Uri.parse(expensesApiUrl));
      if (response.statusCode == 200) {
        final expenses = json.decode(response.body) as List<dynamic>;
        setState(() {
          _messages.insert(0, ChatMessage(
            text: 'Expenses:\n${expenses.map((e) => '- \$${e['amount']} (${e['category']})').join('\n')}',
            isUser: false,
          ));
        });
      } else {
        throw Exception('Failed to retrieve expenses');
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error retrieving expenses: $e',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _getIncome() async {
    try {
      final response = await http.get(Uri.parse(incomeApiUrl));
      if (response.statusCode == 200) {
        final income = json.decode(response.body) as List<dynamic>;
        setState(() {
          _messages.insert(0, ChatMessage(
            text: 'Income:\n${income.map((i) => '- \$${i['amount']} (${i['source']})').join('\n')}',
            isUser: false,
          ));
        });
      } else {
        throw Exception('Failed to retrieve income');
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error retrieving income: $e',
          isUser: false,
        ));
      });
    }
  }

  Future<String?> _showExpenseDialog(String title) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController _controller = TextEditingController();
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: title),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(_controller.text),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: InputDecoration(
                  hintText: 'Send a message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wsManager.dispose();
    super.dispose();
  }

  Future<void> _uploadAndAnalyzeDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'py', 'js', 'java', 'cpp', 'cs', 'go', 'rb', 'php', 'swift', 'kt'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        _isLoading = true;
      });

      try {
        var request = http.MultipartRequest('POST', Uri.parse(documentAnalysisUrl));
        request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        var response = await request.send();

        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final analysisResult = DocumentAnalysisResult.fromJson(json.decode(respStr));

          setState(() {
            _messages.insert(0, DocumentAnalysisMessage(result: analysisResult));
          });
        } else {
          throw Exception('Failed to analyze document');
        }
      } catch (e) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: 'Error analyzing document: ${e.toString()}',
            isUser: false,
          ));
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Update the _performSearch method in the ChatScreen class
  Future<void> _performSearch(String query) async {
    try {
      final response = await http.get(Uri.parse('$searchApiUrl?q=$query&type=image'));

      if (response.statusCode == 200) {
        final searchData = json.decode(response.body);

        if (searchData['images'] != null) {
          final imageResults = (searchData['images'] as List)
              .map((item) => ImageSearchResult.fromJson(item))
              .toList();

          setState(() {
            _messages.insert(0, ImageSearchResultMessage(results: imageResults));
          });
        } else {
          setState(() {
            _messages.insert(0, ChatMessage(
              text: 'No image results found.',
              isUser: false,
            ));
          });
        }
      } else {
        throw Exception('Failed to load search results');
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error performing search: ${e.toString()}',
          isUser: false,
        ));
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
    });
    _saveConversation();
    _sendInitialMessage();
  }

  Future<void> _addCalendarEvent() async {
    final eventName = await _showInputDialog('Enter Event Name');
    if (eventName == null) return;

    final eventDate = await _showDatePicker(context);
    if (eventDate == null) return;

    final eventTime = await _showTimePicker(context);
    if (eventTime == null) return;

    final description = await _showInputDialog('Enter Event Description');
    if (description == null) return;

    final duration = await _showInputDialog('Enter Event Duration (e.g., 1 hour, 30 minutes)');
    if (duration == null) return;

    try {
      final response = await http.post(
        Uri.parse('$calendarApiUrl'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': eventName,
          'date': eventDate.toIso8601String().split('T')[0],  // YYYY-MM-DD
          'time': eventTime.format(context),
          'description': description,
          'duration': duration,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _messages.insert(0, ChatMessage(
            text: responseData['message'],
            isUser: false,
          ));
        });
      } else {
        final errorMessage = json.decode(response.body)['detail'];
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error adding calendar event: $e',
          isUser: false,
        ));
      });
    }
  }

  Future<String?> _showInputDialog(String title) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController _controller = TextEditingController();
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: title),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(_controller.text),
            ),
          ],
        );
      },
    );
  }

  Future<DateTime?> _showDatePicker(BuildContext context) {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
  }

  Future<TimeOfDay?> _showTimePicker(BuildContext context) {
    return showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ai Bitch', style: GoogleFonts.pacifico(fontSize: 24)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple, Colors.blue],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.event),
            onPressed: _addCalendarEvent,
            tooltip: 'Add Calendar Event',
          ),
          IconButton(
            icon: Icon(Icons.attach_money),
            onPressed: _addExpense,
            tooltip: 'Add Expense',
          ),
          IconButton(
            icon: Icon(Icons.monetization_on),
            onPressed: _addIncome,
            tooltip: 'Add Income',
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: _getExpenses,
            tooltip: 'View Expenses',
          ),
          IconButton(
            icon: Icon(Icons.money),
            onPressed: _getIncome,
            tooltip: 'View Income',
          ),
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: _getFinancialAnalysis,
            tooltip: 'Get Financial Analysis',
          ),
          IconButton(
            icon: Icon(Icons.login),
            onPressed: _loginToCapitalOne,
            tooltip: 'Login to Capital One',
          ),
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _uploadAndAnalyzeDocument,
            tooltip: 'Analyze Document',
          ),
          IconButton(
            icon: Icon(Icons.movie),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MovieBrowser()),
              );
            },
            tooltip: 'Browse Movies',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  constraints.maxWidth < 600
                      ? 'assets/the-girls.jpg'
                      : 'assets/the-girls2.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.7),
                    Colors.purple.withOpacity(0.3),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(8.0),
                      reverse: true,
                      itemBuilder: (_, int index) => _messages[index],
                      itemCount: _messages.length,
                    ),
                  ),
                  Divider(height: 1.0),
                  Container(
                    decoration: BoxDecoration(color: Theme.of(context).cardColor),
                    child: _buildTextComposer(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Update the _buildFilePickerButton method
  Widget _buildFilePickerButton() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _uploadAndAnalyzeDocument,
            icon: Icon(Icons.attach_file),
            label: Text('Analyze Document'),
          ),
          ElevatedButton.icon(
            onPressed: _uploadAndAnalyzeSourceCode,
            icon: Icon(Icons.code),
            label: Text('Upload Code'),
          ),
          ElevatedButton.icon(
            onPressed: _pasteAndAnalyzeSourceCode,
            icon: Icon(Icons.paste),
            label: Text('Paste Code'),
          ),
        ],
      ),
    );
  }
}

class ImageSearchResultMessage extends Message {
  final List<ImageSearchResult> results;

  ImageSearchResultMessage({required this.results});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Image Search Results:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 12.0),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: InkWell(
                    onTap: () => _launchURL(result.contextLink ?? result.link),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
                            child: Image.network(
                              result.thumbnailLink,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4.0),
                              Text(
                                result.displayLink,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.0, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'imageSearch',
      'results': results.map((r) => {
        'title': r.title,
        'link': r.link,
        'thumbnailLink': r.thumbnailLink,
        'displayLink': r.displayLink,
        'mime': r.mime,
        'fileFormat': r.fileFormat,
        'contextLink': r.contextLink,
      }).toList(),
    };
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }
}

// Update the Message.fromJson factory method
abstract class Message extends StatelessWidget {
  const Message({Key? key}) : super(key: key);

  factory Message.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'chat':
        return ChatMessage.fromJson(json);
      case 'searchInfo':
        return SearchInfoMessage(resultCount: json['resultCount']);
      case 'imageSearch':
        return ImageSearchResultMessage(
          results: (json['results'] as List)
              .map((item) => ImageSearchResult.fromJson(item))
              .toList(),
        );
      case 'webSearch':
        return WebSearchResultMessage(
          results: (json['results'] as List)
              .map((item) => WebSearchResult.fromJson(item))
              .toList(),
        );
      case 'sourceCodeAnalysis':
        return SourceCodeAnalysisMessage(
          filename: json['filename'],
          language: json['language'],
          summary: json['summary'],
          complexity: json['complexity'],
          suggestions: List<String>.from(json['suggestions']),
          securityConcerns: [],
          code: json['code'],
        );
      case 'sourceCodeRefactoring':
        return SourceCodeRefactoringMessage(
          originalCode: json['originalCode'],
          refactoredCode: json['refactoredCode'],
          summary: json['summary'],
          suggestions: List<String>.from(json['suggestions']),
        );
      case 'financialAnalysis':
        return FinancialAnalysisMessage(
          analysis: FinancialAnalysis.fromJson(json),
        );
      default:
        throw ArgumentError('Unknown message type: ${json['type']}');
    }
  }

  Map<String, dynamic> toJson();
}

class ChatMessage extends Message {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'chat',
      'text': text,
      'isUser': isUser,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                child: Text('Ai'),
                backgroundColor: Colors.purple.withOpacity(0.8),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blue.withOpacity(0.8)
                    : Colors.purple.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 20.0 : 0.0),
                  topRight: Radius.circular(isUser ? 0.0 : 20.0),
                  bottomLeft: Radius.circular(20.0),
                  bottomRight: Radius.circular(20.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'Daddy' : 'Ai Whore',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  _buildMessageContent(context),
                ],
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 16.0),
              child: CircleAvatar(
                child: Text('D'),
                backgroundColor: Colors.blue.withOpacity(0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (isUser) {
      return Text(
        text,
        style: GoogleFonts.roboto(
          textStyle: TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    } else {
      return MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: GoogleFonts.roboto(
            textStyle: TextStyle(fontSize: 16, color: Colors.white),
          ),
          code: GoogleFonts.firaCode(
            textStyle: TextStyle(
              backgroundColor: Colors.black.withOpacity(0.3),
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
        builders: {
          'code': CodeBlockBuilder(context),
        },
      );
    }
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CodeBlockBuilder(this.context);

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String code = element.textContent;
    String language = element.attributes['class']?.split('-').last ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (language.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
              ),
              child: Text(
                language,
                style: GoogleFonts.firaCode(
                  textStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  code,
                  style: GoogleFonts.firaCode(
                    textStyle: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 8.0,
                right: 8.0,
                child: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Code copied to clipboard'),
                        backgroundColor: Colors.purple.withOpacity(0.8),
                      ),
                    );
                  },
                  tooltip: 'Copy code',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Update the WebSearchResultMessage class
class WebSearchResultMessage extends Message {
  final List<WebSearchResult> results;

  WebSearchResultMessage({required this.results});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Web Search Results:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 12.0),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListTile(
                    title: Text(
                      result.title,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          result.link,
                          style: TextStyle(color: Colors.blue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    onTap: () => _launchURL(result.link),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'webSearch',
      'results': results.map((r) => {
        'title': r.title,
        'link': r.link,
        'snippet': r.snippet,
      }).toList(),
    };
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }
}

class SearchInfoMessage extends Message {
  final int resultCount;

  SearchInfoMessage({required this.resultCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      padding: EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        'Found $resultCount results',
        // style: Theme.of(context).textTheme.subtitle2,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'searchInfo',
      'resultCount': resultCount,
    };
  }
}

class SearchResultMessage extends Message {
  final Map<String, dynamic> result;

  SearchResultMessage({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        title: Text(
          result['title'] ?? 'No title available',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result['snippet'] ?? 'No snippet available'),
            SizedBox(height: 4),
            Text(
              result['link'] ?? 'No link available',
              style: TextStyle(color: Colors.blue),
            ),
          ],
        ),
        onTap: () => _launchURL(result['link']),
      ),
    );
  }

  void _launchURL(String? url) async {
    if (url != null && await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'searchResult',
      'result': result,
    };
  }
}

class SourceCodeRefactoringMessage extends Message {
  final String originalCode;
  final String refactoredCode;
  final String summary;
  final List<String> suggestions;

  SourceCodeRefactoringMessage({
    required this.originalCode,
    required this.refactoredCode,
    required this.summary,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Source Code Refactoring Result:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              'Summary of Changes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(summary),
            SizedBox(height: 8.0),
            Text(
              'Refactored Code:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(refactoredCode),
            ),
            SizedBox(height: 8.0),
            Text(
              'Suggestions for Further Improvement:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...suggestions.map((s) => ListTile(
              title: Text('• $s'),
            )),
            SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: originalCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Original code copied to clipboard')),
                    );
                  },
                  child: Text('Copy Original Code'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: refactoredCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Refactored code copied to clipboard')),
                    );
                  },
                  child: Text('Copy Refactored Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'sourceCodeRefactoring',
      'originalCode': originalCode,
      'refactoredCode': refactoredCode,
      'summary': summary,
      'suggestions': suggestions,
    };
  }
}

class ExcelDataGridSource extends DataGridSource {
  final List<List<dynamic>> excelData;

  ExcelDataGridSource(this.excelData) {
    buildDataGridRows();
  }

  List<DataGridRow> dataGridRows = [];

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(cells: row.getCells().map((dataGridCell) {
      return Container(
        alignment: Alignment.center,
        child: Text(dataGridCell.value.toString()),
      );
    }).toList());
  }


  @override
  List<DataGridRow> get rows => dataGridRows;

  void buildDataGridRows() {
    dataGridRows = excelData.map((row) {
      return DataGridRow(
        cells: row.map((cell) => DataGridCell(columnName: 'Column${row.indexOf(cell) + 1}', value: cell)).toList(),
      );
    }).toList();
  }
}

class SourceCodeAnalysisMessage extends Message {
  final String filename;
  final String language;
  final String summary;
  final String complexity;
  final List<String> suggestions;
  final List<String> securityConcerns; // Add this field to display security concerns
  final String code;

  SourceCodeAnalysisMessage({
    required this.filename,
    required this.language,
    required this.summary,
    required this.complexity,
    required this.suggestions,
    required this.securityConcerns, // Use this field to display security concerns
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              alignment: Alignment.centerLeft,
              child: Text(
                'Source Code Analysis: $filename',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                ),
              ),
            ),
            SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: Text('Language: $language'),
                ),
                Expanded(
                  child: Text('Complexity: $complexity'),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            Text(
              'Summary:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4.0),
            Text(summary),
            SizedBox(height: 8.0),
            Text(
              'Suggestions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...suggestions.map((s) => ListTile(
              title: Text('• $s'),
            )),
            SizedBox(height: 16.0),
            Text(
              'Security Concerns:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...securityConcerns.map((c) => ListTile(
              title: Text('• $c'),
            )),
            SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Code copied to clipboard')),
                );
              },
              child: Text('Copy Code'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'sourceCodeAnalysis',
      'filename': filename,
      'language': language,
      'summary': summary,
      'complexity': complexity,
      'suggestions': suggestions,
      'securityConcerns': securityConcerns, // Use this field to display security concerns
      'code': code,
    };
  }
}

class FinancialAnalysisMessage extends Message {
  final FinancialAnalysis analysis;

  FinancialAnalysisMessage({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Analysis:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 8.0),
            Text('Total Expenses: \$${_calculateTotalExpenses()}'),
            Text('Total Income: \$${_calculateTotalIncome()}'),
            SizedBox(height: 8.0),
            Text(
              'AI Analysis:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(analysis.analysis),
          ],
        ),
      ),
    );
  }

  double _calculateTotalExpenses() {
    return analysis.expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  double _calculateTotalIncome() {
    return analysis.incomes.fold(0, (sum, income) => sum + income.amount);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'financialAnalysis',
      'expenses': analysis.expenses.map((e) => e.toJson()).toList(),
      'incomes': analysis.incomes.map((i) => i.toJson()).toList(),
      'analysis': analysis.analysis,
    };
  }
}

class DocumentAnalysisMessage extends Message {
  final DocumentAnalysisResult result;

  DocumentAnalysisMessage({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Analysis Result:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 8.0),
            Text('Filename: ${result.filename}'),
            SizedBox(height: 12.0),
            Text(
              'Document Content:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            SizedBox(height: 4.0),
            _buildFinancialStatementContent(result.content),
            SizedBox(height: 12.0),
            Text(
              'Metadata:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            SizedBox(height: 4.0),
            _buildMetadataWidget(result.metadata),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialStatementContent(String content) {
    List<String> lines = content.split('\n');
    List<DataRow> rows = [];

    for (String line in lines) {
      if (line.trim().isEmpty) continue; // Skip empty lines

      List<String> parts = line.split(RegExp(r'\s{2,}')); // Split by 2 or more spaces

      // Ensure we have at least 2 parts (date and description)
      if (parts.length < 2) continue;

      // Pad the parts list to ensure we have at least 4 elements
      while (parts.length < 4) {
        parts.add('');
      }

      // If we have more than 4 parts, combine extra parts into the description
      if (parts.length > 4) {
        parts = [
          parts[0],
          parts.sublist(1, parts.length - 2).join(' '),
          parts[parts.length - 2],
          parts[parts.length - 1],
        ];
      }

      rows.add(DataRow(cells: [
        DataCell(Text(parts[0])),
        DataCell(Text(parts[1])),
        DataCell(Text(parts[2])),
        DataCell(Text(parts[3])),
      ]));
    }

    if (rows.isEmpty) {
      return Text('No valid data found in the document.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Balance')),
          ],
          rows: rows,
        ),
      ),
    );
  }
  Widget _buildMetadataWidget(DocumentMetadata metadata) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetadataItem('Number of Pages', metadata.numPages.toString()),
        _buildMetadataItem('Author', metadata.author),
        _buildMetadataItem('Creator', metadata.creator),
        _buildMetadataItem('Producer', metadata.producer),
        _buildMetadataItem('Subject', metadata.subject),
        _buildMetadataItem('Title', metadata.title),
        _buildMetadataItem('Creation Date', metadata.creationDate),
        _buildMetadataItem('Modification Date', metadata.modificationDate),
      ],
    );
  }

  Widget _buildMetadataItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.black),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildExcelPreview() {
    if (result.excelData == null || result.excelData!.isEmpty) {
      return Text('No Excel data available');
    }

    final dataGridSource = ExcelDataGridSource(result.excelData!);

    return Container(
      height: 200,
      child: SfDataGrid(
        source: dataGridSource,
        columnWidthMode: ColumnWidthMode.auto,
        columns: result.excelData![0].map((header) {
          return GridColumn(
            columnName: header.toString(),
            label: Container(
              alignment: Alignment.center,
              child: Text(header.toString()),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'documentAnalysis',
      'result': {
        'filename': result.filename,
        'content': result.content,
        'metadata': result.metadata,
        'excel_data': result.excelData,
      },
    };
  }
}

class MovieBrowser extends StatefulWidget {
  @override
  _MovieBrowserState createState() => _MovieBrowserState();
}

class _MovieBrowserState extends State<MovieBrowser> {
  String get baseUrl {
    return 'http://192.168.1.78:8000';
  }

  List<FileItem> _items = [];
  String _currentPath = "/";
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${baseUrl}/api/movies/list?path=${Uri.encodeComponent(path)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _items = data.map((item) => FileItem.fromJson(item)).toList();
          _currentPath = path;
        });
      } else {
        throw Exception('Failed to load directory');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading directory: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Browser'),
        leading: _currentPath != "/" ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final parentPath = path.dirname(_currentPath);
            _loadDirectory(parentPath);
          },
        ) : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        controller: _scrollController,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            leading: Icon(
              item.isDirectory ? Icons.folder : Icons.movie,
              color: item.isDirectory ? Colors.amber : Colors.blue,
            ),
            title: Text(item.name),
            subtitle: !item.isDirectory
                ? Text(_formatFileSize(item.size))
                : null,
            onTap: () {
              if (item.isDirectory) {
                _loadDirectory(item.path);
              } else {
                _playMovie(item);
              }
            },
          );
        },
      ),
    );
  }

  void _playMovie(FileItem movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoviePlayer(movie: movie),
      ),
    );
  }

  String _formatFileSize(int size) {
    final gb = size / (1024 * 1024 * 1024);
    if (gb >= 1) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    final mb = size / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = size / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }
}

class MoviePlayer extends StatefulWidget {
  final FileItem movie;

  MoviePlayer({required this.movie});

  @override
  _MoviePlayerState createState() => _MoviePlayerState();
}

class _MoviePlayerState extends State<MoviePlayer> {
  String get baseUrl {
    return 'http://192.168.1.78:8000';
  }

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  String _constructMovieUrl() {
    final shareName = Uri.encodeComponent(widget.movie.share_name);
    final moviePath = Uri.encodeComponent(widget.movie.path.replaceAll('\\', '/').trim());
    final url = '${baseUrl}/api/movies/stream/$shareName/$moviePath';
    debugPrint('Constructed URL: $url');
    return url;
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final movieUrl = _constructMovieUrl();

      if (kIsWeb) {
        _videoPlayerController = VideoPlayerController.network(
          movieUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(movieUrl),
          httpHeaders: {
            'Accept-Ranges': 'bytes',
          },
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      // Wait for the controller to initialize
      await _videoPlayerController!.initialize();

      // Calculate aspect ratio with a fallback
      double aspectRatio = _videoPlayerController!.value.aspectRatio;
      if (aspectRatio.isNaN || aspectRatio <= 0) {
        aspectRatio = 16 / 9;
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Error playing video: $errorMessage',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retryInitialization,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            if (!kIsWeb)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton.icon(
                  onPressed: _openInDefaultPlayer,
                  icon: Icon(Icons.open_in_new),
                  label: Text('Open in Default Player'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openInDefaultPlayer() async {
    if (kIsWeb) return;

    final url = _constructMovieUrl();
    try {
      final uri = Uri.parse(url);
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', uri.toString()]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [uri.toString()]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [uri.toString()]);
      }
    } catch (e) {
      debugPrint('Error opening default player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open default player')),
        );
      }
    }
  }

  Future<void> _retryInitialization() async {
    await _disposeControllers();
    await _initializePlayer();
  }

  Future<void> _disposeControllers() async {
    _chewieController?.dispose();
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.movie.name),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _retryInitialization,
            tooltip: 'Reload video',
          ),
          if (!kIsWeb)
            IconButton(
              icon: Icon(Icons.open_in_new),
              onPressed: _openInDefaultPlayer,
              tooltip: 'Open in default player',
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: _buildPlayer(),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!);
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return Center(
      child: Text(
        'Unable to load video player',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }
}