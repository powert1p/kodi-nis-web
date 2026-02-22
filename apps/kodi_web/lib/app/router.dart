import 'package:flutter/material.dart';
import '../features/auth/pages/login_page.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/practice/pages/practice_page.dart';

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  return switch (settings.name) {
    '/' || DashboardPage.routeName => MaterialPageRoute(
        builder: (_) => const DashboardPage(),
        settings: settings,
      ),
    LoginPage.routeName => MaterialPageRoute(
        builder: (_) => const LoginPage(),
        settings: settings,
      ),
    PracticePage.routeName => MaterialPageRoute(
        builder: (_) => const PracticePage(),
        settings: settings,
      ),
    _ => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('404 — Страница не найдена')),
        ),
      ),
  };
}
