import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/localeats_controller.dart';
import '../core/validation/social_url_validator.dart';
import '../features/restaurants/domain/local_eats_repository.dart';
import '../models/restaurant_model.dart';

class AddRestaurantScreen extends StatefulWidget {
  const AddRestaurantScreen({super.key, this.source});

  final RestaurantModel? source;

  @override
  State<AddRestaurantScreen> createState() => _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends State<AddRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _dishes = TextEditingController();
  final _socialUrl = TextEditingController();
  String _state = 'Kuala Lumpur';
  String _cuisine = 'Malay';
  String _price = r'$';
  Uint8List? _imageBytes;
  String? _imageMimeType;
  bool _submitting = false;

  static const _states = [
    'Johor',
    'Kedah',
    'Kuala Lumpur',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Penang',
    'Perak',
    'Sabah',
    'Sarawak',
    'Selangor',
  ];
  static const _cuisines = [
    'Malay',
    'Chinese',
    'Indian',
    'Kopitiam',
    'Hawker food',
    'Western',
    'Fusion',
    'Other',
  ];

  bool get _isRevision => widget.source != null;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    if (source == null) return;
    _name.text = source.name;
    _address.text = source.address;
    _city.text = source.city;
    _dishes.text = source.reviewedDishes;
    _socialUrl.text = source.socialMediaUrl;
    if (_states.contains(source.state)) _state = source.state;
    if (_cuisines.contains(source.cuisineType)) {
      _cuisine = source.cuisineType;
    }
    _price = source.priceRange;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _dishes.dispose();
    _socialUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthController>().currentUser?.role;
    if (role != 'influencer') {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'An approved creator account is required to submit a restaurant.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRevision ? 'Revise your restaurant' : 'Submit a restaurant',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Text(
              _isRevision ? 'Restaurant revision' : 'Restaurant submission',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _isRevision
                  ? 'Your approved listing stays public while these material changes are reviewed. Prior decisions remain in history.'
                  : 'Add public business details and the TikTok or Instagram post that supports your recommendation. The listing is reviewed before publication.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Restaurant name',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _cuisine,
              decoration: const InputDecoration(
                labelText: 'Cuisine',
                border: OutlineInputBorder(),
              ),
              items: _cuisines
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _cuisine = value ?? _cuisine),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _state,
              decoration: const InputDecoration(
                labelText: 'State or territory',
                border: OutlineInputBorder(),
              ),
              items: _states
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => _state = value ?? _state),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City or area',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Public address',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _price,
              decoration: const InputDecoration(
                labelText: 'Typical price range',
                border: OutlineInputBorder(),
              ),
              items: const [r'$', r'$$', r'$$$', r'$$$$']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => _price = value ?? _price),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dishes,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Recommended dishes',
                hintText: 'What should visitors try?',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _socialUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'TikTok or Instagram post URL',
                helperText:
                    'HTTPS links from tiktok.com or instagram.com only.',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (!SocialUrlValidator.isSupported(value ?? '')) {
                  return 'Enter a supported TikTok or Instagram HTTPS URL.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _imageBytes == null
                    ? _isRevision
                        ? 'Keep or replace cover photo'
                        : 'Choose cover photo'
                    : 'Change cover photo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _imageBytes == null
                  ? _isRevision
                      ? 'The current photo will be kept unless replaced.'
                      : 'JPEG, PNG or WebP · maximum 8 MB'
                  : 'Photo selected · ${(_imageBytes!.length / 1024).ceil()} KB',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Submitting…' : 'Submit for review'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required.'
        : null;
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageMimeType = image.mimeType ?? _mimeFromName(image.name);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isRevision && (_imageBytes == null || _imageMimeType == null)) {
      _message('Choose a cover photo.');
      return;
    }
    setState(() => _submitting = true);
    final controller = context.read<LocalEatsController>();
    final input = RestaurantDraftInput(
      name: _name.text.trim(),
      address: _address.text.trim(),
      state: _state,
      city: _city.text.trim(),
      cuisineType: _cuisine,
      priceRange: _price,
      reviewedDishes: _dishes.text.trim(),
      socialMediaUrl: _socialUrl.text.trim(),
    );
    final result = _isRevision
        ? await controller.reviseRestaurant(
            source: widget.source!,
            input: input,
            imageBytes: _imageBytes,
            imageMimeType: _imageMimeType,
          )
        : await controller.createRestaurantDraft(
            input: input,
            imageBytes: _imageBytes!,
            imageMimeType: _imageMimeType!,
          );
    if (!mounted) return;
    if (result == null) {
      setState(() => _submitting = false);
      _message(controller.errorMessage ?? 'The submission could not be saved.');
      return;
    }
    if (result.probableDuplicates.isNotEmpty) {
      final resolved = await _resolveDuplicates(result);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!resolved) return;
    }
    _message(
      _isRevision
          ? 'Restaurant revision submitted for review.'
          : 'Restaurant submitted for review.',
    );
    Navigator.pop(context);
  }

  Future<bool> _resolveDuplicates(RestaurantDraftResult draft) async {
    final reason = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Possible existing listing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We found similar public listings. Avoid creating a duplicate when one of these is the same business.',
              ),
              const SizedBox(height: 12),
              ...draft.probableDuplicates.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle:
                      Text('${item.address}\n${item.city}, ${item.state}'),
                  isThreeLine: true,
                ),
              ),
              TextField(
                controller: reason,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Why this is a different listing',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard my draft'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().length < 10) return;
              Navigator.pop(dialogContext, 'submit');
            },
            child: const Text('Submit with explanation'),
          ),
        ],
      ),
    );
    final overrideReason = reason.text.trim();
    reason.dispose();
    if (!mounted || action == null) return false;
    final controller = context.read<LocalEatsController>();
    final saved = await controller.resolveRestaurantDuplicate(
      draft,
      discard: action == 'discard',
      overrideReason: action == 'submit' ? overrideReason : null,
    );
    if (!mounted || !saved) {
      _message(controller.errorMessage ??
          'The duplicate decision could not be saved.');
      return false;
    }
    if (action == 'discard') {
      _message('Draft discarded. You can use the existing listing.');
      Navigator.pop(context);
      return false;
    }
    return true;
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}
