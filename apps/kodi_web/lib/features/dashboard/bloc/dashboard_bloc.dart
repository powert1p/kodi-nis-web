import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:kodi_core/kodi_core.dart';

// ── Events ────────────────────────────────────────────────────
abstract class DashboardEvent extends Equatable {
  @override List<Object?> get props => [];
}
class DashboardLoad extends DashboardEvent {}

// ── States ────────────────────────────────────────────────────
abstract class DashboardState extends Equatable {
  @override List<Object?> get props => [];
}
class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}
class DashboardLoaded extends DashboardState {
  DashboardLoaded({
    required this.student,
    required this.stats,
    required this.nodes,
  });
  final Student student;
  final Stats stats;
  final List<GraphNode> nodes;
  @override List<Object?> get props => [student, stats, nodes];
}
class DashboardError extends DashboardState {
  DashboardError(this.message);
  final String message;
  @override List<Object?> get props => [message];
}

// ── Bloc ──────────────────────────────────────────────────────
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required this.api}) : super(DashboardInitial()) {
    on<DashboardLoad>(_onLoad);
  }

  final NisApiClient api;

  Future<void> _onLoad(
    DashboardLoad event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final results = await Future.wait([
        api.getMe(),
        api.getStats(),
        api.getGraphNodes(),
      ]);
      emit(DashboardLoaded(
        student: results[0] as Student,
        stats: results[1] as Stats,
        nodes: results[2] as List<GraphNode>,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
