import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_models.dart';

// Service was added to keep all REST API logic in one place.
// The UI should ask this service for data instead of building HTTP requests itself.
class RestApiService {
  final String baseUrl;

  const RestApiService({
    // Uses same API_URL idea as the websocket setup.
    // Makes local device/emulator testing configurable.
    this.baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: '127.0.0.1:8000',
    ),
  });

  Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse('http://$baseUrl$path').replace(
      queryParameters: queryParameters,
    );
  }

// Added for the side panel category chip list.
  Future<List<Category>> getCategories() async {
    final res = await http.get(_uri('/get/categories'));
    _checkStatus(res, 'GET /get/categories');

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

// Added so that the side panel can create new categories from the inline form.
  Future<Category> createCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        message: 'Name cannot be empty',
      );
    }

    final res = await http.post(
      _uri('/create/category', queryParameters: {'name': trimmed}),
    );
    _checkStatus(res, 'POST /create/category');

    return Category.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

// Added for the conversations section.
// Optional categoryId is used when filtering by selected category chip.
  Future<List<Conversation>> getConversations({int? categoryId}) async {
    final params = categoryId != null ? {'cat_id': '$categoryId'} : null;

    final res = await http.get(
      _uri('/get/conversations', queryParameters: params),
    );
    _checkStatus(res, 'GET /get/conversations');

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

// Added for the transcript/segments sections that appears when a conversation is selected in the side panel.
  Future<List<ConversationVector>> getVectors(int conversationId) async {
    final res = await http.get(
      _uri('/get/vectors', queryParameters: {'conv_id': '$conversationId'}),
    );
    _checkStatus(res, 'GET /get/vectors?conv_id=$conversationId');

    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => ConversationVector.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _checkStatus(http.Response res, String label) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

//Added to surface useful backend error details in the UI instead of just showing generic failed request.
    String message = 'HTTP ${res.statusCode}';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        message =
            (decoded['detail'] ?? decoded['message'] ?? message).toString();
      } else if (decoded is String && decoded.isNotEmpty) {
        message = decoded;
      }
    } catch (_) {
      if (res.body.trim().isNotEmpty) {
        message = res.body.trim();
      }
    }

    throw ApiException(
      statusCode: res.statusCode,
      message: '[$label] $message',
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}
