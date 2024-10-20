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

// Update DocumentAnalysisResult to handle Excel data
class DocumentAnalysisResult {
  final String filename;
  final String content;
  final Map<String, dynamic> metadata;
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
      metadata: json['metadata'] ?? {},
      excelData: json['excel_data'] != null
          ? List<List<dynamic>>.from(json['excel_data']
          .map((row) => List<dynamic>.from(row)))
          : null,
    );
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

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  late String _conversationId;
  final FocusNode _focusNode = FocusNode();

  String get apiUrl {
    return 'http://192.168.1.87:8000/api/chat';
  }

  String get searchApiUrl {
    return 'http://192.168.1.87:8000/api/search';
  }

  String get documentAnalysisUrl {
    return 'http://192.168.1.87:8000/api/analyze-document';
  }

  String get expenseApiUrl {
    return 'http://192.168.1.87:8000/api/expense';
  }

  String get incomeApiUrl {
    return 'http://192.168.1.87:8000/api/income';
  }

  String get expensesApiUrl {
    return 'http://192.168.1.87:8000/api/expenses';
  }

  String get calendarApiUrl {
    return 'http://192.168.1.87:8000/api/calendar';
  }

  @override
  void initState() {
    super.initState();
    _conversationId = widget.prefs.getString('conversation_id') ?? DateTime.now().millisecondsSinceEpoch.toString();
    _sendInitialMessage();
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
        await _analyzeSourceCode(code, file.name);
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
      await _analyzeSourceCode(code, 'Pasted Code');
    }
  }

  Future<void> _analyzeSourceCode(String code, String filename) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String prompt = '''Analyze the following source code and provide:
1. The programming language
2. A brief summary of what the code does
3. An assessment of its complexity (Low, Medium, or High)
4. 2-3 suggestions for improvement or best practices
5. Any potential security concerns

Here's the code:

```
$code
```

Please format your response as follows:
Language: [language name]
Summary: [brief summary]
Complexity: [Low/Medium/High]
Suggestions:
- [suggestion 1]
- [suggestion 2]
- [suggestion 3 (if applicable)]
Security Concerns: [list any security concerns or "None identified" if none]''';

      await _sendMessage(prompt);

      setState(() {
        _messages.insert(0, ChatMessage(
          text: "Source code from $filename has been analyzed. The results are in the above message.",
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error analyzing source code: ${e.toString()}',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                focusNode: _focusNode,
                onSubmitted: _isLoading ? null : _handleSubmitted,
                decoration: InputDecoration.collapsed(
                  hintText: 'Send a message or search',
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: _isLoading
                    ? null
                    : () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    _focusNode.requestFocus();
    setState(() {
      _messages.insert(0, ChatMessage(
        text: text,
        isUser: true,
      ));
      _isLoading = true;
    });
    _saveConversation();

    // Process the submitted text
    if (text.toLowerCase().startsWith('image search ')) {
      _performImageSearch(text.substring(13));
    } else if (text.toLowerCase().startsWith('search for ')) {
      _performWebSearch(text.substring(11));
    } else {
      _sendMessage(text);
    }
  }

  Future<void> _uploadAndAnalyzeDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv'],
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
  Future<void> _performImageSearch(String query) async {
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

  // Update the _performWebSearch method
  Future<void> _performWebSearch(String query) async {
    try {
      final response = await http.get(Uri.parse('$searchApiUrl?q=$query&type=web'));

      if (response.statusCode == 200) {
        final searchData = json.decode(response.body);

        if (searchData['results'] != null) {
          final webResults = (searchData['results'] as List)
              .map((item) => WebSearchResult.fromJson(item))
              .toList();

          setState(() {
            _messages.insert(0, WebSearchResultMessage(results: webResults));
          });
        } else {
          setState(() {
            _messages.insert(0, ChatMessage(
              text: 'No web results found.',
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
          text: 'Error performing web search: ${e.toString()}',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': text,
          'conversation_id': _conversationId
        }),
      ).timeout(Duration(seconds: 3000));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _messages.insert(0, ChatMessage(
            text: responseData['message'],
            isUser: false,
          ));
          _conversationId = responseData['metadata']['conversation_id'];
        });
      } else {
        throw Exception('Failed to load response');
      }
    } catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: Unable to get response. Please try again.',
          isUser: false,
        ));
      });
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
        title: Text('Ai Bitch'),
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
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(8.0),
                    reverse: true,
                    itemBuilder: (_, int index) {
                      if (_messages[index] is ImageSearchResultMessage) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              width: constraints.maxWidth,
                              child: _messages[index],
                            );
                          },
                        );
                      }
                      return _messages[index];
                    },
                    itemCount: _messages.length,
                  ),
                ),
                Divider(height: 1.0),
                Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardColor),
                  child: Column(
                    children: [
                      _buildFilePickerButton(),
                      _buildTextComposer(),
                    ],
                  ),
                ),
              ],
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
          code: json['code'],
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
      text: json['text'],
      isUser: json['isUser'],
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
              child: const CircleAvatar(child: Text('Ai')),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'Daddy' : 'Ai Whore',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
              child: const CircleAvatar(child: Text('D')),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (isUser) {
      return Text(
        text,
        style: const TextStyle(color: Colors.black87),
      );
    } else {
      return MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 16, color: Colors.black87),
          code: TextStyle(
            backgroundColor: Colors.grey[300],
            fontFamily: 'Courier',
            fontSize: 14,
            color: Colors.black87,
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (language.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
              ),
              child: Text(
                language,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                  ),
                ),
              ),
              Positioned(
                top: 8.0,
                right: 8.0,
                child: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard')),
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

class DocumentAnalysisMessage extends Message {
  final DocumentAnalysisResult result;

  DocumentAnalysisMessage({required this.result});

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
              'Document Analysis Result:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 8.0),
            Text('Filename: ${result.filename}'),
            SizedBox(height: 4.0),
            if (result.excelData == null)
              Text('Content Preview: ${result.content.substring(0, min(100, result.content.length))}...')
            else
              _buildExcelPreview(),
            SizedBox(height: 4.0),
            Text('Metadata:'),
            ...result.metadata.entries.map((entry) => Text('  ${entry.key}: ${entry.value}')),
          ],
        ),
      ),
    );
  }

  Widget _buildExcelPreview() {
    if (result.excelData == null || result.excelData!.isEmpty) {
      return Text('No Excel data available');
    }

    // Create a DataGridSource from the Excel data
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
  final String code;

  SourceCodeAnalysisMessage({
    required this.filename,
    required this.language,
    required this.summary,
    required this.complexity,
    required this.suggestions,
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
            Text(
              'Source Code Analysis: $filename',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
            SizedBox(height: 8.0),
            Text('Language: $language'),
            Text('Complexity: $complexity'),
            SizedBox(height: 8.0),
            Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(summary),
            SizedBox(height: 8.0),
            Text('Suggestions:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...suggestions.map((s) => Text('• $s')),
            SizedBox(height: 8.0),
            Text('Code:', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  code,
                  style: TextStyle(fontFamily: 'Courier'),
                ),
              ),
            ),
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
      'code': code,
    };
  }
}