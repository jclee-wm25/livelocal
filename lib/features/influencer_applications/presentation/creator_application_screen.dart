import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/validation/social_url_validator.dart';
import 'influencer_application_controller.dart';
import '../domain/influencer_application_repository.dart';

class CreatorApplicationScreen extends StatefulWidget {
  const CreatorApplicationScreen({super.key});

  @override
  State<CreatorApplicationScreen> createState() =>
      _CreatorApplicationScreenState();
}

class _CreatorApplicationScreenState extends State<CreatorApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _profileUrl = TextEditingController();
  final _followerCount = TextEditingController();
  final _category = TextEditingController();
  final _message = TextEditingController();
  String _platform = 'instagram';
  bool _agreed = false;
  bool _initializedFields = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InfluencerApplicationController>().loadMine();
    });
  }

  @override
  void dispose() {
    _displayName.dispose();
    _profileUrl.dispose();
    _followerCount.dispose();
    _category.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InfluencerApplicationController>();
    final application = controller.mine;
    if (!_initializedFields && application != null) {
      _initialize(application);
    }
    final locked = application != null &&
        ['submitted', 'under_review', 'approved'].contains(application.status);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        title: const Text('Creator application'),
        backgroundColor: const Color(0xFFF7F5F0),
      ),
      body: controller.isLoading && application == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Text(
                  'Share trusted local recommendations',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Creator access is granted only after review. Approval lets you submit restaurant listings and promotional codes that you own.',
                ),
                if (application != null) ...[
                  const SizedBox(height: 16),
                  _StatusCard(status: application.status),
                ],
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (!locked) ...[
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(
                          _displayName,
                          'Creator display name',
                          minLength: 2,
                          maxLength: 80,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _platform,
                          decoration: const InputDecoration(
                            labelText: 'Primary social platform',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'instagram',
                              child: Text('Instagram'),
                            ),
                            DropdownMenuItem(
                              value: 'tiktok',
                              child: Text('TikTok'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _platform = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _profileUrl,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'HTTPS profile URL',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => SocialUrlValidator.isSupported(
                            value ?? '',
                            platform: _platform,
                          )
                              ? null
                              : 'Use a matching instagram.com or tiktok.com HTTPS URL.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _followerCount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Approximate follower count',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final count = int.tryParse(value?.trim() ?? '');
                            return count == null || count < 0
                                ? 'Enter a non-negative whole number.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _field(
                          _category,
                          'Primary content category',
                          minLength: 2,
                          maxLength: 80,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          _message,
                          'Why do you want to contribute?',
                          minLength: 20,
                          maxLength: 2000,
                          maxLines: 5,
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _agreed,
                          title: const Text(
                            'I agree to the Creator and Community Rules',
                          ),
                          subtitle: TextButton(
                            onPressed: _showRulesSummary,
                            child: const Text('Read the current rules summary'),
                          ),
                          onChanged: (value) =>
                              setState(() => _agreed = value ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.isLoading ? null : _submit,
                    child: const Text('Submit application'),
                  ),
                ] else if (application.status == 'submitted' ||
                    application.status == 'under_review') ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: controller.isLoading
                        ? null
                        : () async {
                            final withdrawn = await controller.withdraw();
                            if (!mounted || !withdrawn) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Application withdrawn.'),
                              ),
                            );
                          },
                    child: const Text('Withdraw application'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required int minLength,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) => (value?.trim().length ?? 0) < minLength
          ? 'Enter at least $minLength characters.'
          : null,
    );
  }

  void _initialize(InfluencerApplication application) {
    _initializedFields = true;
    _displayName.text = application.displayName ?? '';
    _platform = application.socialPlatform ?? 'instagram';
    _profileUrl.text = application.profileUrl ?? '';
    _followerCount.text = application.followerCount?.toString() ?? '';
    _category.text = application.contentCategory ?? '';
    _message.text = application.applicationMessage ?? '';
    _agreed = application.rulesAgreed;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review and accept the rules to apply.')),
      );
      return;
    }
    final saved =
        await context.read<InfluencerApplicationController>().saveAndSubmit(
              InfluencerApplicationDraft(
                displayName: _displayName.text.trim(),
                socialPlatform: _platform,
                profileUrl: _profileUrl.text.trim(),
                followerCount: int.parse(_followerCount.text.trim()),
                contentCategory: _category.text.trim(),
                applicationMessage: _message.text.trim(),
                rulesAgreed: _agreed,
              ),
            );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application submitted for review.')),
    );
  }

  Future<void> _showRulesSummary() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Creator and Community Rules'),
        content: const Text(
          'Submit accurate, lawful, original recommendations. Disclose material relationships, do not impersonate businesses, respect privacy, and keep promotional terms clear. Content may be moderated or removed when it creates safety, trust, or legal risk. This summary requires legal review before release.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ');
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: Text('Application: $label'),
        subtitle: Text(
          switch (status) {
            'approved' => 'Creator access has been granted.',
            'rejected' => 'You may revise your information and reapply.',
            'needs_information' =>
              'Update the requested information and resubmit.',
            'withdrawn' => 'You may start a new application.',
            _ => 'You will see the outcome here after review.',
          },
        ),
      ),
    );
  }
}
