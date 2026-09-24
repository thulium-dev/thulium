import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:forui/forui.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import '../auth/secure_auth_session_store.dart';

/// Collects credentials and performs the shared Tsinghua authentication flow.
final class LoginPage extends StatefulWidget {
  const LoginPage({required this.onLoginSuccess, super.key});

  final VoidCallback onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// Keeps the verification input mounted until the identity provider accepts it.
final class _VerificationCodeDialog extends StatefulWidget {
  const _VerificationCodeDialog({
    required this.animation,
    required this.title,
    required this.hint,
    required this.invalidMessage,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.verifyCode,
  });

  final Animation<double> animation;
  final String title;
  final String hint;
  final String invalidMessage;
  final String confirmLabel;
  final String cancelLabel;
  final TwoFactorCodeVerifier verifyCode;

  @override
  State<_VerificationCodeDialog> createState() =>
      _VerificationCodeDialogState();
}

final class _VerificationCodeDialogState
    extends State<_VerificationCodeDialog> {
  final _controller = TextEditingController();
  bool _isVerifying = false;
  bool _isInvalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _isInvalid = true);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      if (await widget.verifyCode(code)) {
        if (mounted) Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _isInvalid = true);
      }
    } catch (_) {
      // A transport failure is not a bad code; end this dialog so the outer
      // login flow can report its normal sign-in error instead of hanging.
      if (mounted) Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) => FDialog.adaptive(
    animation: widget.animation,
    title: Text(widget.title),
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FTextField(
          control: FTextFieldControl.managed(
            controller: _controller,
            onChange: (_) {
              if (_isInvalid) setState(() => _isInvalid = false);
            },
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
          hint: widget.hint,
        ),
        if (_isInvalid) ...[
          const SizedBox(height: 8),
          Text(
            widget.invalidMessage,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.error,
            ),
          ),
        ],
      ],
    ),
    actions: [
      FButton(
        onPress: _isVerifying ? null : _verify,
        child: _isVerifying
            ? const SizedBox.square(
                dimension: 20,
                child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
              )
            : Text(widget.confirmLabel),
      ),
      FButton(
        variant: FButtonVariant.outline,
        onPress: _isVerifying ? null : () => Navigator.of(context).pop(false),
        child: Text(widget.cancelLabel),
      ),
    ],
  );
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
      if (mounted) widget.onLoginSuccess();
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

    final selected = await showFDialog<TwoFactorMethod>(
      context: context,
      builder: (context, _, animation) => FDialog.adaptive(
        animation: animation,
        title: Text(l10n.twoFactorTitle),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in methods)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => Navigator.of(context).pop(option.method),
                  child: Text(option.label),
                ),
              ),
          ],
        ),
        actions: [
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
        ],
      ),
    );
    if (selected == null) {
      throw StateError('Two-factor method selection canceled.');
    }
    return selected;
  }

  Future<void> _readTwoFactorCode(TwoFactorCodeVerifier verifyCode) async {
    final l10n = AppLocalizations.of(context)!;
    final verified = await showFDialog<bool>(
      context: context,
      builder: (context, _, animation) => _VerificationCodeDialog(
        animation: animation,
        title: l10n.verificationCodeTitle,
        hint: l10n.verificationCodeHint,
        invalidMessage: l10n.verificationCodeInvalid,
        confirmLabel: l10n.confirmAction,
        cancelLabel: l10n.cancelAction,
        verifyCode: verifyCode,
      ),
    );
    if (verified != true) {
      throw StateError('Verification code entry canceled.');
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
                      child: FButton.icon(
                        semanticsLabel: l10n.backAction,
                        variant: FButtonVariant.ghost,
                        onPress: () => Navigator.of(context).pop(),
                        child: context.theme.icons.arrowLeft(
                          context,
                          semanticsLabel: l10n.backAction,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(l10n.loginTitle, style: context.theme.typography.xl2),
                    const SizedBox(height: 32),
                    FTextFormField(
                      control: FTextFieldControl.managed(
                        controller: _studentIdController,
                      ),
                      label: Text(l10n.studentIdLabel),
                      hint: l10n.studentIdHint,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.requiredField
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FTextFormField.password(
                      control: FTextFieldControl.managed(
                        controller: _passwordController,
                      ),
                      label: Text(l10n.passwordLabel),
                      hint: l10n.passwordHint,
                      textInputAction: TextInputAction.done,
                      onSubmit: (_) => _submit(),
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.requiredField
                          : null,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FButton(
                      onPress: _isSubmitting ? null : () => _submit(),
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: FCircularProgress(
                                size: FCircularProgressSizeVariant.sm,
                              ),
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
