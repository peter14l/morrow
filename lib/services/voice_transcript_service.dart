import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';

/// Model for voice transcription result with multilingual support
class VoiceTranscript {
  final String text;
  final double confidence;
  final String language; // ISO language code (e.g., 'en', 'es', 'ar')
  final DateTime createdAt;

  VoiceTranscript({
    required this.text,
    required this.confidence,
    required this.language,
    required this.createdAt,
  });

  factory VoiceTranscript.fromJson(Map<String, dynamic> json) {
    return VoiceTranscript(
      text: json['text'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      language: json['language'] ?? 'en',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// Check if the detected language is Right-to-Left (RTL)
  bool get isRTL {
    const rtlLanguages = ['ar', 'fa', 'he', 'ur', 'ps', 'sd'];
    return rtlLanguages.contains(language.toLowerCase().split('-')[0]);
  }
}

/// Voice message transcript service for fast, multilingual speech-to-text.
class VoiceTranscriptService {
  final _supabase = SupabaseService().client;

  // Client-side cache to prevent redundant API calls
  final Map<String, VoiceTranscript> _cache = {};

  /// Get existing transcript for a message
  Future<VoiceTranscript?> getTranscript(String messageId) async {
    if (_cache.containsKey(messageId)) return _cache[messageId];

    try {
      final response = await _supabase
          .from('message_transcripts')
          .select()
          .eq('message_id', messageId)
          .maybeSingle();

      if (response != null) {
        final transcript = VoiceTranscript.fromJson(response);
        _cache[messageId] = transcript;
        return transcript;
      }
      return null;
    } catch (e) {
      debugPrint('[Transcription] Error fetching from DB: $e');
      return null;
    }
  }

  /// Transcribe audio using a high-performance multilingual Edge Function (e.g., Whisper)
  /// This method now uses the asynchronous task queue for better scalability.
  Future<VoiceTranscript> transcribeVoiceMessage(
    String messageId,
    String audioUrl,
  ) async {
    // Try async queue-based transcription first (scalable)
    try {
      return await queueTranscription(messageId, audioUrl);
    } catch (e) {
      debugPrint(
        '[Transcription] Queue method failed, falling back to sync: $e',
      );
      // Fallback to legacy sync method if queue fails
      return await transcribeVoiceMessageSync(messageId, audioUrl);
    }
  }

  /// Asynchronous transcription using the task queue and Realtime
  Future<VoiceTranscript> queueTranscription(
    String messageId,
    String audioUrl,
  ) async {
    debugPrint('[Transcription] Queuing task for: $audioUrl');

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // 1. Insert task into queue
    final taskResponse = await _supabase
        .from('task_queue')
        .insert({
          'task_type': 'transcription',
          'payload': {'message_id': messageId, 'audio_url': audioUrl},
          'user_id': userId,
          'status': 'pending',
        })
        .select()
        .single();

    final taskId = taskResponse['id'] as String;

    // 2. Listen for completion via Realtime
    final completion = _supabase
        .from('task_queue')
        .stream(primaryKey: ['id'])
        .eq('id', taskId)
        .firstWhere(
          (data) =>
              data.isNotEmpty &&
              (data[0]['status'] == 'completed' ||
                  data[0]['status'] == 'failed'),
        )
        .timeout(const Duration(seconds: 30));

    final resultData = await completion;
    final taskResult = resultData[0];

    if (taskResult['status'] == 'failed') {
      throw Exception(
        taskResult['error'] ?? 'Task failed without error message',
      );
    }

    final transcript = VoiceTranscript.fromJson(taskResult['result']);
    _cache[messageId] = transcript;
    return transcript;
  }

  /// Legacy synchronous transcription method
  Future<VoiceTranscript> transcribeVoiceMessageSync(
    String messageId,
    String audioUrl,
  ) async {
    debugPrint('[Transcription] Requesting sync transcription for: $audioUrl');

    try {
      // 1. Invoke the Supabase Edge Function
      // This function should handle downloading the audio and calling Whisper/AssemblyAI
      final response = await _supabase.functions.invoke(
        'transcribe-voice',
        body: {
          'message_id': messageId,
          'audio_url': audioUrl,
          'config': {'multilingual': true, 'task': 'transcribe'},
        },
      );

      if (response.status != 200) {
        throw Exception(
          'Transcription service returned status ${response.status}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      final transcript = VoiceTranscript.fromJson(data);

      // 2. Persist to DB for future sessions (handled by Function or here)
      // If the function doesn't persist, we do it here:
      await _supabase.from('message_transcripts').upsert({
        'message_id': messageId,
        'text': transcript.text,
        'confidence': transcript.confidence,
        'language': transcript.language,
        'created_at': transcript.createdAt.toIso8601String(),
      });

      _cache[messageId] = transcript;
      return transcript;
    } catch (e) {
      debugPrint('[Transcription] API Error: $e');

      // Fast fallback for demo/dev if function isn't deployed yet
      if (kDebugMode) {
        return VoiceTranscript(
          text:
              '[Service unavailable] Ensure "transcribe-voice" Edge Function is deployed.',
          confidence: 0.0,
          language: 'en',
          createdAt: DateTime.now(),
        );
      }
      rethrow;
    }
  }
}
