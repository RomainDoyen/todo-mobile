import 'package:flutter/material.dart';

import '../src/api_client.dart';
import '../src/scope.dart';
import '../theme.dart';

enum _AuthTab { login, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _server = TextEditingController();
  var _tab = _AuthTab.login;
  var _busy = false;
  var _showServer = false;
  var _hidePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final model = AppScope.of(context);
      _server.text = model.apiBase;
      final account = await model.lastAccount();
      if (!mounted || account == null) return;
      if (_email.text.isEmpty) _email.text = account.email;
      if (_name.text.isEmpty && account.name.isNotEmpty) _name.text = account.name;
      if (_password.text.isEmpty && account.password != null) _password.text = account.password!;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tab = _tab;
    final model = AppScope.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email et mot de passe requis');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = '8 caractères minimum');
      return;
    }
    if (tab == _AuthTab.register && name.isEmpty) {
      setState(() => _error = 'Indiquez votre nom');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_server.text.trim().isNotEmpty) await model.setApiBase(_server.text);
      if (!mounted) return;
      if (tab == _AuthTab.login) {
        await model.login(email, password);
      } else {
        await model.register(email, password, name);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    final model = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_server.text.trim().isNotEmpty) await model.setApiBase(_server.text);
      if (!mounted) return;
      await model.loginWithGoogle();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF151E31) : Colors.white;
    final field = dark ? const Color(0xFF121A2B) : const Color(0xFFF4F7FB);
    final registering = _tab == _AuthTab.register;

    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            children: [
              const Center(
                child: Image(
                  image: AssetImage('assets/icon/app_icon_rounded.png'),
                  width: 52,
                  height: 52,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Mes Tâches',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connectez-vous pour synchroniser vos tâches',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xCC121A2B) : const Color(0xB8FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: dark ? Colors.white12 : const Color(0x14152033)),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Connexion',
                      selected: _tab == _AuthTab.login,
                      onTap: () => setState(() {
                        _tab = _AuthTab.login;
                        _error = null;
                      }),
                    ),
                    _TabButton(
                      label: 'Créer un compte',
                      selected: registering,
                      onTap: () => setState(() {
                        _tab = _AuthTab.register;
                        _error = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (registering)
                _Field(
                  label: 'Nom',
                  controller: _name,
                  hint: 'Votre nom',
                  fill: field,
                  textCapitalization: TextCapitalization.words,
                ),
              _Field(
                label: 'Email',
                controller: _email,
                hint: 'vous@exemple.com',
                fill: field,
                keyboardType: TextInputType.emailAddress,
              ),
              _Field(
                label: 'Mot de passe',
                controller: _password,
                hint: '••••••••',
                fill: field,
                obscure: _hidePassword,
                onToggleObscure: () => setState(() => _hidePassword = !_hidePassword),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: danger, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: dark ? accentDark : accent,
                    foregroundColor: dark ? const Color(0xFF06241F) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _busy
                        ? (registering ? 'Création…' : 'Connexion…')
                        : (registering ? 'Créer mon compte' : 'Se connecter'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou', style: TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: _busy ? null : _google,
                style: OutlinedButton.styleFrom(
                  backgroundColor: card.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: dark ? Colors.white12 : const Color(0x14152033)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleMark(),
                    SizedBox(width: 10),
                    Text('Continuer avec Google', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showServer = !_showServer),
                child: const Text('Adresse du serveur'),
              ),
              if (_showServer)
                TextField(
                  controller: _server,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'https://…',
                    helperText: 'Émulateur Android : http://10.0.2.2:8787',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: selected ? (dark ? const Color(0xFF151E31) : Colors.white) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        elevation: selected ? 1 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: selected ? (dark ? accentDark : accent) : muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.fill,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final Color fill;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: onToggleObscure == null ? keyboardType : TextInputType.visiblePassword,
            textCapitalization: textCapitalization,
            autocorrect: onToggleObscure == null && keyboardType != TextInputType.emailAddress,
            enableSuggestions: onToggleObscure == null,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: fill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      tooltip: obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: muted,
                      ),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      -0.4,
      1.4,
      false,
      stroke..color = const Color(0xFF4285F4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      1.0,
      1.3,
      false,
      stroke..color = const Color(0xFF34A853),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      2.4,
      1.2,
      false,
      stroke..color = const Color(0xFFFBBC05),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      3.7,
      1.2,
      false,
      stroke..color = const Color(0xFFEA4335),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
