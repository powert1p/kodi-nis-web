import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kodi_core/kodi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});
  static const routeName = '/exam';

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late final NisApiClient _api;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  bool _started = false;
  bool _finished = false;
  String? _error;

  // Exam config
  int _numProblems = 20;
  int _timeMinutes = 40;

  // Problems
  List<Map<String, dynamic>> _problems = [];
  int _currentIndex = 0;
  Map<String, dynamic>? _answerResult;

  // Timer
  int _secondsLeft = 0;
  Timer? _timer;

  // Results
  int _correct = 0;
  int _answered = 0;
  final Map<int, bool> _results = {}; // problem_id → correct

  @override
  void initState() {
    super.initState();
    _api = NisApiClient(baseUrl: AppConfig.apiBaseUrl);
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _api.token = prefs.getString('jwt_token');
  }

  Future<void> _startExam() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _api.post('/api/practice/exam/start', {
        'num_problems': _numProblems,
        'time_minutes': _timeMinutes,
      });
      final problems = (resp['problems'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _problems = problems;
        _started = true;
        _loading = false;
        _currentIndex = 0;
        _correct = 0;
        _answered = 0;
        _results.clear();
        _answerResult = null;
        _secondsLeft = _timeMinutes * 60;
      });
      _startTimer();
      _focusAnswer();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        _finishExam();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _focusAnswer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _submitAnswer() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty || _currentIndex >= _problems.length) return;

    final problem = _problems[_currentIndex];
    setState(() => _loading = true);

    try {
      final result = await _api.post('/api/practice/answer', {
        'problem_id': problem['problem_id'],
        'answer': answer,
      });
      final isCorrect = result['is_correct'] == true;
      _results[problem['problem_id']] = isCorrect;
      if (isCorrect) _correct++;
      _answered++;

      setState(() {
        _answerResult = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _nextProblem() {
    if (_currentIndex + 1 >= _problems.length) {
      _finishExam();
      return;
    }
    setState(() {
      _currentIndex++;
      _answerResult = null;
      _controller.clear();
    });
    _focusAnswer();
  }

  void _skipProblem() {
    _answered++;
    final problem = _problems[_currentIndex];
    _results[problem['problem_id']] = false;
    _nextProblem();
  }

  void _finishExam() {
    _timer?.cancel();
    setState(() {
      _finished = true;
      _started = false;
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
          const Text('Экзамен',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (_started) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _secondsLeft < 300
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_rounded,
                    size: 16,
                    color: _secondsLeft < 300
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_secondsLeft),
                  style: TextStyle(
                    color: _secondsLeft < 300
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF2563EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ]),
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
    if (_error != null) return _buildError();
    if (_finished) return _buildResults();
    if (!_started) return _buildSetup();
    if (_answerResult != null) return _buildAnswerFeedback();
    return _buildQuestion();
  }

  // ── Setup screen ──────────────────────────────────────────
  Widget _buildSetup() {
    return Column(children: [
      const SizedBox(height: 40),
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.timer_rounded, color: Colors.white, size: 44),
      ),
      const SizedBox(height: 24),
      const Text('Экзамен',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B))),
      const SizedBox(height: 8),
      Text('Реши задачи на время — как на настоящем НИШ',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),

      // Config card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Настройки', style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),

          // Number of problems
          Row(children: [
            const Icon(Icons.assignment_rounded, size: 20, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            const Text('Задач:'),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 10, label: Text('10')),
                ButtonSegment(value: 20, label: Text('20')),
                ButtonSegment(value: 30, label: Text('30')),
              ],
              selected: {_numProblems},
              onSelectionChanged: (v) => setState(() {
                _numProblems = v.first;
                _timeMinutes = v.first * 2; // 2 min per problem
              }),
              style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: const Color(0xFF2563EB),
                  selectedForegroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 12),

          // Time
          Row(children: [
            const Icon(Icons.timer_rounded, size: 20, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            const Text('Время:'),
            const Spacer(),
            Text('$_timeMinutes мин',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ]),
        ]),
      ),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _startExam,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Начать экзамен',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: const Color(0xFFEF4444)),
        ),
      ),
    ]);
  }

  // ── Question ──────────────────────────────────────────────
  Widget _buildQuestion() {
    final p = _problems[_currentIndex];
    final imagePath = p['image_path'] as String?;
    final text = p['text'] as String? ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Progress
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _problems.isNotEmpty ? (_currentIndex + 1) / _problems.length : 0,
          minHeight: 6,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFEF4444)),
        ),
      ),
      const SizedBox(height: 4),
      Row(children: [
        Text('Задача ${_currentIndex + 1} из ${_problems.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const Spacer(),
        Text('$_correct правильно',
            style: const TextStyle(fontSize: 12, color: Color(0xFF10B981),
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 16),

      // Topic badge
      if (p['node_name'] != null && (p['node_name'] as String).isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8)),
          child: Text(p['node_name'],
              style: const TextStyle(color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      const SizedBox(height: 12),

      // Problem card
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          if (imagePath != null && imagePath.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network('${AppConfig.apiBaseUrl}/$imagePath',
                  width: double.infinity, fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          if (imagePath == null || imagePath.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(text, style: const TextStyle(fontSize: 17, height: 1.6)),
            ),
        ]),
      ),
      const SizedBox(height: 16),

      // Answer
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
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
                  borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(fontSize: 16),
            onSubmitted: (_) => _submitAnswer(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _skipProblem,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Пропустить'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _submitAnswer,
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: const Color(0xFFEF4444)),
                child: const Text('Ответить',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  // ── Answer feedback (brief) ───────────────────────────────
  Widget _buildAnswerFeedback() {
    final r = _answerResult!;
    final ok = r['is_correct'] == true;

    return Column(children: [
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
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ok ? 'Правильно!' : 'Неправильно',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                if (!ok && r['correct_answer'] != null)
                  Text('Ответ: ${r['correct_answer']}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
              ])),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _nextProblem,
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: const Color(0xFF2563EB)),
          child: Text(
            _currentIndex + 1 >= _problems.length ? 'Завершить' : 'Следующая →',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  // ── Results ───────────────────────────────────────────────
  Widget _buildResults() {
    final total = _problems.length;
    final pct = total > 0 ? (_correct / total * 100).round() : 0;
    final timeUsed = _timeMinutes * 60 - _secondsLeft;

    return Column(children: [
      const SizedBox(height: 20),
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: pct >= 70 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          pct >= 70 ? Icons.emoji_events_rounded : Icons.assessment_rounded,
          color: Colors.white, size: 44),
      ),
      const SizedBox(height: 24),
      Text(pct >= 70 ? 'Отлично!' : 'Можно лучше!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B))),
      const SizedBox(height: 8),
      Text('Время: ${_formatTime(timeUsed)}',
          style: TextStyle(fontSize: 15, color: Colors.grey[600])),
      const SizedBox(height: 24),

      Row(children: [
        _StatCard(label: 'Результат', value: '$pct%',
            color: pct >= 70 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
        const SizedBox(width: 10),
        _StatCard(label: 'Правильно', value: '$_correct/$total',
            color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        _StatCard(label: 'Пропущено', value: '${total - _answered}',
            color: const Color(0xFF64748B)),
      ]),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => setState(() {
            _finished = false;
            _started = false;
            _problems.clear();
          }),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Ещё раз',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: const Color(0xFFEF4444)),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.home_rounded),
          label: const Text('На главную', style: TextStyle(fontSize: 16)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
        ),
      ),
    ]);
  }

  Widget _buildError() {
    return Column(children: [
      const SizedBox(height: 40),
      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
      const SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => setState(() => _error = null),
          child: const Text('Назад')),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
    ));
  }
}
