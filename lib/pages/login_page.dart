import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import '../auth/secure_auth_session_store.dart';

/// Collects credentials and performs the shared Tsinghua authentication flow.
final class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TsinghuaAuthClient _authClient = TsinghuaAuthClient(
    sessionStore: SecureAuthSessionStore(),
    twoFactorMethodHandler: _selectTwoFactorMethod,
    twoFactorCodeHandler: _readTwoFactorCode,
    trace: (message) => debugPrint('[auth] $message'),
  );

  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      await _authClient.login(
        userId: _studentIdController.text.trim(),
        password: _passwordController.text,
        fingerprint: 'thulium-flutter',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      // Do not expose server internals or distinguish which credential was
      // incorrect. The same localized message also covers network failures.
      debugPrint('Thulium login failed: $error');
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context)!.loginError,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<TwoFactorMethod> _selectTwoFactorMethod(
    TwoFactorOptions options,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final methods = <({TwoFactorMethod method, String label})>[];
    if (options.hasWeChat) {
      methods.add((method: TwoFactorMethod.wechat, label: l10n.wechatMethod));
    }
    if (options.phone != null) {
      methods.add((
        method: TwoFactorMethod.mobile,
        label: l10n.smsMethod(options.phone!),
      ));
    }
    if (options.hasTotp) {
      methods.add((method: TwoFactorMethod.totp, label: l10n.totpMethod));
    }

    final selected = await showDialog<TwoFactorMethod>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.twoFactorTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in methods)
              ListTile(
                title: Text(option.label),
                onTap: () => Navigator.of(context).pop(option.method),
              ),
          ],
        ),
      ),
    );
    if (selected == null) {
      throw StateError('Two-factor method selection canceled.');
    }
    return selected;
  }

  Future<String> _readTwoFactorCode() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    try {
      final code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.verificationCodeTitle),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.verificationCodeHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(l10n.confirmAction),
            ),
          ],
        ),
      );
      if (code == null || code.isEmpty) {
        throw StateError('Verification code entry canceled.');
      }
      return code;
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(l10n.loginTitle, style: context.theme.typography.xl2),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _studentIdController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.studentIdLabel,
                        hintText: l10n.studentIdHint,
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.requiredField
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        hintText: l10n.passwordHint,
                        suffixIcon: IconButton(
                          tooltip: _isPasswordVisible
                              ? l10n.hidePassword
                              : l10n.showPassword,
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.requiredField
                          : null,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FButton(
                      onPress: _isSubmitting ? null : () => _submit(),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.signInAction),
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
