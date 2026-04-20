import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import 'app_shell.dart';
import 'register_screen.dart';
import 'roadmap_placeholder_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final auth = context.read<AuthController>();
    setState(() => _loading = true);
    try {
      final res = await auth.api.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      await auth.applyAuth(res);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShell()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.mic_rounded, color: cs.onPrimaryContainer, size: 34),
                    ),
                    const SizedBox(height: 12),
                    Text('会议纪要助手', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('登录后开始上传并生成纪要', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: '邮箱',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return '请输入邮箱';
                            if (!s.contains('@')) return '邮箱格式不正确';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _loading ? null : _submit(),
                          validator: (v) {
                            if ((v ?? '').isEmpty) return '请输入密码';
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const RoadmapPlaceholderScreen(
                                          title: '找回密码',
                                          body:
                                              '原型含找回密码流程。当前后端未提供重置接口，本地开发请使用 README 中的测试账号或执行 reset 脚本。',
                                          icon: Icons.lock_reset_outlined,
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text('忘记密码？'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: Text(_loading ? '登录中…' : '登录'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                                  );
                                },
                          child: const Text('没有账号？去注册'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
