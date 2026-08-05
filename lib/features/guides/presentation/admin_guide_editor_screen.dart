import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../domain/guide_repository.dart';
import 'guide_controller.dart';

class AdminGuideEditorScreen extends StatefulWidget {
  const AdminGuideEditorScreen({super.key});

  @override
  State<AdminGuideEditorScreen> createState() => _AdminGuideEditorScreenState();
}

class _AdminGuideEditorScreenState extends State<AdminGuideEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _state = TextEditingController();
  final _overview = TextEditingController();
  final _stops = TextEditingController();
  final _sequence = TextEditingController();
  final _duration = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _state.dispose();
    _overview.dispose();
    _stops.dispose();
    _sequence.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().currentUser?.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Administrator permission is required.')),
      );
    }
    final controller = context.watch<GuideController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create guide draft')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Text(
              'Admin-curated neighbourhood guide',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Save a draft first. Publication is a separate audited action from the admin dashboard.',
            ),
            const SizedBox(height: 20),
            _field(_title, 'Guide title', minLength: 3, maxLength: 160),
            const SizedBox(height: 16),
            _field(_location, 'Neighbourhood or location', maxLength: 120),
            const SizedBox(height: 16),
            _field(_state, 'State or territory', maxLength: 80),
            const SizedBox(height: 16),
            _field(
              _overview,
              'Route overview',
              minLength: 20,
              maxLength: 3000,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _field(
              _stops,
              'Stops — one per line',
              minLength: 2,
              maxLength: 6000,
              maxLines: 7,
            ),
            const SizedBox(height: 16),
            _field(
              _sequence,
              'Walking instructions — one per stop',
              minLength: 2,
              maxLength: 10000,
              maxLines: 7,
            ),
            const SizedBox(height: 16),
            _field(_duration, 'Estimated duration', maxLength: 80),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: controller.isLoading ? null : _save,
              child: Text(controller.isLoading ? 'Saving…' : 'Save draft'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int minLength = 2,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      minLines: maxLines == 1 ? 1 : 2,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => (value?.trim().length ?? 0) < minLength
          ? 'Enter at least $minLength characters.'
          : null,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final stops = _lines(_stops.text);
    final sequence = _lines(_sequence.text);
    if (stops.isEmpty || stops.length != sequence.length) {
      _message('Provide exactly one walking instruction for each stop.');
      return;
    }
    final controller = context.read<GuideController>();
    final saved = await controller.createDraft(
      GuideDraftInput(
        title: _title.text.trim(),
        locationName: _location.text.trim(),
        state: _state.text.trim(),
        routeOverview: _overview.text.trim(),
        stops: stops,
        walkingSequence: sequence,
        estimatedDuration: _duration.text.trim(),
      ),
    );
    if (!mounted) return;
    if (!saved) {
      _message(controller.errorMessage ?? 'The draft could not be saved.');
      return;
    }
    _message('Guide draft saved. Review it in the admin dashboard.');
    Navigator.pop(context);
  }

  List<String> _lines(String value) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
