import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kodi_core/kodi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config.dart';

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});
  static const routeName = '/diagnostic';

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  late final NisApiClient _api;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // State
  bool _loading = true;
  bool _started = false;
  bool _finished = false;
  String? _error;

  // Current question
  Map<String, dynamic>? _question;
  Map<String, dynamic>? _answerResult;

  // Progress
  int _phase = 1;
  int _questionsAsked = 0;
  int _topicsTested = 0;
  int _maxTopics = 10;
  int _correctCount = 0;

  // Timer
  late Stopwatch _stopwatch;

  // Finish results
  Map<String, dynamic>? _results;

  @override
  void initState() {
    super.initState();
    _api = NisApiClient(baseUrl: AppConfig.apiBaseUrl);
    _stopwatch = Stopwatch();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _api.token = prefs.getString('jwt_token');
    setState(() => _loading = false);
  }

  Future<void> _startDiagnostic(int phase) async {
    setState(() {
      _loading = true;
      _error = null;
      _phase = phase;
      _started = true;
      _finished = false;
      _correctCount = 0;
      _results = null;
    });
    try {
      final q = await _api.startDiagnostic(phase: phase);
      _handleQuestion(q);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _handleQuestion(Map<String, dynamic> q) {
    if (q['finished'] == true) {
      _finishDiagnostic();
      return;
    }
    setState(() {
      _question = q;
      _answerResult = null;
      _loading = false;
      _questionsAsked = q['questions_asked'] ?? 0;
      _topicsTested = q['topics_tested'] ?? 0;
      _maxTopics = q['max_topics'] ?? 10;
      _controller.clear();
    });
    _stopwatch.reset();
    _stopwatch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _submitAnswer() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty || _question == null) return;

    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;

    setState(() => _loading = true);
    try {
      final result = await _api.submitDiagnosticAnswer(
        problemId: _question!['problem_id'],
        answer: answer,
        elapsedSec: elapsed,
      );
      setState(() {
        _answerResult = result;
        _loading = false;
        _questionsAsked = result['questions_asked'] ?? _questionsAsked;
        _topicsTested = result['topics_tested'] ?? _topicsTested;
        if (result['is_correct'] == true) _correctCount++;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _nextQuestion() async {
    setState(() => _loading = true);
    try {
      final q = await _api.getDiagnosticQuestion();
      _handleQuestion(q);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _finishDiagnostic() async {
    setState(() => _loading = true);
    try {
      final result = await _api.finishDiagnostic();
      setState(() {
        _finished = true;
        _results = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(),
        title: Row(children: [
          const Text('Диагностика',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (_started && !_finished) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                'Фаза $_phase · $_topicsTested/$_maxTopics',
                style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildContent(),
                ),
              ),
            ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _buildError();
    }
    if (_finished) {
      return _buildResults();
    }
    if (!_started) {
      return _buildStart();
    }
    if (_answerResult != null) {
      return _buildAnswerResult();
    }
    if (_question != null) {
      return _buildQuestion();
    }
    return const SizedBox.shrink();
  }

  // ── Start screen ──────────────────────────────────────────
  Widget _buildStart() {
    return Column(children: [
      const SizedBox(height: 40),
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.psychology_rounded,
            color: Colors.white, size: 44),
      ),
      const SizedBox(height: 24),
      const Text('Диагностика знаний',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      Text(
        'Система определит твой уровень по 118 темам математики.\n'
        'Адаптивный алгоритм подберёт задачи под тебя.',
        style: TextStyle(
            fontSize: 15, color: Colors.grey[600], height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      _PhaseCard(
        phase: 1,
        title: 'Фаза 1: Тест на пробелы',
        subtitle: '10 тем · 5-10 минут',
        description: 'Быстрый скан основных разделов',
        icon: Icons.flash_on_rounded,
        color: const Color(0xFF2563EB),
        onStart: () => _startDiagnostic(1),
      ),
      const SizedBox(height: 12),
      _PhaseCard(
        phase: 2,
        title: 'Фаза 2: Глубокий тест',
        subtitle: '40 тем · 20-30 минут',
        description: 'Детальная проверка всех областей',
        icon: Icons.explore_rounded,
        color: const Color(0xFF7C3AED),
        onStart: () => _startDiagnostic(2),
      ),
    ]);
  }

  // ── Question ──────────────────────────────────────────────
  Widget _buildQuestion() {
    final q = _question!;
    final imagePath = q['image_path'] as String?;
    final text = q['text'] as String? ?? '';

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _maxTopics > 0 ? _topicsTested / _maxTopics : 0,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text('Тема ${_topicsTested + 1} из $_maxTopics',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const Spacer(),
            Text('$_correctCount правильно',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),

          // Topic + difficulty
          if (q['node_name'] != null && (q['node_name'] as String).isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(q['node_name'],
                  style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          const SizedBox(height: 12),

          // Problem card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                if (imagePath != null && imagePath.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: Image.network(
                      '${AppConfig.apiBaseUrl}/$imagePath',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (imagePath == null || imagePath.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(text,
                        style: const TextStyle(
                            fontSize: 17, height: 1.6)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Answer input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Ответ...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF2563EB), width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 16),
                  onSubmitted: (_) => _submitAnswer(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitAnswer,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: const Color(0xFF2563EB)),
                    child: const Text('Ответить',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ]);
  }

  // ── Answer result ─────────────────────────────────────────
  Widget _buildAnswerResult() {
    final r = _answerResult!;
    final ok = r['is_correct'] == true;

    return Column(children: [
      // Same progress bar
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _maxTopics > 0 ? _topicsTested / _maxTopics : 0,
          minHeight: 6,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
        ),
      ),
      const SizedBox(height: 16),

      // Result card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 24),
            const SizedBox(width: 8),
            Text(ok ? 'Правильно! 🎉' : 'Неправильно',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: ok
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444))),
          ]),
          if (!ok && r['correct_answer'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Text('Ответ: ',
                    style: TextStyle(color: Colors.grey[500])),
                Text('${r['correct_answer']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ],
          if (r['solution'] != null &&
              (r['solution'] as String).isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 Решение:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('${r['solution']}',
                      style: const TextStyle(
                          color: Color(0xFF475569), height: 1.5)),
                ],
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: r['has_next'] == true ? _nextQuestion : _finishDiagnostic,
          icon: Icon(r['has_next'] == true
              ? Icons.arrow_forward_rounded
              : Icons.flag_rounded),
          label: Text(
              r['has_next'] == true ? 'Следующая' : 'Завершить',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: const Color(0xFF2563EB)),
        ),
      ),
    ]);
  }

  // ── Results ───────────────────────────────────────────────
  Widget _buildResults() {
    final r = _results ?? {};
    final mastered = (r['mastered_nodes'] as List?)?.length ?? 0;
    final failed = (r['failed_nodes'] as List?)?.length ?? 0;
    final summary = r['summary'] as String? ?? '';

    return Column(children: [
      const SizedBox(height: 20),
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.check_rounded,
            color: Colors.white, size: 44),
      ),
      const SizedBox(height: 24),
      const Text('Диагностика завершена!',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B))),
      const SizedBox(height: 8),
      Text(summary,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),

      // Stats cards
      Row(children: [
        _ResultStat(
            label: 'Освоено', value: '$mastered', color: const Color(0xFF10B981)),
        const SizedBox(width: 10),
        _ResultStat(
            label: 'Пробелы', value: '$failed', color: const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        _ResultStat(
            label: 'Правильно',
            value: '$_correctCount/${r['topics_tested'] ?? _topicsTested}',
            color: const Color(0xFF2563EB)),
      ]),
      const SizedBox(height: 24),

      // Actions
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.home_rounded),
          label: const Text('На главную',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: const Color(0xFF2563EB)),
        ),
      ),
      if (_phase == 1) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _startDiagnostic(2),
            icon: const Icon(Icons.explore_rounded),
            label: const Text('Начать Фазу 2',
                style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52)),
          ),
        ),
      ],
    ]);
  }

  // ── Error ─────────────────────────────────────────────────
  Widget _buildError() {
    return Column(children: [
      const SizedBox(height: 40),
      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
      const SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(
          onPressed: () => setState(() => _error = null),
          child: const Text('Назад')),
    ]);
  }
}

// ── Phase card ──────────────────────────────────────────────
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phase,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.onStart,
  });

  final int phase;
  final String title, subtitle, description;
  final IconData icon;
  final Color color;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],
          ),
        ),
        FilledButton(
          onPressed: onStart,
          style: FilledButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 16)),
          child: const Text('Начать'),
        ),
      ]),
    );
  }
}

// ── Result stat card ────────────────────────────────────────
class _ResultStat extends StatelessWidget {
  const _ResultStat(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
      ),
    );
  }
}
