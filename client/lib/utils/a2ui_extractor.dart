import 'dart:convert';
import '../models/a2ui_models.dart';

/// Result of extracting embedded A2UI components, dynamic choices,
/// stage cues, and clean narrative speech from raw model output.
class ExtractedA2UIPayload {
  final String cleanSpeechText;
  final String? extractedStageCue;
  final A2UISurface? surface;
  final List<A2UIChoiceItem> choices;
  final bool hasA2UIPayload;

  const ExtractedA2UIPayload({
    required this.cleanSpeechText,
    this.extractedStageCue,
    this.surface,
    this.choices = const [],
    this.hasA2UIPayload = false,
  });
}

/// A2UIExtractor
/// Robustly isolates declarative A2UI payloads (JSON surfaces or choice arrays)
/// from conversational narrative dialogue, stage cues, and markdown fences.
///
/// Ensures compliance with A2UI Protocol v0.9+ and prevents raw JSON markdown
/// from polluting user-visible dialogue bubbles.
class A2UIExtractor {
  static final RegExp _stageCueRegex = RegExp(r'\*\[(.*?)\]\*');
  static final RegExp _jsonFenceRegex = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    caseSensitive: false,
  );
  static final RegExp _jsonArrayRegex = RegExp(
    r'\[\s*\{[\s\S]*\}\s*\]',
  );
  static final RegExp _jsonObjectRegex = RegExp(
    r'\{\s*"[a-zA-Z0-9_-]+"\s*:[\s\S]*\}',
  );

  /// Analyzes raw model output or turn speech text and extracts A2UI structures.
  static ExtractedA2UIPayload extract({
    required String rawText,
    String? existingStageCue,
    String? surfaceIdPrefix,
    String? objectiveTitle,
    String? objectiveContext,
  }) {
    if (rawText.trim().isEmpty) {
      return const ExtractedA2UIPayload(
        cleanSpeechText: '',
        hasA2UIPayload: false,
      );
    }

    // Filter out any leaked SSE protocol frames (e.g. event: error, data: [DONE])
    final sanitizedLines = rawText.split('\n').where((line) {
      final t = line.trim();
      return !t.startsWith('event:') && t != 'data: [DONE]';
    }).join('\n');

    if (sanitizedLines.trim().isEmpty) {
      return const ExtractedA2UIPayload(
        cleanSpeechText: '',
        hasA2UIPayload: false,
      );
    }

    String workingText = sanitizedLines;
    String? extractedCue;

    // 1. Extract stage cues (*[cue]*), if present
    final cueMatch = _stageCueRegex.firstMatch(workingText);
    if (cueMatch != null) {
      extractedCue = cueMatch.group(0);
      // Remove cue from working text to prevent duplication in speech body
      workingText = workingText.replaceFirst(cueMatch.group(0)!, '').trim();
    }

    String? jsonCandidate;
    String textWithoutJson = workingText;

    // 2. Identify potential JSON payload (markdown fence or raw JSON block)
    final fenceMatch = _jsonFenceRegex.firstMatch(workingText);
    if (fenceMatch != null) {
      jsonCandidate = fenceMatch.group(1)?.trim();
      textWithoutJson = workingText.replaceFirst(fenceMatch.group(0)!, '').trim();
    } else {
      final arrayMatch = _jsonArrayRegex.firstMatch(workingText);
      if (arrayMatch != null) {
        jsonCandidate = arrayMatch.group(0)?.trim();
        textWithoutJson = workingText.replaceFirst(arrayMatch.group(0)!, '').trim();
      } else {
        final objectMatch = _jsonObjectRegex.firstMatch(workingText);
        if (objectMatch != null) {
          jsonCandidate = objectMatch.group(0)?.trim();
          textWithoutJson = workingText.replaceFirst(objectMatch.group(0)!, '').trim();
        }
      }
    }

    A2UISurface? parsedSurface;
    List<A2UIChoiceItem> parsedChoices = [];
    bool hasA2UI = false;

    if (jsonCandidate != null && jsonCandidate.isNotEmpty) {
      try {
        final sanitizedJson = _sanitizeJsonString(jsonCandidate);
        final dynamic decoded = jsonDecode(sanitizedJson);

        if (decoded is List) {
          // Decoded a list of choices
          parsedChoices = _parseChoiceList(decoded);
          if (parsedChoices.isNotEmpty) {
            hasA2UI = true;
            final sid = surfaceIdPrefix ?? 'a2ui-extracted-${DateTime.now().millisecondsSinceEpoch}';
            parsedSurface = A2UISurface.createProactiveTurn(
              surfaceId: sid,
              stageCue: existingStageCue ?? extractedCue,
              spokenLine: textWithoutJson.isNotEmpty ? textWithoutJson : null,
              objectiveTitle: objectiveTitle,
              objectiveContext: objectiveContext,
              choices: parsedChoices,
            );
          }
        } else if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);

          // Case A: Full declarative A2UISurface
          if (map.containsKey('components') || map.containsKey('surfaceId')) {
            parsedSurface = A2UISurface.fromJson(map);
            hasA2UI = true;
          }
          // Case B: Game Master Assessment containing choices
          else if (map.containsKey('choices') && map['choices'] is List) {
            parsedChoices = _parseChoiceList(map['choices'] as List);
            if (parsedChoices.isNotEmpty) {
              hasA2UI = true;
              final sid = surfaceIdPrefix ?? 'a2ui-gm-${DateTime.now().millisecondsSinceEpoch}';
              final commentary = map['assessment']?.toString() ?? map['commentary']?.toString();
              parsedSurface = A2UISurface.createProactiveTurn(
                surfaceId: sid,
                stageCue: existingStageCue ?? extractedCue,
                spokenLine: textWithoutJson.isNotEmpty ? textWithoutJson : null,
                gameMasterCommentary: commentary,
                choices: parsedChoices,
              );
            }
          }
        }
      } catch (_) {
        // Failed to parse JSON candidate; treat as unparsed text without crashing
        hasA2UI = false;
      }
    }

    // Clean remaining narrative speech text
    String cleanSpeech = hasA2UI ? textWithoutJson : workingText;
    cleanSpeech = cleanSpeech
        .replaceAll(RegExp(r'^\s*[\r\n]+|[\r\n]+\s*$'), '')
        .trim();

    return ExtractedA2UIPayload(
      cleanSpeechText: cleanSpeech,
      extractedStageCue: extractedCue,
      surface: parsedSurface,
      choices: parsedChoices,
      hasA2UIPayload: hasA2UI,
    );
  }

  static List<A2UIChoiceItem> _parseChoiceList(List<dynamic> rawList) {
    final List<A2UIChoiceItem> result = [];
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is Map) {
        try {
          final choice = A2UIChoiceItem.fromJson(Map<String, dynamic>.from(item));
          if (choice.label.isNotEmpty) {
            result.add(choice);
          }
        } catch (_) {}
      }
    }
    return result;
  }

  /// Cleans markdown residue, trailing commas, or quotes from JSON string candidates.
  static String _sanitizeJsonString(String input) {
    var s = input.trim();
    // Remove wrapping quotes if the whole string was quoted
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    // Remove trailing commas before closing braces or brackets
    s = s.replaceAll(RegExp(r',\s*(\]|\})'), r'$1');
    return s;
  }
}
