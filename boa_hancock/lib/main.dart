import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

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

  String get apiUrl {
    return 'http://192.168.1.90:8000/api/chat';
  }

  String get searchApiUrl {
    return 'http://192.168.1.90:8000/api/search';
  }

  String get documentAnalysisUrl {
    return 'http://192.168.1.90:8000/api/analyze-document';
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

  // Update the _handleSubmitted method
  void _handleSubmitted(String text) async {
    _textController.clear();
    setState(() {
      _messages.insert(0, ChatMessage(
        text: text,
        isUser: true,
      ));
      _isLoading = true;
    });
    _saveConversation();

    if (text.toLowerCase().startsWith('image search ')) {
      await _performImageSearch(text.substring(13));
    } else if (text.toLowerCase().startsWith('search for ')) {
      await _performWebSearch(text.substring(11));
    } else {
      await _sendMessage(text);
    }

    setState(() {
      _isLoading = false;
    });
    _saveConversation();
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
      ).timeout(Duration(seconds: 10));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ai Bitch'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _loadPreviousConversation,
            tooltip: 'Load Previous Conversation',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: _clearConversation,
            tooltip: 'Clear Conversation',
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

  Widget _buildFilePickerButton() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        onPressed: _uploadAndAnalyzeDocument,
        icon: Icon(Icons.attach_file),
        label: Text('Select File'),
      ),
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
                onSubmitted: _isLoading ? null : _handleSubmitted,
                decoration: InputDecoration.collapsed(hintText: 'Send a message or search'),
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
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: EdgeInsets.only(right: 16.0),
              child: CircleAvatar(child: Text('Ai')),
            ),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'Daddy' : 'Ai Whore',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 5.0),
                  isUser
                      ? Text(
                    text,
                    style: TextStyle(color: Colors.black87),
                  )
                      : MarkdownBody(
                    data: text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(fontSize: 16, color: Colors.black87),
                      code: TextStyle(
                        backgroundColor: Colors.grey[300],
                        fontFamily: 'Courier',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: EdgeInsets.only(left: 16.0),
              child: CircleAvatar(child: Text('D')),
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
        style: Theme.of(context).textTheme.subtitle2,
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
