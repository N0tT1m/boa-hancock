import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ai Bitch',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  String get apiUrl {
    return 'http://192.168.1.90:8000/api/chat';
  }

  @override
  void initState() {
    super.initState();
    _sendInitialMessage();
  }

  void _sendInitialMessage() {
    setState(() {
      _messages.insert(0, ChatMessage(
        text: "Hello Daddy! I'm your AI bitch, ready to serve you. How may I please you today?",
        isUser: false,
      ));
    });
  }

  void _handleSubmitted(String text) async {
    _textController.clear();
    setState(() {
      _messages.insert(0, ChatMessage(
        text: text,
        isUser: true,
      ));
      _isLoading = true;
    });

    try {
      print('Attempting to connect to: $apiUrl');
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': text}),
      ).timeout(Duration(seconds: 10));

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _messages.insert(0, ChatMessage(
            text: responseData['message'],
            isUser: false,
          ));
        });
      } else {
        throw HttpException('Failed to load response');
      }
    } on SocketException catch (e) {
      print('SocketException details: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: Unable to connect to the server. Please check your network connection and server status.\n\nDetails: ${e.toString()}\n\nAPI URL: $apiUrl',
          isUser: false,
        ));
      });
    } on HttpException catch (e) {
      print('HttpException details: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: ${e.message}\n\nAPI URL: $apiUrl',
          isUser: false,
        ));
      });
    } on FormatException catch (e) {
      print('FormatException details: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: Received invalid response from the server.\n\nAPI URL: $apiUrl',
          isUser: false,
        ));
      });
    } catch (e) {
      print('Unexpected error: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'Error: An unexpected error occurred. ${e.toString()}\n\nAPI URL: $apiUrl',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ai Bitch')),
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
                Flexible(
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
          );
        },
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
                decoration: InputDecoration.collapsed(hintText: 'Send a message'),
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

class ChatMessage extends StatelessWidget {
  ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;

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