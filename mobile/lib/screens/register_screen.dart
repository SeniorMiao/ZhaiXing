import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../services/api_service.dart';
import 'app_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final auth = context.read<AuthController>();
    setState(() => _loading = true);
    try {
      final res = await auth.api.register(
        email: _email.text.trim(),
        password: _password.text,
        nickname: _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
      );
      await auth.applyAuth(res);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AppShell()),
        (route) => false,
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
      appBar: AppBar(title: const Text('注册')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('创建账号', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('用于同步你的会议与纪要', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
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
                        labelText: '密码（≥8 位）',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final s = (v ?? '');
                        if (s.isEmpty) return '请输入密码';
                        if (s.length < 8) return '密码至少 8 位';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nickname,
                      decoration: const InputDecoration(
                        labelText: '昵称（可选）',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? '注册中…' : '注册并登录'),
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
}
