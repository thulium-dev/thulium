import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:forui/forui.dart';

import '../widgets/app_page_scaffold.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';
import 'package:thulium_auth/thulium_auth.dart';

import '../auth/secure_auth_session_store.dart';

/// Configures a transport while retaining the real page's verification dialogs.
typedef LoginAuthClientBuilder =
    TsinghuaAuthClient Function({
      required AuthSessionStore sessionStore,
      required AuthCredentialStore credentialStore,
      required TwoFactorMethodHandler twoFactorMethodHandler,
      required TwoFactorCodeHandler twoFactorCodeHandler,
      required TwoFactorTrustHandler twoFactorTrustHandler,
      required TwoFactorAuthLimitHandler twoFactorAuthLimitHandler,
      required AuthTraceHandler trace,
    });

/// Collects credentials and performs the shared Tsinghua authentication flow.
final class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.onLoginSuccess,
    this.authClientBuilder,
    super.key,
  });

  final VoidCallback onLoginSuccess;
  final LoginAuthClientBuilder? authClientBuilder;

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
    if (!mounted || _isVerifying || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _isInvalid = true);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      if (await widget.verifyCode(code)) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop(true);
        }
      } else if (mounted) {
        setState(() => _isInvalid = true);
      }
    } catch (_) {
      // A transport failure is not a bad code; end this dialog so the outer
      // login flow can report its normal sign-in error instead of hanging.
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(false);
      }
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
        onPress: _isVerifying
            ? null
            : () {
                if (!_isVerifying &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  Navigator.of(context).pop(false);
                }
              },
        child: Text(widget.cancelLabel),
      ),
    ],
  );
}

final class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _sessionStore = SecureAuthSessionStore();
  late final TsinghuaAuthClient _authClient =
      (widget.authClientBuilder ?? TsinghuaAuthClient.new)(
        sessionStore: _sessionStore,
        credentialStore: _sessionStore,
        twoFactorMethodHandler: _selectTwoFactorMethod,
        twoFactorCodeHandler: _readTwoFactorCode,
        twoFactorTrustHandler: _askToTrustDevice,
        twoFactorAuthLimitHandler: _showDeviceTrustLimit,
        trace: (message) => debugPrint('[auth][signin=$_attemptId] $message'),
      );

  bool _isSubmitting = false;
  String? _errorMessage;
  Future<bool>? _trustChoice;
  static int _nextAttemptId = 0;
  int _attemptId = 0;

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted) return;
    if (_isSubmitting) {
      debugPrint('[signin] attempt=$_attemptId stage=duplicate_submit_ignored');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = _studentIdController.text.trim();
    final password = _passwordController.text;
    FocusScope.of(context).unfocus();
    setState(() {
      _attemptId = ++_nextAttemptId;
      _trustChoice = null;
      _errorMessage = null;
      _isSubmitting = true;
    });
    debugPrint('[signin] attempt=$_attemptId stage=start');

    try {
      await AuthSessionRunner.exclusive(_sessionStore, () async {
        await _authClient.login(
          userId: userId,
          password: password,
          fingerprint: await _sessionStore.getOrCreateFingerprint(),
        );
      });
      debugPrint('[signin] attempt=$_attemptId stage=success');
      if (mounted) widget.onLoginSuccess();
    } catch (error) {
      // Do not expose server internals or distinguish which credential was
      // incorrect. The same localized message also covers network failures.
      debugPrint(
        '[signin] attempt=$_attemptId stage=failed type=${error.runtimeType}',
      );
      if (mounted) {
        setState(
          () => _errorMessage = error is DeviceTrustRegistrationException
              ? AppLocalizations.of(context)!.deviceTrustRegistrationError
              : AppLocalizations.of(context)!.loginError,
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
    var answered = false;
    void answer(BuildContext dialogContext, TwoFactorMethod? method) {
      if (answered || ModalRoute.of(dialogContext)?.isCurrent != true) return;
      answered = true;
      Navigator.of(dialogContext).pop(method);
    }

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
                  onPress: () => answer(context, option.method),
                  child: Text(option.label),
                ),
              ),
          ],
        ),
        actions: [
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => answer(context, null),
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

  Future<bool> _askToTrustDevice() {
    final existing = _trustChoice;
    if (existing != null) {
      debugPrint('[signin] attempt=$_attemptId stage=trust_choice_reused');
      return existing;
    }
    return _trustChoice = _showTrustDeviceDialog();
  }

  Future<void> _showDeviceTrustLimit() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    var answered = false;
    await showFDialog<void>(
      context: context,
      builder: (context, _, animation) => FDialog.adaptive(
        animation: animation,
        title: Text(l10n.deviceTrustLimitTitle),
        body: Text(l10n.deviceTrustLimitDescription),
        actions: [
          FButton(
            onPress: () {
              if (answered || ModalRoute.of(context)?.isCurrent != true) return;
              answered = true;
              Navigator.of(context).pop();
            },
            child: Text(l10n.continueSignInAction),
          ),
        ],
      ),
    );
  }

  Future<bool> _showTrustDeviceDialog() async {
    final l10n = AppLocalizations.of(context)!;
    var answered = false;
    void answer(BuildContext dialogContext, bool choice) {
      if (answered || ModalRoute.of(dialogContext)?.isCurrent != true) return;
      answered = true;
      Navigator.of(dialogContext).pop(choice);
    }

    debugPrint('[signin] attempt=$_attemptId stage=trust_dialog_shown');
    final choice =
        await showFDialog<bool>(
          context: context,
          builder: (context, _, animation) => FDialog.adaptive(
            animation: animation,
            title: Text(l10n.trustDeviceTitle),
            body: Text(l10n.trustDeviceDescription),
            actions: [
              FButton(
                variant: FButtonVariant.outline,
                onPress: () => answer(context, false),
                child: Text(l10n.notNowAction),
              ),
              FButton(
                onPress: () => answer(context, true),
                child: Text(l10n.trustDeviceAction),
              ),
            ],
          ),
        ) ??
        false;
    debugPrint('[signin] attempt=$_attemptId stage=trust_dialog_resolved');
    return choice;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppPageScaffold(
      title: l10n.loginTitle,
      maxWidth: 480,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
