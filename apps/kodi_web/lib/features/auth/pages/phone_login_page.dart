import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kodi_core/kodi_core.dart';
import '../bloc/auth_bloc.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});
  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController(text: '+7');
  final _otpController = TextEditingController();
  ConfirmationResult? _confirmationResult;
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Введите номер телефона');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // signInWithPhoneNumber uses invisible reCAPTCHA on web
      final result = await FirebaseAuth.instance.signInWithPhoneNumber(phone);
      setState(() {
        _confirmationResult = result;
        _codeSent = true;
        _loading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() { _loading = false; _error = _mapError(e.code); });
    } catch (e) {
      setState(() { _loading = false; _error = 'Ошибка: $e'; });
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Введите 6-значный код');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final userCredential = await _confirmationResult!.confirm(code);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        setState(() { _loading = false; _error = 'Не удалось получить токен'; });
        return;
      }

      if (!mounted) return;
      final api = context.read<NisApiClient>();
      final jwt = await api.loginWithPhone(idToken);

      if (!mounted) return;
      context.read<AuthBloc>().add(AuthTokenReceived(jwt));
    } on FirebaseAuthException catch (e) {
      setState(() { _loading = false; _error = _mapError(e.code); });
    } catch (e) {
      setState(() { _loading = false; _error = 'Ошибка: $e'; });
    }
  }

  String _mapError(String code) => switch (code) {
    'invalid-phone-number' => 'Неверный номер телефона',
    'too-many-requests' => 'Слишком много попыток. Подождите',
    'invalid-verification-code' => 'Неверный код',
    'session-expired' => 'Код истёк. Запросите новый',
    'captcha-check-failed' => 'Ошибка проверки. Обновите страницу',
    _ => 'Ошибка: $code',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_codeSent) ...[
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+0-9]'))],
            decoration: InputDecoration(
              labelText: 'Номер телефона',
              hintText: '+7 777 123 4567',
              prefixIcon: const Icon(Icons.phone_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: const TextStyle(fontSize: 18, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _sendCode,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                backgroundColor: const Color(0xFF2563EB)),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Получить код', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ] else ...[
          Text('Код отправлен на ${_phoneController.text}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            textAlign: TextAlign.center,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Код из SMS',
              hintText: '123456',
              prefixIcon: const Icon(Icons.lock_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            onSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _verifyCode,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                backgroundColor: const Color(0xFF2563EB)),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Подтвердить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : () => setState(() {
              _codeSent = false; _otpController.clear(); _error = null; _confirmationResult = null;
            }),
            child: const Text('Изменить номер'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
            ]),
          ),
        ],
      ],
    );
  }
}
