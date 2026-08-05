import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_colors.dart';
import '../../../core/config/app_environment.dart';
import '../../../screens/main_navigation_screen.dart';
import '../../profile/presentation/account_controller.dart';
import 'auth_controller.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.checking:
        return const _SessionLoadingScreen();
      case AuthStatus.failure:
        return _SessionFailureScreen(
          message: auth.errorMessage,
          onRetry: auth.retrySessionRestore,
        );
      case AuthStatus.verificationRequired:
        return const EmailVerificationScreen();
      case AuthStatus.restricted:
      case AuthStatus.banned:
      case AuthStatus.deletionPending:
        return const RestrictedAccountScreen();
      case AuthStatus.guest:
      case AuthStatus.authenticated:
        return const MainNavigationScreen();
    }
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Checking your session',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _SessionFailureScreen extends StatelessWidget {
  const _SessionFailureScreen({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'We could not check your account',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ?? 'Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.pendingVerificationEmail ?? 'your email address';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Check your inbox',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to $email. Open it on this device, then return to LiveLocal.',
                    textAlign: TextAlign.center,
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final sent = await auth.resendVerificationEmail();
                            if (!context.mounted || !sent) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verification email sent.'),
                              ),
                            );
                          },
                    child: const Text('Resend email'),
                  ),
                  TextButton(
                    onPressed: auth.isLoading ? null : auth.logout,
                    child: const Text('Use a different account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RestrictedAccountScreen extends StatelessWidget {
  const RestrictedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final accountController = context.watch<AccountController>();
    final account = auth.currentUser;
    final configuration = context.read<AppConfiguration>();
    final isDeletionPending = auth.status == AuthStatus.deletionPending;
    final title = switch (auth.status) {
      AuthStatus.restricted => 'Account temporarily restricted',
      AuthStatus.deletionPending => 'Account deletion scheduled',
      _ => 'Account unavailable',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Account status')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  isDeletionPending
                      ? Icons.schedule_outlined
                      : Icons.gpp_maybe_outlined,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  account?.accessReason ??
                      (isDeletionPending
                          ? 'You cannot create content while deletion is pending.'
                          : 'Protected actions are unavailable for this account.'),
                  textAlign: TextAlign.center,
                ),
                if (account?.accessEndsAt case final endsAt?) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Restriction ends: ${MaterialLocalizations.of(context).formatMediumDate(endsAt)}',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (account?.deletionScheduledFor case final deletionDate?) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Deletion scheduled: ${MaterialLocalizations.of(context).formatMediumDate(deletionDate)}',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                if (isDeletionPending)
                  FilledButton.icon(
                    onPressed: accountController.isLoading
                        ? null
                        : () => _showRecoveryDialog(
                              context,
                              accountController,
                            ),
                    icon: const Icon(Icons.restore),
                    label: const Text('Recover my account'),
                  )
                else
                  FilledButton.icon(
                    onPressed: account?.accessDecisionId == null ||
                            accountController.isLoading
                        ? null
                        : () => _showAppealDialog(
                              context,
                              accountController,
                              account!.accessDecisionId!,
                            ),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: Text(
                      accountController.submittedAppeal == null
                          ? 'Submit an appeal'
                          : 'Appeal submitted',
                    ),
                  ),
                if (!isDeletionPending &&
                    account?.accessDecisionId == null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'An in-app appeal is unavailable because this account state has no auditable decision record.',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (accountController.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    accountController.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 8),
                SelectableText(
                  'If app access fails, contact ${configuration.supportEmail}.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: auth.isLoading ? null : auth.logout,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRecoveryDialog(
    BuildContext context,
    AccountController controller,
  ) async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recover this account?'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
            labelText: 'Current password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm recovery'),
          ),
        ],
      ),
    );
    final enteredPassword = password.text;
    password.dispose();
    if (confirmed != true || enteredPassword.isEmpty) return;
    final recovered = await controller.cancelDeletion(enteredPassword);
    if (!context.mounted || !recovered) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your deletion request was cancelled.')),
    );
  }

  Future<void> _showAppealDialog(
    BuildContext context,
    AccountController controller,
    String decisionId,
  ) async {
    var reason = 'mistake';
    final explanation = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Appeal this decision'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'mistake',
                      child: Text('I believe this is a mistake'),
                    ),
                    DropdownMenuItem(
                      value: 'context',
                      child: Text('Important context is missing'),
                    ),
                    DropdownMenuItem(
                      value: 'account_compromised',
                      child: Text('My account was compromised'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Another reason'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: explanation,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Optional explanation',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const Text(
                  'We will review your appeal as soon as reasonably possible.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit appeal'),
            ),
          ],
        ),
      ),
    );
    final enteredExplanation = explanation.text.trim();
    explanation.dispose();
    if (submitted != true) return;
    final success = await controller.submitAppeal(
      decisionId: decisionId,
      reason: reason,
      explanation: enteredExplanation.isEmpty ? null : enteredExplanation,
    );
    if (!context.mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appeal submitted for review.')),
    );
  }
}
