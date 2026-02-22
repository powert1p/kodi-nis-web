import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kodi_core/kodi_core.dart';
import '../bloc/dashboard_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../practice/pages/practice_page.dart';

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
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('NIS Math'),
            actions: [
              if (state is DashboardLoaded)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      state.student.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Выйти',
                onPressed: () =>
                    context.read<AuthBloc>().add(AuthLogout()),
              ),
            ],
          ),
          body: switch (state) {
            DashboardLoading() || DashboardInitial() => const Center(
                child: CircularProgressIndicator(),
              ),
            DashboardError(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(message),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          context.read<DashboardBloc>().add(DashboardLoad()),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            DashboardLoaded(:final student, :final stats, :final nodes) =>
              _DashboardBody(student: student, stats: stats, nodes: nodes),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

// ── Body ──────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.student,
    required this.stats,
    required this.nodes,
  });
  final Student student;
  final Stats stats;
  final List<GraphNode> nodes;

  @override
  Widget build(BuildContext context) {
    final lang = student.lang;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats row ───────────────────────────────────
              _StatsRow(stats: stats),
              const SizedBox(height: 32),

              // ── Practice button ─────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushNamed(PracticePage.routeName),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Начать практику'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Topics list ──────────────────────────────────
              Text(
                'Темы',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _TopicGrid(nodes: nodes, lang: lang),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatCard(
          label: 'Освоено тем',
          value: '${stats.masteredCount} / ${stats.totalNodes}',
          icon: Icons.school_rounded,
          color: const Color(0xFF10B981),
        ),
        _StatCard(
          label: 'Решено задач',
          value: '${stats.solved}',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF2563EB),
        ),
        _StatCard(
          label: 'Точность',
          value: '${stats.accuracy}%',
          icon: Icons.analytics_outlined,
          color: const Color(0xFFF59E0B),
        ),
        _StatCard(
          label: 'Прогресс',
          value:
              '${(stats.masteryPercent * 100).toStringAsFixed(0)}%',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Topics grid ───────────────────────────────────────────────

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({required this.nodes, required this.lang});
  final List<GraphNode> nodes;
  final String lang;

  @override
  Widget build(BuildContext context) {
    // Group by tag
    final Map<String, List<GraphNode>> byTag = {};
    for (final n in nodes) {
      byTag.putIfAbsent(n.tag, () => []).add(n);
    }

    return Column(
      children: byTag.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _tagLabel(entry.key),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  letterSpacing: .5,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.value.map((node) {
                return _TopicChip(node: node, lang: lang);
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  static String _tagLabel(String tag) {
    const labels = {
      'arithmetic': 'АРИФМЕТИКА',
      'fractions': 'ДРОБИ',
      'algebra': 'АЛГЕБРА',
      'geometry': 'ГЕОМЕТРИЯ',
      'word_problems': 'ТЕКСТОВЫЕ ЗАДАЧИ',
      'number_theory': 'ТЕОРИЯ ЧИСЕЛ',
      'combinatorics': 'КОМБИНАТОРИКА',
      'probability': 'ВЕРОЯТНОСТЬ',
      'statistics': 'СТАТИСТИКА',
    };
    return labels[tag] ?? tag.toUpperCase();
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.node, required this.lang});
  final GraphNode node;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (node.status) {
      'mastered' => (const Color(0xFF10B981), Icons.check_circle_rounded),
      'partial'  => (const Color(0xFFF59E0B), Icons.radio_button_checked),
      'failed'   => (const Color(0xFFEF4444), Icons.cancel_rounded),
      _          => (const Color(0xFFCBD5E1), Icons.radio_button_unchecked),
    };

    return Tooltip(
      message: node.pMastery != null
          ? '${(node.pMastery! * 100).toStringAsFixed(0)}% освоено'
          : 'Не проверено',
      child: Chip(
        avatar: Icon(icon, color: color, size: 16),
        label: Text(
          node.name(lang),
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: color.withOpacity(.1),
        side: BorderSide(color: color.withOpacity(.3)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
