import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../domain/models/scrape_job.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final cleanQuery = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        cleanQuery[entry.key] = value;
      }
    }
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: cleanQuery.isEmpty ? null : cleanQuery);
  }

  Future<bool> healthCheck() async {
    final response = await _client.get(_uri('/health'));
    if (response.statusCode != 200) {
      return false;
    }
    final body = jsonDecode(response.body);
    return body is Map && body['status'] == 'ok';
  }

  Future<List<Map<String, dynamic>>> getApps({int? projectId}) async {
    final query = <String, String>{};
    if (projectId != null) query['project_id'] = projectId.toString();
    final response = await _client.get(_uri('/apps', query));
    _throwIfNotOk(response);
    return _decodeList(response.body);
  }

  Future<Map<String, dynamic>> addPlayApp(
    String url, {
    bool downloadScreenshots = false,
  }) async {
    final response = await _client.post(
      _uri('/apps/play'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {'url': url, 'download_screenshots': downloadScreenshots},
      ),
    );
    _throwIfNotOk(response);
    return _decodeMap(response.body);
  }

  /// Returns a map with 'reviews' (list) and 'total' (int).
  Future<Map<String, dynamic>> getReviews({
    String? appId,
    String? platform,
    int? projectId,
    bool featureRequestOnly = false,
    bool? pinned,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'app_id': appId ?? '',
      'platform': platform ?? '',
      if (featureRequestOnly) 'feature_request_only': 'true',
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (pinned != null) query['pinned'] = pinned.toString();
    if (projectId != null) query['project_id'] = projectId.toString();
    final response = await _client.get(_uri('/reviews', query));
    _throwIfNotOk(response);
    final map = _decodeMap(response.body);
    if (map['reviews'] is! List || map['total'] == null) {
      throw const FormatException('Expected reviews list and total in response');
    }
    return map;
  }

  Future<void> setReviewPinned(int reviewId, bool pinned) async {
    final response = await _client.patch(
      _uri('/reviews/$reviewId/pin'),
      headers: {'Content-Type': 'application/json'},
      body: '{"pinned": $pinned}',
    );
    _throwIfNotOk(response);
  }

  Future<List<Map<String, dynamic>>> getFeatureRequests({
    String? appId,
    String? platform,
    int? projectId,
  }) async {
    final query = <String, String>{
      'app_id': appId ?? '',
      'platform': platform ?? '',
    };
    if (projectId != null) query['project_id'] = projectId.toString();
    final response = await _client.get(_uri('/feature-requests', query));
    _throwIfNotOk(response);
    return _decodeList(response.body);
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final response = await _client.get(_uri('/projects'));
    _throwIfNotOk(response);
    return _decodeList(response.body);
  }

  Future<Map<String, dynamic>> getProject(int id) async {
    final response = await _client.get(_uri('/projects/$id'));
    _throwIfNotOk(response);
    return _decodeMap(response.body);
  }

  Future<Map<String, dynamic>> createProject({
    required String name,
    String? description,
    String? icon,
    List<int>? appIds,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      if (appIds != null) 'app_ids': appIds,
    };
    final response = await _client.post(
      _uri('/projects'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _throwIfNotOk(response);
    return _decodeMap(response.body);
  }

  Future<Map<String, dynamic>> updateProject(
    int id, {
    String? name,
    String? description,
    String? icon,
    List<int>? appIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (icon != null) body['icon'] = icon;
    if (appIds != null) body['app_ids'] = appIds;
    final response = await _client.patch(
      _uri('/projects/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _throwIfNotOk(response);
    return _decodeMap(response.body);
  }

  Future<void> deleteProject(int id) async {
    final response = await _client.delete(_uri('/projects/$id'));
    _throwIfNotOk(response);
  }

  Future<String> startScrape(ScrapeRequestModel request) async {
    final response = await _client.post(
      _uri('/scrape/play-store'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    _throwIfNotOk(response);
    final body = _decodeMap(response.body);
    final jobId = body['job_id']?.toString();
    if (jobId == null || jobId.isEmpty) {
      throw const FormatException('Missing job_id in scrape response');
    }
    return jobId;
  }

  Future<Map<String, dynamic>> getScrapeStatus({String? jobId}) async {
    final response = await _client.get(
      _uri('/scrape/status', {'job_id': jobId}),
    );
    _throwIfNotOk(response);
    return _decodeMap(response.body);
  }

  static List<Map<String, dynamic>> _decodeList(String body) {
    final parsed = jsonDecode(body);
    if (parsed is! List) {
      throw const FormatException('Expected a JSON list');
    }
    return parsed.map((item) => Map<String, dynamic>.from(item as Map)).toList(growable: false);
  }

  static Map<String, dynamic> _decodeMap(String body) {
    final parsed = jsonDecode(body);
    if (parsed is! Map) {
      throw const FormatException('Expected a JSON object');
    }
    return Map<String, dynamic>.from(parsed);
  }

  static void _throwIfNotOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw HttpException(
      'HTTP ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

class HttpException implements Exception {
  const HttpException(this.message, {required this.statusCode, required this.body});

  final String message;
  final int statusCode;
  final String body;

  @override
  String toString() => message;
}
