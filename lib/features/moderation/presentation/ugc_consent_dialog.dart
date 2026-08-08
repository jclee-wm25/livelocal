import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/legal_urls.dart';

/// Shows a dialog requesting the user to accept the latest Community Rules.
/// Returns true if accepted, false if canceled.
Future<bool> showUgcConsentDialog(BuildContext context,
    {Future<void> Function()? onAccept}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => UgcConsentDialog(
            onAccept: onAccept ?? UgcConsentDialog.onAcceptOverride),
      ) ??
      false;
}

class UgcConsentDialog extends StatefulWidget {
  const UgcConsentDialog({super.key, this.onAccept});
  final Future<void> Function()? onAccept;

  @visibleForTesting
  static Future<void> Function()? onAcceptOverride;

  @override
  State<UgcConsentDialog> createState() => _UgcConsentDialogState();
}

class _UgcConsentDialogState extends State<UgcConsentDialog> {
  bool _isLoading = false;
  late final LegalUrls _urls;
  final AppLauncher _launcher = const DefaultAppLauncher();

  @override
  void initState() {
    super.initState();
    _urls = LegalUrls.fromCompileTime();
  }

  Future<void> _launchRules() async {
    final success = await _launcher.launch(_urls.communityRules);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not open the link. Please visit livelocal.app/rules'),
        ),
      );
    }
  }

  Future<void> _acceptRules() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.onAccept != null) {
        await widget.onAccept!();
      } else {
        await Supabase.instance.client.rpc('accept_current_ugc_rules');
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept rules: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Community Rules Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'To keep our community safe and welcoming, we require all users to accept our updated Community Rules before submitting content.',
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _launchRules,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            child: const Text('Read Community Rules'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _acceptRules,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Agree & Continue'),
        ),
      ],
    );
  }
}
