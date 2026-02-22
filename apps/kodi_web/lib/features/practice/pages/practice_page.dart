import 'package:flutter/material.dart';
import 'package:kodi_core/kodi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config.dart';

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

class _PracticePageState extends State<PracticePage> {
  late final NisApiClient _api;
  Problem? _problem;
  AnswerResult? _result;
  bool _loading = true;
  int _count = 1;
  int _correct = 0;
  final _controller = TextEditingController();
  static const _sessionLimit = 10;
  bool _sessionDone = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _api = NisApiClient(baseUrl: AppConfig.apiBaseUrl);
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
    await _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _result = null;
      _controller.clear();
    });
    try {
      final p = await _api.getNextProblem(count: _count, tag: widget.tag, nodeId: widget.nodeId);
      setState(() {
        _problem = p;
        _loading = false;
      });
      // Focus text field after load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (_problem == null || answer.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await _api.submitAnswer(_problem!.problemId, answer);
      setState(() {
        _result = res;
        _loading = false;
        _count++;
        if (res.isCorrect) _correct++;
        if (_count > _sessionLimit) _sessionDone = true;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(),
        title: Row(children: [
          Text(widget.tagName ?? 'Практика',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          // Score badge
          if (_count > 1)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$_correct/${_count - 1}',
                  style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessionDone
              ? _buildSessionSummary()
              : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildContent()),
              ),
            ),
    );
  }

  Widget _buildContent() {
    final p = _problem;
    if (p == null) {
      return const Center(child: Text('Нет доступных задач'));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic + difficulty row
          Row(children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(p.nodeName,
                    style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            if (p.difficulty != null) _DifficultyDots(level: p.difficulty!),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('# $_count',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),

          // Problem card with image
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image (if available)
                if (p.imagePath != null && p.imagePath!.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      '${AppConfig.apiBaseUrl}/${p.imagePath}',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        height: 100,
                        alignment: Alignment.center,
                        color: const Color(0xFFF8FAFC),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported,
                                color: Colors.grey[400]),
                            const SizedBox(height: 4),
                            Text('Изображение недоступно',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Text (always show if no image, or as supplement)
                if (p.imagePath == null || p.imagePath!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(p.text,
                        style: const TextStyle(
                            fontSize: 17,
                            height: 1.6,
                            color: Color(0xFF1E293B))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Result or input
          if (_result != null) ...[
            _ResultCard(result: _result!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadNext,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Следующая',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: const Color(0xFF2563EB)),
              ),
            ),
          ] else ...[
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
                  Text('Ваш ответ',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Введите ответ...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: const Color(0xFF2563EB)),
                        child: const Text('Ответить',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _skip,
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                        child: const Text('Пропустить',
                            style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ]);
  }

  Widget _buildSessionSummary() {
    final pct = _count > 1 ? (_correct / (_count - 1) * 100).round() : 0;
    final color = pct >= 80
        ? const Color(0xFF10B981)
        : pct >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  pct >= 80 ? Icons.emoji_events_rounded : Icons.trending_up_rounded,
                  color: color,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                pct >= 80 ? 'Отличная работа! 🎉' : pct >= 60 ? 'Хороший результат! 💪' : 'Продолжай стараться! 📚',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SummaryChip(label: 'Решено', value: '${_count - 1}', color: const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _SummaryChip(label: 'Правильно', value: '$_correct', color: const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _SummaryChip(label: 'Точность', value: '$pct%', color: color),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _sessionDone = false;
                      _count = 1;
                      _correct = 0;
                    });
                    _loadNext();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Ещё 10 задач',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: const Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('На главную'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}



// ── Difficulty dots ───────────────────────────────────────────
class _DifficultyDots extends StatelessWidget {
  const _DifficultyDots({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) => Row(
      children: List.generate(
          4,
          (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < level
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                ),
              )));
}

// ── Result card ───────────────────────────────────────────────
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
        border: Border.all(
            color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              ok
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
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
          const Spacer(),
          if (result.isMastered)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('✨ Освоено',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
        if (!ok) ...[
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Text('Ответ: ',
                    style: TextStyle(color: Colors.grey[500])),
                Expanded(
                  child: Text(result.correctAnswer,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B))),
                ),
              ])),
        ],
        if (result.solution != null && result.solution!.isNotEmpty) ...[
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
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        fontSize: 14)),
                const SizedBox(height: 6),
                Text(result.solution!,
                    style: const TextStyle(
                        color: Color(0xFF475569),
                        height: 1.5,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        // Mastery bar
        Row(children: [
          Text('Освоение: ',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: result.pMastery,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                    result.pMastery >= 0.7
                        ? const Color(0xFF10B981)
                        : result.pMastery >= 0.4
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(result.pMastery * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ]),
    );
  }

}
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
      );
}

