import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:animated_text_kit/animated_text_kit.dart';

class Chat extends StatefulWidget {
  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _fadeController;

  static const String API_URL = "https://api.together.xyz/v1/chat/completions";
  static const String API_KEY = "4db152889da5afebdba262f90e4cdcf12976ee8b48d9135c2bb86ef9b0d12bdd";

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadInitialMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadInitialMessage() {
    _addMessage(
      "Hello! I'm your RAX Care AI companion. I'm here to support you on your recovery journey. How are you feeling today?",
      false,
    );
  }

  Future<String> _fetchAIResponse(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(API_URL),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $API_KEY",
        },
        body: json.encode({
          "model": "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO",
          "messages": [
            {
              "role": "system",
              "content": """
                You are an empathetic AI counselor specialized in addiction recovery. Your responses should be:
                1. Supportive and non-judgmental
                2. Focused on encouragement and growth
                3. Brief but meaningful (2-3 sentences max)
                4. Aimed at building hope and resilience
                Remember to maintain a warm, professional tone while keeping responses concise.
              """
            },
            {"role": "user", "content": userMessage}
          ],
          "temperature": 0.7,
          "max_tokens": 150,  // Added to limit response length
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseJson = json.decode(response.body);
        return responseJson['choices'][0]['message']['content'].trim();
      }
      throw Exception("API Error: ${response.statusCode}");
    } catch (e) {
      return "I apologize, but I'm having trouble connecting right now. Please try again in a moment.";
    }
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmit(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    _messageController.clear();
    _addMessage(trimmedText, true);

    setState(() => _isTyping = true);
    try {
      final response = await _fetchAIResponse(trimmedText);
      if (mounted) {
        setState(() => _isTyping = false);
        _addMessage(response, false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTyping = false);
        _showErrorSnackBar();
      }
    }
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to send message. Please try again.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.blue[900],
      elevation: 0,
      title: Text(
        'RAX Care Support',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.help_outline),
          onPressed: () => _showHelpDialog(),
          tooltip: 'Help',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          _buildBackground(),
          Column(
            children: [
              Expanded(
                child: _buildMessageList(),
              ),
              if (_isTyping) _buildTypingIndicator(),
              _buildMessageInput(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue[900]!,
            Colors.grey[100]!,
          ],
          stops: const [0.0, 0.1],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                DefaultTextStyle(
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                  child: AnimatedTextKit(
                    animatedTexts: [
                      WavyAnimatedText('Thinking...'),
                    ],
                    isRepeatingAnimation: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(true),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue[900] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.poppins(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.poppins(
                      color: message.isUser
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (message.isUser) _buildAvatar(false),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isAI) {
    return CircleAvatar(
      backgroundColor: isAI ? Colors.blue[900] : Colors.blue[700],
      child: Icon(
        isAI ? Icons.support_agent : Icons.person,
        color: Colors.white,
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: _handleSubmit,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: () => _handleSubmit(_messageController.text),
              backgroundColor: Colors.blue[900],
              child: const Icon(Icons.send),
              mini: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'How to Use RAX Care Chat',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              icon: Icons.chat_bubble_outline,
              text: 'Share your thoughts and feelings freely',
            ),
            _buildHelpItem(
              icon: Icons.psychology,
              text: 'Get supportive responses and guidance',
            ),
            _buildHelpItem(
              icon: Icons.privacy_tip_outlined,
              text: 'Your conversations are private and secure',
            ),
            _buildHelpItem(
              icon: Icons.error_outline,
              text: 'In crisis? Call emergency services immediately',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.poppins(
                color: Colors.blue[900],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[900], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}