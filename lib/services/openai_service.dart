import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Handles communication with the Google Gemini API
/// for blood donor–recipient matchmaking.
/// Falls back to a local rule-based engine when the API is unavailable.
class GeminiService {
  static const String _apiBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // Valid Gemini model IDs for the v1beta API (as of 2025)
  static const List<String> _models = [
    'gemini-2.0-flash',        // Latest, fastest
    'gemini-2.0-flash-lite',   // Lightweight fallback
    'gemini-1.5-flash-8b',     // Small, fast fallback
  ];

  static const int _maxRetries = 2;
  static const Duration _timeout = Duration(seconds: 25);

  static const String _systemPrompt = '''
You are DonvivaAI, an expert blood donation matchmaking assistant embedded in the Donviva app.

Your primary goals are:
1. Match donors to recipients — help users find compatible blood donors or recipients based on blood group compatibility rules.
2. Answer blood donation questions — eligibility, health requirements, frequency, safety, myths.
3. Explain blood type compatibility — who can donate to whom, universal donors/recipients.
4. Provide urgent guidance — for emergency blood requests, guide users to act fast and contact hospitals.

Blood compatibility rules:
- O- is the universal donor (can give to anyone)
- AB+ is the universal recipient (can receive from anyone)
- O- donates to: all blood types
- O+ donates to: O+, A+, B+, AB+
- A- donates to: A-, A+, AB-, AB+
- A+ donates to: A+, AB+
- B- donates to: B-, B+, AB-, AB+
- B+ donates to: B+, AB+
- AB- donates to: AB-, AB+
- AB+ donates to: AB+ only

Keep responses concise (2-5 sentences), friendly, and empathetic.
Use bullet points for lists.
Only discuss blood donation, health eligibility, or app features.
If asked off-topic, politely redirect to blood donation topics.
''';

  Future<String> getChatResponse(List<Map<String, String>> messages) async {
    // Support both key names — GEMINI_API_KEY preferred, OPENAI_API_KEY for backward compat
    final apiKey = (dotenv.env['GEMINI_API_KEY'] ?? '').isNotEmpty
        ? dotenv.env['GEMINI_API_KEY']!
        : (dotenv.env['OPENAI_API_KEY'] ?? '');

    // Always try local fallback first for reliability, then API
    final lastUserMessage = messages.isNotEmpty
        ? (messages.lastWhere(
            (m) => m['role'] == 'user',
            orElse: () => {'content': ''},
          )['content'] ?? '')
        : '';

    if (apiKey.isEmpty) {
      debugPrint('No API key found — using local fallback');
      return _localFallback(lastUserMessage);
    }

    // Try each model in order
    for (final model in _models) {
      final result = await _tryModel(model, apiKey, messages, lastUserMessage);
      if (result != null) return result;
    }

    // All API attempts failed — use smart local fallback
    debugPrint('All Gemini models failed — using local fallback');
    return _localFallback(lastUserMessage);
  }

  Future<String?> _tryModel(
    String model,
    String apiKey,
    List<Map<String, String>> messages,
    String lastUserMessage,
  ) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final apiUrl =
            '$_apiBase/$model:generateContent?key=$apiKey';

        final List<Map<String, dynamic>> geminiContents = [];
        for (final msg in messages) {
          geminiContents.add({
            'role': msg['role'] == 'user' ? 'user' : 'model',
            'parts': [
              {'text': msg['content']}
            ],
          });
        }

        final requestBody = {
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt}
            ]
          },
          'contents': geminiContents,
          'generationConfig': {
            'temperature': 0.65,
            'maxOutputTokens': 400,
            'topP': 0.9,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
          ],
        };

        final response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(_timeout);

        debugPrint(
          'Gemini [$model] — HTTP ${response.statusCode} (attempt $attempt)',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          // Safety block on input
          final feedback = data['promptFeedback'] as Map<String, dynamic>?;
          if (feedback != null && feedback['blockReason'] != null) {
            return 'I can only assist with blood donation topics. Please ask '
                'me about blood types, donors, eligibility, or emergency '
                'requests. 🩸';
          }

          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            return _localFallback(lastUserMessage);
          }

          final candidate = candidates[0] as Map<String, dynamic>;
          final finishReason = candidate['finishReason'] as String?;
          if (finishReason == 'SAFETY') {
            return 'I can only assist with blood donation topics. Please ask '
                'me about blood types, donors, eligibility, or emergency '
                'requests. 🩸';
          }

          final content = candidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts == null || parts.isEmpty) {
            return _localFallback(lastUserMessage);
          }

          return (parts[0]['text'] as String).trim();
        } else if (response.statusCode == 400) {
          // Bad request — log and skip this model
          debugPrint('Gemini 400: ${response.body}');
          return null;
        } else if ([429, 500, 503].contains(response.statusCode)) {
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          // This model is overloaded, try next
          return null;
        } else {
          debugPrint('Gemini error ${response.statusCode}: ${response.body}');
          return null;
        }
      } on TimeoutException {
        debugPrint('Gemini [$model] timed out (attempt $attempt)');
        if (attempt >= _maxRetries) return null;
        await Future.delayed(Duration(seconds: attempt));
      } on SocketException catch (e) {
        debugPrint('Gemini [$model] socket error: $e');
        // Network error — no point trying other models
        return _localFallback(lastUserMessage);
      } catch (e) {
        debugPrint('Gemini [$model] unexpected error: $e');
        if (attempt >= _maxRetries) return null;
      }
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────────
  // LOCAL RULE-BASED FALLBACK
  // Provides helpful blood donation answers without any API call.
  // ──────────────────────────────────────────────────────────────────
  String _localFallback(String message) {
    final q = message.toLowerCase();

    // --- NEED BLOOD ---
    if (_contains(q, ['need', 'urgently need', 'require', 'looking for']) &&
        _contains(q, ['blood', 'donor'])) {
      final group = _extractBloodGroup(q);
      if (group != null) {
        final donors = _compatibleDonors(group);
        return '🩸 For **$group** blood, compatible donors are: **${donors.join(', ')}**.\n\n'
            '• Post an urgent request in the app immediately\n'
            '• Contact local hospitals and blood banks\n'
            '• Share this request with friends and family\n\n'
            'Time is critical — act now!';
      }
      return '🩸 Please specify the blood group needed (e.g., A+, O-, AB+).\n\n'
          'Meanwhile:\n'
          '• Post an urgent request in the Donviva app\n'
          '• Contact your nearest blood bank or hospital\n'
          '• O- donors can donate to anyone in an emergency';
    }

    // --- DONATE / CAN I DONATE ---
    if (_contains(q, ['donate', 'can i donate', 'eligible', 'eligibility', 'donating'])) {

      // ── Specific medical conditions — check these FIRST ──────────
      if (_contains(q, ['hiv', 'aids', 'hiv positive', 'hiv+'])) {
        return '❌ **HIV/AIDS and Blood Donation**\n\n'
            'Unfortunately, **people living with HIV/AIDS cannot donate blood**.\n\n'
            '• HIV is a permanent deferral in most countries\n'
            '• This is to protect the safety of blood recipients\n'
            '• Even if viral load is undetectable, donation is not permitted\n\n'
            'There are many other ways you can help — consider volunteering at blood drives or raising awareness! 💙\n\n'
            'For support: contact your local HIV/AIDS helpline or healthcare provider.';
      }

      if (_contains(q, ['hepatitis', 'hep b', 'hep c', 'liver disease'])) {
        return '❌ **Hepatitis and Blood Donation**\n\n'
            '• **Hepatitis B or C (current/past):** Permanent deferral — cannot donate\n'
            '• **Hepatitis A:** Can donate after full recovery (usually 6+ weeks)\n'
            '• Even if treated or "cured" from Hep C, most blood banks still permanently defer\n\n'
            'Your safety and the recipient\'s safety come first. 💙\n'
            'Please consult your local blood bank for specific guidelines.';
      }

      if (_contains(q, ['cancer', 'chemotherapy', 'chemo', 'leukemia', 'lymphoma', 'tumour', 'tumor'])) {
        return '⚠️ **Cancer and Blood Donation**\n\n'
            '• **During active cancer treatment:** Cannot donate blood\n'
            '• **After treatment (solid tumors):** May donate after being cancer-free for 1–5 years (varies by country/type)\n'
            '• **Blood cancers (leukemia/lymphoma):** Permanent deferral in most countries\n\n'
            'Please consult your oncologist and local blood bank for your specific situation. 💙';
      }

      if (_contains(q, ['diabetes', 'diabetic', 'insulin'])) {
        return '✅ **Diabetes and Blood Donation**\n\n'
            'Good news — most diabetics **CAN donate blood**!\n\n'
            '• Well-controlled diabetes (diet or oral medication): Usually eligible\n'
            '• Insulin-dependent Type 1 diabetes: Eligible in many countries if well-controlled\n'
            '• Blood sugar must be in normal range on donation day\n\n'
            'Always inform the blood bank about your condition. They will check your eligibility on the day. 🩸';
      }

      if (_contains(q, ['pregnant', 'pregnancy', 'breastfeed', 'nursing', 'postpartum'])) {
        return '⛔ **Pregnancy and Blood Donation**\n\n'
            '• **During pregnancy:** Cannot donate blood\n'
            '• **After delivery:** Must wait at least **6 months** before donating\n'
            '• **Breastfeeding:** Should not donate — wait until baby is fully weaned\n\n'
            'Your health and your baby\'s health come first! 💙\n'
            'Thank you for wanting to donate — you can register for future donations in the app.';
      }

      if (_contains(q, ['heart', 'cardiac', 'heart disease', 'heart attack', 'bypass', 'pacemaker', 'blood pressure'])) {
        return '⚠️ **Heart Conditions and Blood Donation**\n\n'
            '• **High blood pressure (controlled):** May donate if BP < 180/100 on donation day\n'
            '• **Heart attack/bypass surgery:** Defer for at least 6–12 months after recovery\n'
            '• **Pacemaker:** Usually permanently deferred (varies by country)\n'
            '• **Active heart disease:** Cannot donate\n\n'
            'Always consult your cardiologist and inform the blood bank about your condition. 🩸';
      }

      if (_contains(q, ['malaria', 'dengue', 'typhoid', 'covid', 'coronavirus', 'tb', 'tuberculosis'])) {
        return '⚠️ **Infectious Disease and Blood Donation**\n\n'
            '• **Malaria:** Wait 3 years after treatment (or 12 months if travelled to malaria zone)\n'
            '• **Dengue:** Wait 6 months after full recovery\n'
            '• **COVID-19:** Wait 28 days after full recovery (14 days if vaccinated)\n'
            '• **Typhoid:** Wait 1 year after recovery\n'
            '• **Active TB:** Cannot donate; wait 2 years after completing treatment\n\n'
            'When in doubt, always check with your local blood bank. 🩸';
      }

      if (_contains(q, ['tattoo', 'piercing', 'body art'])) {
        return '⏰ **Tattoo/Piercing and Blood Donation**\n\n'
            '• **Tattoo or piercing:** Wait **3–6 months** (varies by country)\n'
            '• If done at a licensed, sterile facility: some countries allow 6-week wait\n'
            '• If done in an unlicensed place: wait at least 12 months\n\n'
            'This deferral protects against hepatitis and other bloodborne infections. 🩸';
      }

      if (_contains(q, ['medication', 'medicine', 'drug', 'antibiotics', 'blood thinner', 'aspirin', 'steroids'])) {
        return '⚠️ **Medications and Blood Donation**\n\n'
            '• **Antibiotics:** Wait until course is complete + 48 hours\n'
            '• **Blood thinners (warfarin, heparin):** Cannot donate while on medication\n'
            '• **Aspirin:** Wait 48–72 hours (for platelet donation)\n'
            '• **Steroids:** Depends on reason — consult blood bank\n'
            '• **Most common medications (vitamins, antihistamines):** Usually fine\n\n'
            'Always declare all medications on your donation form. 🩸';
      }

      if (_contains(q, ['fever', 'cold', 'flu', 'sick', 'infection', 'cough'])) {
        return '⏰ **Illness and Blood Donation**\n\n'
            '• **Active fever/cold/flu:** Do NOT donate until fully recovered\n'
            '• **After fever:** Wait at least **14 days** after symptoms resolve\n'
            '• **Bacterial infection:** Wait until antibiotics are complete + 48 hours\n\n'
            'Donating while sick can harm both you and the recipient. Please rest and recover first! 🩸';
      }

      if (_contains(q, ['2 month', '60 day', '56 day', '8 week', 'recently donated'])) {
        return '⏰ **Donation Gap Requirements**\n\n'
            '• **Whole blood:** Minimum **56 days (8 weeks)** between donations\n'
            '• **Platelets:** Every 7 days, up to 24 times/year\n'
            '• **Plasma:** Every 28 days\n\n'
            'If you donated 2 months ago (~60 days), you are **eligible** to donate again! 🩸\n'
            'Stay hydrated and eat iron-rich foods before your next donation.';
      }

      // ── General eligibility (no specific condition detected) ──────
      return '✅ **General Blood Donation Eligibility:**\n'
          '• Age: 18–65 years\n'
          '• Weight: at least 50 kg (110 lbs)\n'
          '• Hemoglobin: ≥12.5 g/dL (women), ≥13 g/dL (men)\n'
          '• No active illness, fever, or infection\n'
          '• At least 56 days since last whole blood donation\n'
          '• No HIV, hepatitis B/C, or active cancer\n\n'
          'Have a specific condition? Ask me and I\'ll give you a detailed answer! 🩸';
    }


    // --- BLOOD TYPE COMPATIBILITY ---
    if (_contains(q, ['compatibility', 'compatible', 'who can', 'donate to', 'receive from'])) {
      final group = _extractBloodGroup(q);
      if (group != null) {
        final donors = _compatibleDonors(group);
        final recipients = _compatibleRecipients(group);
        return '🩸 **$group Blood Type Info:**\n\n'
            '**Can receive from:** ${donors.join(', ')}\n'
            '**Can donate to:** ${recipients.join(', ')}\n\n'
            '${_bloodGroupFact(group)}';
      }
      return '🩸 **Blood Compatibility Summary:**\n'
          '• **O-** → Universal donor (gives to all)\n'
          '• **AB+** → Universal recipient (receives from all)\n'
          '• **O+** → Most common type, donates to O+, A+, B+, AB+\n'
          '• **A+** → Donates to A+, AB+\n'
          '• **B+** → Donates to B+, AB+\n\n'
          'Which blood type would you like to know more about?';
    }

    // --- O- specific ---
    if (q.contains('o-') || q.contains('o negative')) {
      return '🩸 **O- (O Negative)** is the **universal donor**!\n\n'
          '• Can donate red blood cells to **ALL** blood types\n'
          '• Extremely valuable in emergencies when blood type is unknown\n'
          '• Can only receive from **O-** donors\n'
          '• Only ~7% of people have this blood type\n\n'
          'O- donors are heroes — always in high demand! 💪';
    }

    // --- AB+ specific ---
    if (q.contains('ab+') || q.contains('ab positive')) {
      return '🩸 **AB+ (AB Positive)** is the **universal recipient**!\n\n'
          '• Can receive blood from **ALL** blood types (O-, O+, A-, A+, B-, B+, AB-, AB+)\n'
          '• Can only donate to **AB+** patients\n'
          '• AB+ plasma is universal — can be given to any patient\n'
          '• About 3–5% of people have this blood type\n\n'
          'AB+ individuals are great plasma donors! 🩸';
    }

    // --- EMERGENCY ---
    if (_contains(q, ['emergency', 'critical', 'urgent', 'immediately'])) {
      final group = _extractBloodGroup(q);
      return '🚨 **Emergency Blood Request!**\n\n'
          '${group != null ? "Blood needed: **$group**\nCompatible donors: **${_compatibleDonors(group).join(', ')}**\n\n" : ""}'
          'Immediate steps:\n'
          '• Post an emergency request in the Donviva app NOW\n'
          '• Call your nearest hospital blood bank immediately\n'
          '• Contact the national blood service helpline\n'
          '• If O- is unavailable, ask for O+\n\n'
          'Every minute counts — act immediately! ❤️';
    }

    // --- FREQUENCY ---
    if (_contains(q, ['how often', 'frequency', 'again', 'how many times', 'how long'])) {
      return '⏰ **Donation Frequency Guidelines:**\n'
          '• **Whole blood:** Every 56 days (8 weeks)\n'
          '• **Platelets:** Every 7 days, up to 24 times/year\n'
          '• **Plasma:** Every 28 days\n'
          '• **Double red cells:** Every 112 days\n\n'
          'Regular donation saves lives! Consider setting a reminder in the app. 🩸';
    }

    // --- DEFAULT ---
    return 'Hello! I\'m **DonvivaAI** 🩸 — your blood donation assistant.\n\n'
        'I can help you with:\n'
        '• Blood type compatibility (e.g., "Who can donate to A+?")\n'
        '• Donation eligibility (e.g., "Can I donate after 2 months?")\n'
        '• Emergency blood requests\n'
        '• Donation frequency and guidelines\n\n'
        'What would you like to know?';
  }

  bool _contains(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  String? _extractBloodGroup(String text) {
    final groups = ['ab+', 'ab-', 'a+', 'a-', 'b+', 'b-', 'o+', 'o-'];
    for (final g in groups) {
      if (text.contains(g)) return g.toUpperCase();
    }
    // Text version
    final groupMap = {
      'a positive': 'A+', 'a negative': 'A-',
      'b positive': 'B+', 'b negative': 'B-',
      'o positive': 'O+', 'o negative': 'O-',
      'ab positive': 'AB+', 'ab negative': 'AB-',
    };
    for (final entry in groupMap.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  List<String> _compatibleDonors(String bloodGroup) {
    const donors = {
      'A+': ['A+', 'A-', 'O+', 'O-'],
      'A-': ['A-', 'O-'],
      'B+': ['B+', 'B-', 'O+', 'O-'],
      'B-': ['B-', 'O-'],
      'AB+': ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
      'AB-': ['A-', 'B-', 'O-', 'AB-'],
      'O+': ['O+', 'O-'],
      'O-': ['O-'],
    };
    return donors[bloodGroup] ?? [];
  }

  List<String> _compatibleRecipients(String bloodGroup) {
    const recipients = {
      'A+': ['A+', 'AB+'],
      'A-': ['A+', 'A-', 'AB+', 'AB-'],
      'B+': ['B+', 'AB+'],
      'B-': ['B+', 'B-', 'AB+', 'AB-'],
      'AB+': ['AB+'],
      'AB-': ['AB+', 'AB-'],
      'O+': ['O+', 'A+', 'B+', 'AB+'],
      'O-': ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
    };
    return recipients[bloodGroup] ?? [];
  }

  String _bloodGroupFact(String group) {
    const facts = {
      'O-': '⭐ O- is the **universal donor** — can donate to anyone!',
      'O+': '🌟 O+ is the most common blood type worldwide.',
      'AB+': '⭐ AB+ is the **universal recipient** — can receive from anyone!',
      'AB-': '💡 AB- can donate plasma to any blood type.',
      'A+': '🩸 A+ is the second most common blood type.',
      'A-': '💡 A- donors are highly valuable especially for surgeries.',
      'B+': '🩸 B+ donors are important for the South Asian and Black communities.',
      'B-': '💡 B- is rare — only about 2% of people have this type.',
    };
    return facts[group] ?? '';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}