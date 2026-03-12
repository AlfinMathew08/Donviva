import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/openai_service.dart';
import '../services/firebase_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = false;
  bool _isLoadingHistory = true;

  static const String _welcomeMessage =
      "Hello! I'm **DonvivaAI** 🩸 — your blood donation matchmaking assistant.\n\nI can help you:\n• Find compatible blood donors\n• Check your donation eligibility\n• Understand blood type compatibility\n• Post or respond to urgent requests\n\nHow can I assist you today?";

  final List<ChatMessage> _messages = [];

  // Quick suggestion chips
  final List<Map<String, String>> _suggestions = [
    {'label': '🩸 I need A+ blood', 'query': 'I urgently need A+ blood. Who can donate to me?'},
    {'label': '💉 Can I donate?', 'query': 'I want to donate blood. Am I eligible if I donated 2 months ago?'},
    {'label': '🔗 O- compatibility', 'query': 'Who can an O- blood type person donate to?'},
    {'label': '⚠️ Emergency O+', 'query': 'Emergency! I need O+ blood for a patient in critical condition.'},
    {'label': '📋 AB+ info', 'query': 'Tell me about AB+ blood type and who can donate to AB+ patients.'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await FirebaseService.instance.loadChatHistory();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      if (history.isEmpty) {
        // First time: show welcome message and save it
        final welcome = ChatMessage(text: _welcomeMessage, isUser: false);
        _messages.add(welcome);
        FirebaseService.instance.saveChatMessage(
          text: _welcomeMessage,
          isUser: false,
          timestamp: welcome.timestamp,
        );
      } else {
        // Restore history (oldest first → reversed for the ListView which is reversed)
        for (final m in history) {
          _messages.insert(0, ChatMessage(
            text: m['text'] as String,
            isUser: m['isUser'] as bool,
            timestamp: (m['timestamp'] as dynamic).toDate(),
          ));
        }
      }
      _isLoadingHistory = false;
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Clear chat history?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('This will permanently delete all your chat messages.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: GoogleFonts.poppins(color: AppColors.criticalRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseService.instance.clearChatHistory();
    if (!mounted) return;
    final welcome = ChatMessage(text: _welcomeMessage, isUser: false);
    await FirebaseService.instance.saveChatMessage(
      text: _welcomeMessage,
      isUser: false,
      timestamp: welcome.timestamp,
    );
    setState(() {
      _messages.clear();
      _messages.add(welcome);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _inputController.clear();

    final userMsg = ChatMessage(text: trimmed, isUser: true);
    setState(() {
      _messages.insert(0, userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Save user message to Firestore
      await FirebaseService.instance.saveChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: userMsg.timestamp,
      );

      // Build conversation history for the API (last 15 messages)
      final history = _messages
          .skip(1) // Skip the current message we just added to index 0
          .take(15) // Keep history manageable
          .toList()
          .reversed
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      // Ensure alternating roles (Model -> User -> Model -> User)
      // This prevents Gemini API 400 errors if history is fragmented
      final List<Map<String, String>> cleanedHistory = [];
      for (final msg in history) {
        if (cleanedHistory.isNotEmpty && cleanedHistory.last['role'] == msg['role']) {
          // Merge identical roles by appending content
          cleanedHistory.last['content'] = "${cleanedHistory.last['content']}\n${msg['content']}";
        } else {
          cleanedHistory.add(Map<String, String>.from(msg));
        }
      }
      cleanedHistory.add({'role': 'user', 'content': trimmed});

      final response = await _geminiService.getChatResponse(cleanedHistory);

      if (mounted) {
        final aiMsg = ChatMessage(text: response, isUser: false);
        setState(() {
          _messages.insert(0, aiMsg);
        });
        // Save AI response to Firestore
        await FirebaseService.instance.saveChatMessage(
          text: response,
          isUser: false,
          timestamp: aiMsg.timestamp,
        );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error. Using local fallback...'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Fallback response if everything else fails
        final fallback = _geminiService.getChatResponse([{'role': 'user', 'content': trimmed}]);
        fallback.then((response) {
            if (mounted) {
               final aiMsg = ChatMessage(text: response, isUser: false);
                setState(() {
                  _messages.insert(0, aiMsg);
                });
                _scrollToBottom();
            }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoadingHistory)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryRed),
              ),
            )
          else ...[
            _buildSuggestionChips(),
            Expanded(child: _buildMessageList()),
            if (_isLoading) _buildTypingIndicator(),
            _buildInputBar(bottomInset),
          ],
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // AI avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: AppColors.primaryRed,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DonvivaAI',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2ECC71),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Gemini AI • Online',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Clear history button
              GestureDetector(
                onTap: _clearHistory,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick suggestion chips ─────────────────────────────────────────────
  Widget _buildSuggestionChips() {
    return Container(
      color: const Color(0xFFF4F6FB),
      padding: const EdgeInsets.fromLTRB(12, 14, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Quick questions',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestions.map((s) {
                return GestureDetector(
                  onTap: () => _handleSubmit(s['query']!),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryRed.withValues(alpha: 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      s['label']!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    gradient:
                        isUser ? AppColors.primaryGradient : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? AppColors.primaryRed.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _buildMessageText(msg.text, isUser),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatTime(msg.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primaryRed,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUser) {
    // Parse simple **bold** markdown
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: isUser ? Colors.white : AppColors.textDark,
        height: 1.45,
      ),
    );
  }

  // ── Typing indicator ───────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildDot(0),
                _buildDot(150),
                _buildDot(300),
                const SizedBox(width: 4),
                Text(
                  'Thinking...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, val, __) => Opacity(
        opacity: val,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: CircleAvatar(
            radius: 4,
            backgroundColor: AppColors.primaryRed,
          ),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────
  Widget _buildInputBar(double bottomInset) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: bottomInset > 0 ? bottomInset + 10 : 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.15),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _inputController,
                onSubmitted: _handleSubmit,
                textInputAction: TextInputAction.send,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration.collapsed(
                  hintText: 'Ask about donors, eligibility, blood types…',
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textLight,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () => _handleSubmit(_inputController.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isLoading ? null : AppColors.primaryGradient,
                color: _isLoading ? AppColors.textLight : null,
                shape: BoxShape.circle,
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primaryRed.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}