import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kodi_core/kodi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config.dart';
import '../../../shared/widgets/math_text.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key, this.tag, this.tagName, this.nodeId, this.embedded = false});
  final String? tag;
  final String? tagName;
  final String? nodeId;
  final bool embedded;
  static const routeName = '/practice';
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> with TickerProviderStateMixin {
  late final NisApiClient _api;
  Problem? _problem;
  AnswerResult? _result;
  bool _loading = true;
  int _count = 1;
  int _correct = 0;
  int _combo = 0;
  int _bestCombo = 0;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  // Timer
  late Stopwatch _stopwatch;
  Timer? _tickTimer;
  int _elapsedSeconds = 0;
  double _totalTimeSpent = 0;

  // Animation
  late AnimationController _resultAnimController;
  late Animation<double> _resultFadeIn;
  late AnimationController _comboAnimController;

  // Keyboard
  final _keyboardFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _api = NisApiClient(baseUrl: AppConfig.apiBaseUrl);
    _stopwatch = Stopwatch();
    _resultAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _resultFadeIn = CurvedAnimation(parent: _resultAnimController, curve: Curves.easeOut);
    _comboAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _init();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _keyboardFocus.dispose();
    _scrollController.dispose();
    _resultAnimController.dispose();
    _comboAnimController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _api.token = prefs.getString('jwt_token');
    await _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() { _loading = true; _result = null; _controller.clear(); });
    try {
      final p = await _api.getNextProblem(count: _count, tag: widget.tag, nodeId: widget.nodeId);
      setState(() { _problem = p; _loading = false; });
      _resultAnimController.reset();
      _startTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _startTimer() {
    _stopwatch.reset(); _stopwatch.start(); _elapsedSeconds = 0;
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
  }

  void _stopTimer() {
    _stopwatch.stop(); _tickTimer?.cancel();
    _totalTimeSpent += _stopwatch.elapsed.inMilliseconds / 1000.0;
  }

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (_problem == null || answer.isEmpty) return;
    _stopTimer();
    setState(() => _loading = true);
    try {
      final res = await _api.submitAnswer(_problem!.problemId, answer);
      setState(() {
        _result = res; _loading = false; _count++;
        if (res.isCorrect) {
          _correct++; _combo++;
          if (_combo > _bestCombo) _bestCombo = _combo;
          if (_combo >= 3) _comboAnimController.forward(from: 0);
        } else { _combo = 0; }
      });
      _resultAnimController.forward();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _skip() async {
    if (_problem == null) return;
    _stopTimer(); _combo = 0;
    await _api.skipProblem(_problem!.problemId);
    _count++; await _loadNext();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_result != null && (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.space)) {
      _loadNext();
    }
  }

  String _fmtTime(int s) => s < 60 ? '${s}с' : '${s ~/ 60}м ${s % 60}с';
  String _fmtAvg() {
    if (_count <= 1) return '-';
    return '${(_totalTimeSpent / (_count - 1)).toStringAsFixed(1)}с';
  }

  void _showStats() {
    final n = _count - 1;
    final pct = n > 0 ? (_correct / n * 100).round() : 0;
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Статистика сессии', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(children: [
          _StatTile(label: 'Решено', value: '$n', icon: Icons.check_circle_outline),
          _StatTile(label: 'Правильно', value: '$_correct', icon: Icons.thumb_up_outlined),
          _StatTile(label: 'Точность', value: '$pct%', icon: Icons.percent),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatTile(label: 'Ср. время', value: _fmtAvg(), icon: Icons.timer_outlined),
          _StatTile(label: 'Макс комбо', value: '$_bestCombo 🔥', icon: Icons.local_fire_department),
          _StatTile(label: 'Всего', value: _fmtTime(_totalTimeSpent.round()), icon: Icons.schedule),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Продолжить'))),
      ])));
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocus, autofocus: true, onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        appBar: AppBar(
          backgroundColor: Colors.white, surfaceTintColor: Colors.white, elevation: 0.5,
          leading: const BackButton(),
          title: Row(children: [
            Flexible(child: Text(widget.tagName ?? 'Практика',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), overflow: TextOverflow.ellipsis)),
            const Spacer(),
            if (_result == null && !_loading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _elapsedSeconds > 120 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 14,
                      color: _elapsedSeconds > 120 ? const Color(0xFFEF4444) : Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text(_fmtTime(_elapsedSeconds), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _elapsedSeconds > 120 ? const Color(0xFFEF4444) : Colors.grey[500],
                      fontFeatures: const [FontFeature.tabularFigures()])),
                ])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
              child: Text(_count > 1 ? '$_correct/${_count - 1}' : '0/0',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
          actions: [
            if (_count > 2) IconButton(icon: const Icon(Icons.assessment_rounded, color: Color(0xFF64748B)),
                onPressed: _showStats, tooltip: 'Статистика'),
          ],
        ),
        body: _loading ? const Center(child: CircularProgressIndicator())
            : Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(controller: _scrollController, padding: const EdgeInsets.all(16), child: _buildContent()))),
      ));
  }

  Widget _buildContent() {
    final p = _problem;
    if (p == null) {
      return Center(child: Column(children: [
        const SizedBox(height: 60),
        Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber[400]),
        const SizedBox(height: 16),
        const Text('Все задачи решены! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Попробуй другую тему', style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('На главную')),
      ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Combo
      if (_combo >= 3)
        ScaleTransition(
          scale: Tween(begin: 0.8, end: 1.0).animate(_comboAnimController),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F00)]),
              borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('$_combo подряд!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ]))),

      // Topic + difficulty
      Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
          child: Text(p.nodeName, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis))),
        const SizedBox(width: 8),
        if (p.difficulty != null) _DifficultyDots(level: p.difficulty!),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
          child: Text('#$_count', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 12),

      // Problem card
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Always show text
          if (p.text.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: MathText(p.text, style: const TextStyle(fontSize: 17, height: 1.6, color: Color(0xFF1E293B)))),
          // Show image below (inverted colors for light theme)
        ])),
      const SizedBox(height: 16),

      // Result or input
      if (_result != null)
        FadeTransition(opacity: _resultFadeIn,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(_resultFadeIn),
            child: Column(children: [
              _ResultCard(result: _result!),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _loadNext,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Следующая', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Text('→', style: TextStyle(fontSize: 14, color: Colors.white70)),
                ]),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52), backgroundColor: const Color(0xFF2563EB)))),
              const SizedBox(height: 8),
              Text('Нажми → или пробел', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ])))
      else ...[
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Ваш ответ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              const Spacer(),
              Text('Enter — ответить', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _controller, focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Введите ответ...',
                filled: true, fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)), onPressed: _submit)),
              style: const TextStyle(fontSize: 16),
              onSubmitted: (_) => _submit()),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton(onPressed: _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48), backgroundColor: const Color(0xFF2563EB)),
                child: const Text('Ответить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
              const SizedBox(width: 10),
              SizedBox(height: 48, child: OutlinedButton(onPressed: _skip,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: const Text('Пропустить', style: TextStyle(color: Color(0xFF64748B))))),
            ]),
          ])),
      ],
    ]);
  }
}

class _DifficultyDots extends StatelessWidget {
  const _DifficultyDots({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) => Row(children: List.generate(4, (i) => Container(
    width: 8, height: 8, margin: const EdgeInsets.only(right: 3),
    decoration: BoxDecoration(shape: BoxShape.circle,
      color: i < level ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)))));
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AnswerResult result;
  @override
  Widget build(BuildContext context) {
    final ok = result.isCorrect;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 24),
          const SizedBox(width: 8),
          Text(ok ? 'Правильно! 🎉' : 'Неправильно',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                  color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
          const Spacer(),
          if (result.isMastered)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
              child: const Text('✨ Освоено', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
        if (!ok) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text('Ответ: ', style: TextStyle(color: Colors.grey[500])),
              Expanded(child: Text(result.correctAnswer,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)))),
            ])),
        ],
        if (result.solution != null && result.solution!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💡 Решение:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14)),
              const SizedBox(height: 6),
              Text(result.solution!, style: const TextStyle(color: Color(0xFF475569), height: 1.5, fontSize: 14)),
            ])),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Text('Освоение: ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: result.pMastery, minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                  result.pMastery >= 0.7 ? const Color(0xFF10B981)
                      : result.pMastery >= 0.4 ? const Color(0xFFF59E0B) : const Color(0xFF2563EB))))),
          const SizedBox(width: 8),
          Text('${(result.pMastery * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ]));
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, size: 22, color: const Color(0xFF64748B)),
    const SizedBox(height: 6),
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
  ]));
}
