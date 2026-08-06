import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/localeats_controller.dart';
import '../features/restaurants/domain/local_eats_repository.dart';
import '../models/discount_code_model.dart';

class ManageDiscountScreen extends StatefulWidget {
  const ManageDiscountScreen({super.key});

  @override
  State<ManageDiscountScreen> createState() => _ManageDiscountScreenState();
}

class _ManageDiscountScreenState extends State<ManageDiscountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _terms = TextEditingController();
  String? _restaurantId;
  DateTime _startsAt = DateTime.now();
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LocalEatsController>().loadOwnedDiscounts();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _description.dispose();
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().currentUser?.role != 'influencer') {
      return const Scaffold(
        body: Center(child: Text('Approved creator access is required.')),
      );
    }
    final controller = context.watch<LocalEatsController>();
    final restaurants = controller.ownedApprovedRestaurants;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage discounts')),
      body: restaurants.isEmpty
          ? _NoApprovedRestaurant(
              onRefresh: () => context.read<LocalEatsController>().loadData())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Text(
                    'Your offers',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (controller.ownedDiscounts.isEmpty)
                    const Text('No creator offers have been created yet.')
                  else
                    ...controller.ownedDiscounts.map(
                      (discount) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OwnedDiscountCard(
                          discount: discount,
                          onAction: (action) => _transition(discount, action),
                        ),
                      ),
                    ),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Create an offer',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Discounts can only be attached to your approved listing. LiveLocal displays the offer but does not process payment or guarantee merchant acceptance.',
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _restaurantId,
                    decoration: const InputDecoration(
                      labelText: 'Approved restaurant',
                      border: OutlineInputBorder(),
                    ),
                    items: restaurants
                        .map(
                          (restaurant) => DropdownMenuItem(
                            value: restaurant.id,
                            child: Text(restaurant.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _restaurantId = value),
                    validator: (value) =>
                        value == null ? 'Choose a restaurant.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    maxLength: 32,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'LOCAL10',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final normalized = value?.trim() ?? '';
                      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{2,31}$')
                          .hasMatch(normalized)) {
                        return 'Use 3–32 letters, numbers, hyphens or underscores.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Offer description',
                      border: OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _terms,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Redemption terms',
                      hintText:
                          'State exclusions, minimum spend, and how to redeem.',
                      border: OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 8),
                  _DateTimeTile(
                    label: 'Starts',
                    value: _startsAt,
                    onTap: () => _chooseDateTime(start: true),
                  ),
                  const SizedBox(height: 8),
                  _DateTimeTile(
                    label: 'Expires',
                    value: _expiresAt,
                    onTap: () => _chooseDateTime(start: false),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Creating…' : 'Create discount'),
                  ),
                ],
              ),
            ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _chooseDateTime({required bool start}) async {
    final initial = start ? _startsAt : _expiresAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = value;
      } else {
        _expiresAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_expiresAt.isAfter(_startsAt)) {
      _message('Expiry must be after the start time.');
      return;
    }
    setState(() => _saving = true);
    final saved = await context.read<LocalEatsController>().createDiscount(
          DiscountDraftInput(
            restaurantId: _restaurantId!,
            code: _code.text.trim().toUpperCase(),
            description: _description.text.trim(),
            redemptionTerms: _terms.text.trim(),
            startsAt: _startsAt,
            expiresAt: _expiresAt,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      _message(context.read<LocalEatsController>().errorMessage ??
          'The discount could not be created.');
      return;
    }
    _message(
      _startsAt.isAfter(DateTime.now())
          ? 'Discount scheduled.'
          : 'Discount is active.',
    );
    Navigator.pop(context);
  }

  Future<void> _transition(
    DiscountCodeModel discount,
    String action,
  ) async {
    if (action == 'revoke') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Revoke this discount?'),
          content: const Text(
            'Revocation is immediate and cannot be reversed. The offer will stop appearing as active.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Revoke'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final saved = await context
        .read<LocalEatsController>()
        .transitionDiscount(discount, action);
    if (!mounted) return;
    _message(
      saved
          ? 'Discount status updated.'
          : context.read<LocalEatsController>().errorMessage ??
              'The discount status could not be updated.',
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _OwnedDiscountCard extends StatelessWidget {
  const _OwnedDiscountCard({
    required this.discount,
    required this.onAction,
  });

  final DiscountCodeModel discount;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final canPause =
        discount.status == 'active' || discount.status == 'scheduled';
    final canResume = discount.status == 'paused' && !discount.isExpired;
    final canRevoke = discount.status != 'revoked' && !discount.isExpired;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    discount.code,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(discount.status.replaceAll('_', ' '))),
              ],
            ),
            const SizedBox(height: 4),
            Text(discount.description),
            if (canPause || canResume || canRevoke) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (canPause)
                    TextButton(
                      onPressed: () => onAction('pause'),
                      child: const Text('Pause'),
                    ),
                  if (canResume)
                    TextButton(
                      onPressed: () => onAction('resume'),
                      child: const Text('Resume'),
                    ),
                  if (canRevoke)
                    TextButton(
                      onPressed: () => onAction('revoke'),
                      child: const Text('Revoke'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoApprovedRestaurant extends StatelessWidget {
  const _NoApprovedRestaurant({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'No approved owned restaurant',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'A restaurant must be approved and remain owned by your creator account before you can add a discount.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final formatted =
        '${localizations.formatMediumDate(value)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
    return ListTile(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(label),
      subtitle: Text(formatted),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: onTap,
    );
  }
}
