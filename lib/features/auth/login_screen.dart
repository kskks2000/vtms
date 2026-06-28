import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_scope.dart';
import '../../core/responsive/breakpoints.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await AuthScope.of(context)
          .login(_emailCtrl.text, _passwordCtrl.text);
      // 성공 시 라우터 리다이렉트가 자동으로 메인으로 이동시킨다.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _googleSubmit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await AuthScope.of(context).loginWithGoogle();
      // 성공 시 라우터 리다이렉트가 자동으로 메인으로 이동시킨다.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '구글 로그인 중 문제가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return '이메일을 입력해 주세요.';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(value)) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 입력해 주세요.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Breakpoints.of(context).isWide;
    final card = _LoginCard(
      formKey: _formKey,
      emailCtrl: _emailCtrl,
      passwordCtrl: _passwordCtrl,
      obscure: _obscure,
      submitting: _submitting,
      error: _error,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onSubmit: _submit,
      onGoogleSubmit: _googleSubmit,
      onEmailValidate: _validateEmail,
      onPasswordValidate: _validatePassword,
    );

    return Scaffold(
      body: SafeArea(
        child: isWide
            ? Row(
                children: [
                  const Expanded(child: _BrandPanel()),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: card,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: card,
                  ),
                ),
              ),
      ),
    );
  }
}

/// 넓은 화면 좌측 브랜드 패널.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primary,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_shipping, size: 64, color: scheme.onPrimary),
          const SizedBox(height: 24),
          Text(
            'VTMS',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '운송 관리 시스템',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.submitting,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogleSubmit,
    required this.onEmailValidate,
    required this.onPasswordValidate,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool submitting;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleSubmit;
  final String? Function(String?) onEmailValidate;
  final String? Function(String?) onPasswordValidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('로그인', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '계정 정보를 입력해 주세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !submitting,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: '이메일',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: onEmailValidate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscure,
            enabled: !submitting,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: '비밀번호',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: onPasswordValidate,
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: error!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('로그인'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '또는',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: submitting ? null : onGoogleSubmit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Google 계정으로 로그인'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed:
                    submitting ? null : () => context.go('/reset-password'),
                child: const Text('비밀번호 찾기'),
              ),
              TextButton(
                onPressed: submitting ? null : () => context.go('/signup'),
                child: const Text('회원가입'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
