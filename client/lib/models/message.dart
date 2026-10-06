import 'routing_decision.dart';

enum MessageSender {
  user,
  assistant,
  system,
}

class ChatMessage {
  final String id;
  final MessageSender sender;
  String text;
  final DateTime timestamp;
  IntentPillData? intentPill;
  ExecutionTelemetry? telemetry;
  bool isStreaming;
  bool isPiiSanitized;
  bool isFallback;
  String? fallbackReason;
  String? rawOriginalPrompt;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.intentPill,
    this.telemetry,
    this.isStreaming = false,
    this.isPiiSanitized = false,
    this.isFallback = false,
    this.fallbackReason,
    this.rawOriginalPrompt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'intent_pill': intentPill?.toJson(),
    'telemetry': telemetry?.toJson(),
    'is_streaming': isStreaming,
    'is_pii_sanitized': isPiiSanitized,
    'is_fallback': isFallback,
    'fallback_reason': fallbackReason,
    'raw_original_prompt': rawOriginalPrompt,
  };
}
