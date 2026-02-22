import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kodi_core/kodi_core.dart';
import '../bloc/dashboard_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../practice/pages/practice_page.dart';
import 'graph_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  static const routeName = '/';
  @override State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(DashboardLoad());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('NIS Math', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          actions: [
            if (state is DashboardLoaded)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(GraphPage.routeName),
                  icon: const Icon(Icons.hub_rounded, size: 18),
                  label: const Text('Граф'),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20),
              onPressed: () => context.read<AuthBloc>().add(AuthLogout()),
              tooltip: 'Выйти',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: switch (state) {
          DashboardLoading() || DashboardInitial() => const Center(child: CircularProgressIndicator()),
          DashboardError(:final message) => _ErrorView(message: message, onRetry: () => context.read<DashboardBloc>().add(DashboardLoad())),
          DashboardLoaded(:final student, :final stats, :final nodes) => _Body(student: student, stats: stats, nodes: nodes),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
    const SizedBox(height: 16),
    Text(message, textAlign: TextAlign.center),
    const SizedBox(height: 16),
    FilledButton(onPressed: onRetry, child: const Text('Повторить')),
  ]));
}

class _Body extends StatelessWidget {
  const _Body({required this.student, required this.stats, required this.nodes});
  final Student student; final Stats stats; final List<GraphNode> nodes;

  @override
  Widget build(BuildContext context) {
    final lang = student.lang;
    final byTag = <String, List<GraphNode>>{};
    for (final n in nodes) { byTag.putIfAbsent(n.tag, () => []).add(n); }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _HeroCard(student: student, stats: stats),
            const SizedBox(height: 20),
            _StatsRow(stats: stats),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(PracticePage.routeName),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Начать практику', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: const Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Темы по категориям', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            ...byTag.entries.map((e) => _CategoryCard(tag: e.key, nodes: e.value, lang: lang)),
          ]),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.student, required this.stats});
  final Student student; final Stats stats;

  @override
  Widget build(BuildContext context) {
    final pct = stats.masteryPercent;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Привет, ${student.displayName.split(' ').first}! 👋',
            style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Твой прогресс', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('${stats.masteredCount} из ${stats.totalNodes} тем освоено',
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct, minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ])),
        const SizedBox(width: 20),
        _RingChart(percent: pct),
      ]),
    );
  }
}

class _RingChart extends StatelessWidget {
  const _RingChart({required this.percent});
  final double percent;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80, height: 80,
    child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(80, 80), painter: _RingPainter(percent)),
      Text('${(percent * 100).toStringAsFixed(0)}%',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ]),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.percent);
  final double percent;
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white.withValues(alpha: 0.2)..strokeWidth = 8..style = PaintingStyle.stroke;
    final fg = Paint()..color = Colors.white..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * percent, false, fg);
  }
  @override bool shouldRepaint(_RingPainter old) => old.percent != percent;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Stats stats;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final cards = [
      _StatCard(label: 'Освоено тем', value: '${stats.masteredCount}/${stats.totalNodes}', icon: Icons.school_rounded, color: const Color(0xFF10B981)),
      _StatCard(label: 'Задач решено', value: '${stats.solved}', icon: Icons.check_circle_outline, color: const Color(0xFF2563EB)),
      _StatCard(label: 'Точность', value: '${stats.accuracy}%', icon: Icons.analytics_outlined, color: const Color(0xFFF59E0B)),
      _StatCard(label: 'Ср. время', value: '${stats.avgTimeS.toStringAsFixed(0)}с', icon: Icons.timer_outlined, color: const Color(0xFF8B5CF6)),
    ];
    return Wrap(spacing: 12, runSpacing: 12, children: cards);
  });
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label, value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 200,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 24)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ])),
    ]),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.tag, required this.nodes, required this.lang});
  final String tag; final List<GraphNode> nodes; final String lang;

  static const _tagLabels = {
    'arithmetic': 'Арифметика', 'fractions': 'Дроби', 'algebra': 'Алгебра',
    'geometry': 'Геометрия', 'word_problems': 'Текстовые задачи',
    'number_theory': 'Теория чисел', 'combinatorics': 'Комбинаторика',
    'probability': 'Вероятность', 'statistics': 'Статистика',
    'equations': 'Уравнения', 'decimals': 'Десятичные дроби',
    'ratios': 'Пропорции и проценты', 'modulus': 'Модуль числа',
    'sequences': 'Последовательности', 'sets': 'Множества',
    'negative': 'Отрицательные числа', 'rounding': 'Округление',
    'measurement': 'Единицы измерения', 'data_analysis': 'Анализ данных',
    'divisibility': 'Делимость', 'logic': 'Логика',
  };

  @override
  Widget build(BuildContext context) {
    final mastered = nodes.where((n) => n.status == 'mastered').length;
    final partial = nodes.where((n) => n.status == 'partial').length;
    final pct = nodes.isEmpty ? 0.0 : mastered / nodes.length;
    final label = _tagLabels[tag] ?? tag;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          const SizedBox(width: 8),
          Text('$mastered/${nodes.length}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(pct > 0.7 ? const Color(0xFF10B981) : pct > 0.3 ? const Color(0xFFF59E0B) : const Color(0xFF2563EB)),
            ),
          ),
        ),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: nodes.map((n) => _TopicBadge(node: n, lang: lang)).toList()),
        ],
      ),
    );
  }
}

class _TopicBadge extends StatelessWidget {
  const _TopicBadge({required this.node, required this.lang});
  final GraphNode node; final String lang;
  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (node.status) {
      'mastered' => (const Color(0xFF10B981), const Color(0xFFECFDF5)),
      'partial'  => (const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
      'failed'   => (const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      _          => (const Color(0xFF94A3B8), const Color(0xFFF8FAFC)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(node.name(lang), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
