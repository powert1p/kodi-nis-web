import 'package:flutter/material.dart';
import 'package:kodi_core/kodi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});
  static const routeName = '/practice';
  @override State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late final NisApiClient _api;
  Problem? _problem;
  AnswerResult? _result;
  bool _loading = true;
  int _count = 1;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _api = NisApiClient(baseUrl: AppConfig.apiBaseUrl);
    _init();
  }

  @override void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _api.token = prefs.getString('jwt_token');
    await _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() { _loading = true; _result = null; _controller.clear(); });
    try {
      final p = await _api.getNextProblem(count: _count);
      setState(() { _problem = p; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (_problem == null || answer.isEmpty) return;
    setState(() { _loading = true; });
    try {
      final res = await _api.submitAnswer(_problem!.problemId, answer);
      setState(() { _result = res; _loading = false; _count++; });
    } catch (e) {
      setState(() { _loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _skip() async {
    if (_problem == null) return;
    await _api.skipProblem(_problem!.problemId);
    _count++;
    await _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: const BackButton(),
        title: Row(children: [
          const Text('Практика', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
            child: Text('Задача $_count', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildContent()),
            )),
    );
  }

  Widget _buildContent() {
    final p = _problem;
    if (p == null) return const Center(child: Text('Нет доступных задач'));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Topic + difficulty
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
          child: Text(p.nodeName, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        if (p.difficulty != null) _DifficultyDots(level: p.difficulty!),
      ]),
      const SizedBox(height: 16),

      // Problem card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Text(p.text, style: const TextStyle(fontSize: 17, height: 1.6, color: Color(0xFF1E293B))),
      ),
      const SizedBox(height: 20),

      if (_result != null) ...[
        _ResultCard(result: _result!),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loadNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Следующая задача', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52), backgroundColor: const Color(0xFF2563EB)),
          ),
        ),
      ] else ...[
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Ваш ответ...',
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: const TextStyle(fontSize: 16),
          onSubmitted: (_) => _submit(),
          autofocus: true,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52), backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Ответить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _skip,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: const Text('Пропустить', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ),
        ]),
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
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: i < level ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
    ),
  )));
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
        border: Border.all(color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 22),
          const SizedBox(width: 8),
          Text(ok ? 'Правильно! 🎉' : 'Неправильно',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
          if (result.isMastered) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
              child: const Text('Тема освоена', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        if (!ok) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Text('Ответ: ', style: TextStyle(color: Color(0xFF64748B))),
              Text(result.correctAnswer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
            ])),
        ],
        if (result.solution != null) ...[
          const SizedBox(height: 12),
          const Text('💡 Решение:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(result.solution!, style: const TextStyle(color: Color(0xFF475569), height: 1.5)),
        ],
        if (result.llmNote != null) ...[
          const SizedBox(height: 8),
          Text('💬 ${result.llmNote}', style: const TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Text('Освоение темы: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(width: 100, child: LinearProgressIndicator(
              value: result.pMastery, minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(result.pMastery > 0.7 ? const Color(0xFF10B981) : const Color(0xFF2563EB)),
            )),
          ),
          const SizedBox(width: 6),
          Text('${(result.pMastery * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ]),
    );
  }
}
