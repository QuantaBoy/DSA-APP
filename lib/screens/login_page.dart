import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Runs a Firebase call with a spinner and a readable error message.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = FirebaseAuth.instance;
    final email = _email.text.trim();
    await _run(() async {
      if (_signUp) {
        final cred = await auth.createUserWithEmailAndPassword(email: email, password: _password.text);
        await cred.user?.updateDisplayName(_name.text.trim());
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: _password.text);
      }
    });
  }

  Future<void> _google() => _run(() async {
    final provider = GoogleAuthProvider();
    final auth = FirebaseAuth.instance;
    await (kIsWeb ? auth.signInWithPopup(provider) : auth.signInWithProvider(provider));
  });

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_isEmail(email)) {
      setState(() => _error = 'Type your email above first, then tap "Forgot password?".');
      return;
    }
    await _run(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('If $email has an account, a reset link is on its way.')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset('assets/illustrations/logo.png', width: 44, height: 44),
                          ),
                          const SizedBox(width: 10),
                          Text('Memory Stack', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 36),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey(_signUp),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _signUp ? 'Create account' : 'Welcome back',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _signUp
                                  ? 'Sign up to start remembering every problem you solve.'
                                  : "We've missed you. Sign in to keep your streak going.",
                              style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_signUp) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => _isEmail((v ?? '').trim()) ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          helperText: _signUp ? 'At least 8 characters' : null,
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                        onFieldSubmitted: (_) => _busy ? null : _submit(),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return 'Enter your password';
                          if (_signUp && v!.length < 8) return 'Use at least 8 characters';
                          return null;
                        },
                      ),
                      if (!_signUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _busy ? null : _forgotPassword, child: const Text('Forgot password?')),
                        ),
                      if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: colors.error))],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        child: _busy
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(_signUp ? 'Sign up' : 'Sign in'),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(color: colors.onSurfaceVariant)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _google,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        icon: const Icon(Icons.g_mobiledata, size: 30),
                        label: Text(_signUp ? 'Sign up with Google' : 'Sign in with Google'),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _signUp ? 'Already have an account?' : "Don't have an account?",
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _signUp = !_signUp;
                                    _error = null;
                                  }),
                            child: Text(_signUp ? 'Sign in' : 'Sign up', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

String? _message(String code) => switch (code) {
  'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Wrong email or password.',
  'invalid-email' => 'That email address is not valid.',
  'email-already-in-use' => 'That email already has an account. Sign in instead.',
  'weak-password' => 'Choose a stronger password.',
  'user-disabled' => 'This account has been disabled.',
  'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
  'network-request-failed' => 'No internet connection. Check it and try again.',
  'operation-not-allowed' => 'This sign-in method is not turned on in Firebase yet.',
  'popup-closed-by-user' || 'web-context-canceled' || 'web-context-cancelled' => null, // user closed Google window
  _ => 'Something went wrong ($code). Please try again.',
};
