import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/spot_controller.dart';
import '../features/spots/domain/spot_repository.dart';

class SubmitSpotScreen extends StatefulWidget {
  const SubmitSpotScreen({super.key});

  @override
  State<SubmitSpotScreen> createState() => _SubmitSpotScreenState();
}

class _SubmitSpotScreenState extends State<SubmitSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _bestTime = TextEditingController();
  final _thingsToDo = TextEditingController();

  String _state = 'Penang';
  String _category = 'Kopitiam';
  String _priceRange = r'$';
  Uint8List? _imageBytes;
  String? _imageMimeType;
  SpotDraftResult? _createdDraft;
  bool _submitting = false;

  static const _states = [
    'Penang',
    'Kuala Lumpur',
    'Perak',
    'Johor',
    'Selangor',
    'Melaka',
    'Sabah',
    'Sarawak',
  ];
  static const _categories = [
    'Kopitiam',
    'Pasar Malam',
    'Indie Cafe',
    'Park / Walkway',
    'Hawker Food',
    'Heritage Spot',
  ];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    _address.dispose();
    _bestTime.dispose();
    _thingsToDo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final spotController = context.watch<SpotController>();
    if (!auth.canWrite) {
      return Scaffold(
        appBar: AppBar(title: const Text('Submit a local spot')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Sign in with a verified, active account to submit a spot.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        title: const Text('Submit a local spot'),
        backgroundColor: const Color(0xFFF7F5F0),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Share a place worth discovering',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your submission stays private until an administrator approves it. Material edits create a new reviewable revision.',
            ),
            const SizedBox(height: 24),
            _field(_name, 'Spot name', minLength: 2, maxLength: 120),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    label: 'Category',
                    value: _category,
                    values: _categories,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _dropdown(
                    label: 'State',
                    value: _state,
                    values: _states,
                    onChanged: (value) => setState(() => _state = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field(_city, 'City or area', minLength: 2, maxLength: 100),
            const SizedBox(height: 16),
            _field(_address, 'Full address', minLength: 5, maxLength: 300),
            const SizedBox(height: 16),
            _field(
              _description,
              'Why is this place useful or special?',
              minLength: 20,
              maxLength: 3000,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _field(_bestTime, 'Best visiting time',
                minLength: 2, maxLength: 160),
            const SizedBox(height: 16),
            _field(
              _thingsToDo,
              'What should visitors do or try?',
              minLength: 2,
              maxLength: 500,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _dropdown(
              label: 'Price range',
              value: _priceRange,
              values: const [r'$', r'$$', r'$$$', r'$$$$'],
              onChanged: (value) => setState(() => _priceRange = value),
            ),
            const SizedBox(height: 24),
            Text('Photo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: _submitting ? null : _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: _imageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40),
                          SizedBox(height: 8),
                          Text('Choose a JPEG, PNG or WebP photo (max 8 MB)'),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            if (spotController.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                spotController.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _createdDraft == null
                          ? 'Check and submit'
                          : 'Resolve probable duplicate',
                    ),
            ),
          ],
        ),
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
      maxLines: maxLines,
      maxLength: maxLength,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) {
        final length = value?.trim().length ?? 0;
        if (length < minLength) return 'Enter at least $minLength characters.';
        return null;
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Future<void> _pickImage() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 88,
    );
    if (selected == null || !mounted) return;
    final bytes = await selected.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      _message('Choose a photo no larger than 8 MB.');
      return;
    }
    setState(() {
      _imageBytes = bytes;
      _imageMimeType = selected.mimeType ?? _mimeFromName(selected.name);
      _createdDraft = null;
    });
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    if (_createdDraft != null) {
      await _resolveDuplicates(_createdDraft!);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      _message('Choose a clear photo of the place.');
      return;
    }
    setState(() => _submitting = true);
    final result = await context.read<SpotController>().submitDraft(
          input: SpotDraftInput(
            name: _name.text.trim(),
            category: _category,
            description: _description.text.trim(),
            state: _state,
            city: _city.text.trim(),
            address: _address.text.trim(),
            priceRange: _priceRange,
            bestTime: _bestTime.text.trim(),
            thingsToDo: _thingsToDo.text.trim(),
          ),
          imageBytes: _imageBytes,
          imageMimeType: _imageMimeType,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) return;
    if (result.probableDuplicates.isNotEmpty) {
      setState(() => _createdDraft = result);
      await _resolveDuplicates(result);
      return;
    }
    _finish();
  }

  Future<void> _resolveDuplicates(SpotDraftResult draft) async {
    final reasonController = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('This may already be listed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Review these probable matches before creating another listing:'),
              const SizedBox(height: 12),
              ...draft.probableDuplicates.map(
                (duplicate) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(duplicate.name),
                  subtitle: Text(
                      '${duplicate.address}\n${duplicate.city}, ${duplicate.state}'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Why is this a different place?',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'existing'),
            child: const Text('Use existing listing'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().length < 10) return;
              Navigator.pop(dialogContext, 'override');
            },
            child: const Text('Submit as different'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (!mounted || action == null) return;
    if (action == 'existing') {
      setState(() => _submitting = true);
      final discarded =
          await context.read<SpotController>().discardDraft(draft);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!discarded) return;
      _message('Draft discarded. Open the existing listing from discovery.');
      Navigator.pop(context);
      return;
    }
    setState(() => _submitting = true);
    final submitted = await context.read<SpotController>().submitExistingDraft(
          draft.revisionId,
          reason,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (submitted) _finish();
  }

  void _finish() {
    _message('Spot submitted for review.');
    Navigator.pop(context);
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}
