import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AgoraTokenService {
  static final AgoraTokenService _instance = AgoraTokenService._internal();
  factory AgoraTokenService() => _instance;
  AgoraTokenService._internal();

  Future<String?> getRtcToken({
    required String channelId,
    required int uid,
    int expireSeconds = 3600,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.backendUrl}/api/agora/rtc-token').replace(
        queryParameters: {
          'channel': channelId,
          'uid': uid.toString(),
          'expire': expireSeconds.toString(),
        },
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        debugPrint('AgoraTokenService: http ${resp.statusCode} ${resp.body}');
        return null;
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      return data['token']?.toString();
    } catch (e) {
      debugPrint('AgoraTokenService: error $e');
      return null;
    }
  }
}


