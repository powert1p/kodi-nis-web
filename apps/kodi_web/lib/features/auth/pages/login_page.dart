import 'dart:convert';
import '../../../app/config.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../../dashboard/pages/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  html.WindowBase? _popup;

  @override
  void initState() {
    super.initState();
    html.window.onMessage.listen(_onMessage);
  }

  void _onMessage(html.MessageEvent event) {
    try {
      final decoded = jsonDecode(event.data as String) as Map<String, dynamic>;
      if (decoded['type'] == 'tg_auth') {
        final data = decoded['data'] as Map<String, dynamic>;
        _popup?.close();
        if (mounted) {
          context.read<AuthBloc>().add(AuthTelegramLogin(data));
        }
      }
    } catch (_) {}
  }

  void _openTelegramLogin() {
    final url = Uri.base.resolve('/telegram_login.html?bot=${AppConfig.telegramBotName}').toString();
    _popup = html.window.open(
      url,
      'tg_login',
      'width=400,height=500,left=200,top=100',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushReplacementNamed(DashboardPage.routeName);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'NIS Math',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Подготовка к поступлению в НИШ',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is AuthLoading) {
                          return const CircularProgressIndicator();
                        }
                        if (state is AuthError) {
                          return Column(
                            children: [
                              Text(
                                state.message,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              _loginButton(),
                            ],
                          );
                        }
                        return _loginButton();
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '2525 задач · 118 тем · БКТ-алгоритм',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginButton() => FilledButton.icon(
        onPressed: _openTelegramLogin,
        icon: const Icon(Icons.telegram),
        label: const Text('Войти через Telegram'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF229ED9),
        ),
      );
}
