import 'package:flutter/material.dart';
import 'package:kodi_core/kodi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});
  static const routeName = '/practice';

  @override
  State<PracticePage> createState() => _PracticePageState();
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

  @override
  void dispose() {
    _controller.dispose();
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
      final p = await _api.getNextProblem(count: _count);
      setState(() { _problem = p; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
      appBar: AppBar(
        title: Text('Практика · Задача $_count'),
        leading: const BackButton(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final problem = _problem;
    if (problem == null) {
      return const Center(child: Text('Нет доступных задач'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic
        Chip(
          label: Text(problem.nodeName),
          backgroundColor: const Color(0xFFEFF6FF),
          side: const BorderSide(color: Color(0xFF2563EB), width: .5),
        ),
        const SizedBox(height: 16),

        // Problem card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              problem.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Result or input
        if (_result != null) ...[
          _ResultCard(result: _result!),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Следующая задача'),
            ),
          ),
        ] else ...[
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Ваш ответ',
              border: OutlineInputBorder(),
              hintText: 'Введите ответ и нажмите Enter',
            ),
            onSubmitted: (_) => _submit(),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Ответить'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _skip,
                child: const Text('Пропустить'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Result card ───────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AnswerResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.isCorrect;
    return Card(
      color: ok ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Text(
                  ok ? 'Правильно!' : 'Неправильно',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ok
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
                if (result.isMastered) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('Тема освоена 🎉'),
                    backgroundColor: Color(0xFFECFDF5),
                  ),
                ],
              ],
            ),
            if (!ok) ...[
              const SizedBox(height: 8),
              Text('Правильный ответ: ${result.correctAnswer}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
            if (result.solution != null) ...[
              const SizedBox(height: 12),
              const Text('💡 Решение:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(result.solution!),
            ],
            if (result.llmNote != null) ...[
              const SizedBox(height: 8),
              Text('💬 ${result.llmNote}',
                  style: TextStyle(color: Colors.grey[600])),
            ],
            const SizedBox(height: 8),
            Text(
              'Освоение темы: ${(result.pMastery * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
