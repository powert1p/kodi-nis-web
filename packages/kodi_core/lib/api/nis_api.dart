import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/stats.dart';
import '../models/graph_node.dart';
import '../models/problem.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NisApiClient {
  NisApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store',
        'Pragma': 'no-cache',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => _post(path, body);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
        data['detail']?.toString() ?? 'Request failed',
        statusCode: res.statusCode,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
        data['detail']?.toString() ?? 'Request failed',
        statusCode: res.statusCode,
      );
    }
    return data;
  }

  // ── Auth ──────────────────────────────────────────────────────

  Future<String> loginWithTelegram(Map<String, dynamic> tgData) async {
    final res = await _post('/api/auth/telegram', tgData);
    token = res['access_token'] as String;
    return token!;
  }

  Future<Student> getMe() async {
    final res = await _get('/api/auth/me');
    return Student.fromJson(res);
  }

  // ── Stats & Graph ─────────────────────────────────────────────

  Future<Stats> getStats() async {
    final res = await _get('/api/stats/me?lang=ru');
    return Stats.fromJson(res);
  }

  Future<Map<String, dynamic>> getGraphData() async {
    return await _get('/api/graph/me?lang=ru');
  }

  Future<List<GraphNode>> getGraphNodes() async {
    final data = await getGraphData();
    final nodes = data['nodes'] as List<dynamic>;
    return nodes
        .map((n) => GraphNode.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  // ── Practice ──────────────────────────────────────────────────

  Future<Problem> getNextProblem({int count = 1, String? tag, String? nodeId}) async {
    final params = 'count=$count&lang=ru${tag != null ? '&tag=$tag' : ''}${nodeId != null ? '&node_id=$nodeId' : ''}';
    final res = await _get('/api/practice/next?$params');
    return Problem.fromJson(res);
  }

  Future<AnswerResult> submitAnswer(int problemId, String answer) async {
    final res = await _post('/api/practice/answer?lang=ru', {
      'problem_id': problemId,
      'answer': answer,
    });
    return AnswerResult.fromJson(res);
  }

  Future<void> skipProblem(int problemId) async {
    await http.post(
      Uri.parse('$baseUrl/api/practice/skip'),
      headers: _headers,
      body: jsonEncode({'problem_id': problemId, 'answer': ''}),
    );
  }

  // ── Diagnostic ──────────────────────────────────────────────

  Future<Map<String, dynamic>> startDiagnostic({String mode = 'exam'}) async {
    return await _post('/api/diagnostic/start', {'mode': mode});
  }

  Future<Map<String, dynamic>> getDiagnosticQuestion() async {
    return await _get('/api/diagnostic/question');
  }

  Future<Map<String, dynamic>> submitDiagnosticAnswer({
    required int problemId,
    required String answer,
    double elapsedSec = 30.0,
  }) async {
    return await _post('/api/diagnostic/answer', {
      'problem_id': problemId,
      'answer': answer,
      'elapsed_sec': elapsedSec,
    });
  }

  Future<Map<String, dynamic>> finishDiagnostic() async {
    return await _post('/api/diagnostic/finish', {});
  }

  Future<Map<String, dynamic>> getDiagnosticStatus() async {
    return await _get('/api/diagnostic/status');
  }
}