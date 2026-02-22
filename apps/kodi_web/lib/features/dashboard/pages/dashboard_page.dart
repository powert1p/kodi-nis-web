import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kodi_core/kodi_core.dart';
import '../bloc/dashboard_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../practice/pages/practice_page.dart';
import 'graph_page.dart';
import 'leaderboard_page.dart';
import '../../diagnostic/pages/diagnostic_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  static const routeName = '/';
  @override
  State<DashboardPage> createState() => _DashboardPageState();
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
        backgroundColor: const Color(0xFFFAF9F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          title: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('NIS Math',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          actions: [
            if (state is DashboardLoaded)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(GraphPage.routeName),
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
          DashboardLoading() || DashboardInitial() =>
            const Center(child: CircularProgressIndicator()),
          DashboardError(:final message) => _ErrorView(
              message: message,
              onRetry: () =>
                  context.read<DashboardBloc>().add(DashboardLoad())),
          DashboardLoaded(:final student, :final stats, :final nodes, :final leaderboard) =>
            _Body(student: student, stats: stats, nodes: nodes, leaderboard: leaderboard),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

// ── Error ──────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Повторить')),
        ]),
      );
}

// ── Body ───────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  const _Body(
      {required this.student, required this.stats, required this.nodes, required this.leaderboard});
  final Student student;
  final Stats stats;
  final List<GraphNode> nodes;
  final List<LeaderboardEntry> leaderboard;

  @override
  Widget build(BuildContext context) {
    // Group nodes by tag → build sections
    final byTag = <String, List<GraphNode>>{};
    for (final n in nodes) {
      byTag.putIfAbsent(n.tag, () => []).add(n);
    }

    final sections = byTag.entries.map((e) {
      final tag = e.key;
      final topics = e.value;
      final tested = topics.where((t) => t.pMastery != null).toList();
      final testedCount = tested.length;
      final totalCount = topics.length;
      final avgPct = testedCount > 0
          ? (tested.fold<double>(0, (s, t) => s + (t.pMastery ?? 0)) /
                  testedCount *
                  100)
              .round()
          : 0;
      final mastered =
          topics.where((t) => (t.pMastery ?? 0) >= 0.7).length;
      final failed = topics
          .where((t) => t.pMastery != null && t.pMastery! < 0.7)
          .length;
      final untested = totalCount - testedCount;

      return _SectionData(
        tag: tag,
        nameRu: _sectionNames[tag] ?? tag,
        icon: _sectionIcons[tag] ?? '📘',
        testedCount: testedCount,
        totalCount: totalCount,
        percentage: avgPct,
        barGreen: totalCount > 0 ? mastered / totalCount : 0,
        barRed: totalCount > 0 ? failed / totalCount : 0,
        barGray: totalCount > 0 ? untested / totalCount : 0,
        topics: topics,
      );
    }).toList();

    // Sort: tested sections first by % desc, untested at bottom
    sections.sort((a, b) {
      if (a.testedCount == 0 && b.testedCount > 0) return 1;
      if (a.testedCount > 0 && b.testedCount == 0) return -1;
      return b.percentage.compareTo(a.percentage);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(student: student, stats: stats),
                const SizedBox(height: 16),
                _StatsRow(stats: stats),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(DiagnosticPage.routeName)
                            .then((_) => context.read<DashboardBloc>().add(DashboardLoad())),
                        icon: const Icon(Icons.psychology_rounded, size: 20),
                        label: const Text('Диагностика',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: const Color(0xFF7C3AED)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(PracticePage.routeName)
                            .then((_) => context.read<DashboardBloc>().add(DashboardLoad())),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Практика',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: const Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(LeaderboardPage.routeName,
                                arguments: leaderboard),
                        icon: const Icon(Icons.emoji_events_rounded, size: 20),
                        label: const Text('Рейтинг',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: const Color(0xFFFF8F00)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('РАЗДЕЛЫ',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                ...sections.map((s) => _SectionCard(section: s)),
              ]),
        ),
      ),
    );
  }

  static const _sectionNames = {
    'arithmetic': 'Арифметика',
    'fractions': 'Дроби',
    'decimals': 'Десятичные',
    'divisibility': 'Делимость',
    'equations': 'Уравнения',
    'geometry': 'Геометрия',
    'algebra': 'Алгебра',
    'word_problems': 'Текст. задачи',
    'proportion': 'Пропорции',
    'percent': 'Проценты',
    'numbers': 'Числа',
    'conversion': 'Ед. измерения',
    'logic': 'Логика',
    'sets': 'Множества',
    'data': 'Данные',
  };

  static const _sectionIcons = {
    'arithmetic': '🔢',
    'fractions': '🍕',
    'decimals': '🔟',
    'divisibility': '➗',
    'equations': '⚖️',
    'geometry': '📐',
    'algebra': '🔤',
    'word_problems': '📝',
    'proportion': '🏗️',
    'percent': '📊',
    'numbers': '🔢',
    'conversion': '📏',
    'logic': '🧩',
    'sets': '🔵',
    'data': '📈',
  };
}

// ── Section data ──────────────────────────────────────────────
class _SectionData {
  const _SectionData({
    required this.tag,
    required this.nameRu,
    required this.icon,
    required this.testedCount,
    required this.totalCount,
    required this.percentage,
    required this.barGreen,
    required this.barRed,
    required this.barGray,
    required this.topics,
  });

  final String tag, nameRu, icon;
  final int testedCount, totalCount, percentage;
  final double barGreen, barRed, barGray;
  final List<GraphNode> topics;
}

// ── Section Card ──────────────────────────────────────────────
class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.section});
  final _SectionData section;
  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  Color _pctColor(int pct) {
    if (pct >= 75) return const Color(0xFF4CAF50);
    if (pct >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final pctColor = s.testedCount > 0
        ? _pctColor(s.percentage)
        : Colors.grey[400]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Column(
        children: [
          // ── Header (tappable) ────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Icon
                      Text(s.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      // Name + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.nameRu,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.testedCount > 0
                                  ? '${s.testedCount} из ${s.totalCount} проверено'
                                  : '${s.totalCount} тем',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      // Percentage
                      if (s.testedCount > 0)
                        Text(
                          '${s.percentage}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: pctColor,
                          ),
                        ),
                      const SizedBox(width: 8),
                      // Arrow
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down,
                            color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ── 3-segment progress bar ──────────────
                  _ThreeSegmentBar(
                    green: s.barGreen,
                    red: s.barRed,
                    gray: s.barGray,
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded topics ──────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _TopicsList(topics: s.topics),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

// ── 3-Segment Progress Bar ────────────────────────────────────
class _ThreeSegmentBar extends StatelessWidget {
  const _ThreeSegmentBar({
    required this.green,
    required this.red,
    required this.gray,
  });
  final double green, red, gray;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (green > 0)
              Expanded(
                flex: (green * 1000).round(),
                child: Container(color: const Color(0xFF4CAF50)),
              ),
            if (red > 0)
              Expanded(
                flex: (red * 1000).round(),
                child: Container(color: const Color(0xFFF44336)),
              ),
            if (gray > 0)
              Expanded(
                flex: (gray * 1000).round(),
                child: Container(color: const Color(0xFFE0E0E0)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Topics List (expanded) ────────────────────────────────────
class _TopicsList extends StatelessWidget {
  const _TopicsList({required this.topics});
  final List<GraphNode> topics;

  Color _dotColor(GraphNode n) {
    final pct = ((n.pMastery ?? 0) * 100).round();
    if (n.pMastery == null) return Colors.grey[300]!;
    if (pct >= 75) return const Color(0xFF4CAF50);
    if (pct >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    // Sort topics: tested first by mastery desc, untested at bottom
    final sorted = List<GraphNode>.from(topics)
      ..sort((a, b) {
        if (a.pMastery == null && b.pMastery != null) return 1;
        if (a.pMastery != null && b.pMastery == null) return -1;
        return (b.pMastery ?? 0).compareTo(a.pMastery ?? 0);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          const Divider(height: 1),
          ...sorted.map((t) {
            final pct = t.pMastery != null
                ? ((t.pMastery! * 100).round())
                : null;
            final color = _dotColor(t);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  // Colored dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  // Topic name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.nameRu,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (t.pMastery != null)
                          Text(
                            'оценка по связям',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                      ],
                    ),
                  ),
                  // Percentage
                  if (pct != null)
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  if (pct == null)
                    Text('—',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[300])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.student, required this.stats});
  final Student student;
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final pct = stats.masteryPercent;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Привет, ${student.displayName.split(' ').first}! 👋',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Твой прогресс',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                    '${stats.masteredCount} из ${stats.totalNodes} тем освоено',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ]),
        ),
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
        width: 80,
        height: 80,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: const Size(80, 80), painter: _RingPainter(percent)),
          Text('${(percent * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.percent);
  final double percent;
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    final fg = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * percent, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.percent != percent;
}

// ── Stats Row ─────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Stats stats;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatCard(
              label: 'Освоено',
              value: '${stats.masteredCount}/${stats.totalNodes}',
              icon: Icons.school_rounded,
              color: const Color(0xFF10B981)),
          _StatCard(
              label: 'Решено',
              value: '${stats.solved}',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF2563EB)),
          _StatCard(
              label: 'Точность',
              value: '${stats.accuracy}%',
              icon: Icons.analytics_outlined,
              color: const Color(0xFFF59E0B)),
          _StatCard(
              label: 'Ср. время',
              value: '${stats.avgTimeS.toStringAsFixed(0)}с',
              icon: Icons.timer_outlined,
              color: const Color(0xFF8B5CF6)),
        ],
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
      );
}
