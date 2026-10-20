import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/qr_link_parser.dart';
import '../../domain/session_controller.dart';

/// Pairs the app with the computer running `run_ui.ps1`: scan its QR code, or
/// type the address and paste the access token.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _address = TextEditingController();
  final _token = TextEditingController();
  bool _connecting = false;
  bool _showToken = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    if (session is SignedOut && session.lastAddress != null) {
      _address.text = displayAddress(session.lastAddress!);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final raw = await context.push<String>(Routes.scan);
    if (raw == null || !mounted) return;
    final link = parsePairingLink(raw);
    if (link == null) {
      setState(() => _error = 'That QR code is not an Agent UI sign-in code.');
      return;
    }
    _address.text = displayAddress(link.baseUrl);
    _token.text = link.token;
    await _connect(link.baseUrl, link.token);
  }

  Future<void> _submit() async {
    // A pasted sign-in link works in the address field too.
    final link = parsePairingLink(_address.text);
    if (link != null) {
      _address.text = displayAddress(link.baseUrl);
      _token.text = link.token;
      return _connect(link.baseUrl, link.token);
    }

    final String? problem;
    final address = parseServerAddress(_address.text);
    if (_address.text.trim().isEmpty) {
      problem = 'Enter the computer\'s address, for example 192.168.1.20:8000.';
    } else if (address == null) {
      problem = 'That doesn\'t look like an address. Use the form 192.168.1.20:8000.';
    } else if (_token.text.trim().isEmpty) {
      problem = 'Paste the access token.';
    } else {
      problem = null;
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _connect(address!, _token.text.trim());
  }

  Future<void> _connect(Uri baseUrl, String token) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).pair(baseUrl, token);
      // The router moves on to the chat once the session is signed in.
    } on PairingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final signedOutMessage = session is SignedOut ? session.message : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (signedOutMessage != null) ...[
                      _Notice(text: signedOutMessage, color: palette.warning, background: palette.warningBackground),
                      const SizedBox(height: 24),
                    ],
                    Center(
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: palette.userBubble,
                        child: Icon(Icons.phonelink_rounded, size: 32, color: palette.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Connect to your computer',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start run_ui.ps1 on your computer, then scan the QR code it shows, either in the '
                      'terminal or under "Use on your phone" in the web app. Your phone must be on the same Wi-Fi.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _connecting ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan QR code'),
                    ),
                    const SizedBox(height: 28),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or enter it by hand',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.muted),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('pairing-address'),
                      controller: _address,
                      enabled: !_connecting,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Server address',
                        hintText: '192.168.1.20:8000',
                        helperText: 'The address and port from the terminal.',
                        prefixIcon: Icon(Icons.computer_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('pairing-token'),
                      controller: _token,
                      enabled: !_connecting,
                      obscureText: !_showToken,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Access token',
                        helperText: 'In agent-ui/backend/data/remote_token.txt',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showToken ? 'Hide token' : 'Show token',
                          icon: Icon(_showToken ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          onPressed: () => setState(() => _showToken = !_showToken),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _Notice(text: _error!, color: palette.error, background: palette.error.withValues(alpha: 0.08)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('pairing-connect'),
                      onPressed: _connecting ? null : _submit,
                      child: _connecting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Connecting'),
                            )
                          : const Text('Connect'),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(color: color))),
            ],
          ),
        ),
      );
}
