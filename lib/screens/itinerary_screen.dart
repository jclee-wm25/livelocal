import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/itinerary_controller.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/spot_controller.dart';
import '../features/itinerary/domain/saved_itinerary_repository.dart';
import '../widgets/timeline_step_card.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ItineraryController>().loadItineraries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ItineraryController>();
    final steps = controller.itinerarySteps;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        title: const Text('Itineraries'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          Text(
            'Plan a route from your saved places',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a manual starting city or request your device location. Route order is an estimate based on straight-line proximity, not travel time.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.isGeneratingItinerary
                ? null
                : _chooseOriginAndCreate,
            icon: const Icon(Icons.route_outlined),
            label: Text(
              controller.isGeneratingItinerary
                  ? 'Creating itinerary…'
                  : 'Create itinerary',
            ),
          ),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(controller.errorMessage!),
              ),
            ),
          ],
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'New route',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...List.generate(steps.length, (index) {
              return TimelineStepCard(
                step: steps[index],
                index: index,
                isLast: index == steps.length - 1,
              );
            }),
          ],
          const SizedBox(height: 28),
          Text(
            'Saved itineraries',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (controller.savedItineraries.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No saved itinerary yet. Creating a route saves its order to your account.',
                ),
              ),
            )
          else
            ...controller.savedItineraries.map(
              (itinerary) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(itinerary.title),
                  subtitle: Text(
                    '${itinerary.originLabel} · ${itinerary.targets.length} stops',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseOriginAndCreate() async {
    final title = TextEditingController(text: 'My local day');
    var mode = 'manual';
    var city = _manualOrigins.first;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create itinerary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Plan title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'manual',
                    icon: Icon(Icons.location_city_outlined),
                    label: Text('Choose city'),
                  ),
                  ButtonSegment(
                    value: 'device',
                    icon: Icon(Icons.my_location_outlined),
                    label: Text('Device location'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (values) =>
                    setSheetState(() => mode = values.single),
              ),
              const SizedBox(height: 16),
              if (mode == 'manual')
                DropdownButtonFormField<_ManualOrigin>(
                  initialValue: city,
                  decoration: const InputDecoration(
                    labelText: 'Starting city',
                    border: OutlineInputBorder(),
                  ),
                  items: _manualOrigins
                      .map(
                        (origin) => DropdownMenuItem(
                          value: origin,
                          child: Text(origin.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => city = value ?? city),
                )
              else
                const Text(
                  'LiveLocal will ask for foreground location only after you continue. Denying permission will not block discovery; you can return and choose a city.',
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (title.text.trim().length < 2) return;
                  Navigator.pop(sheetContext, true);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
    final planTitle = title.text.trim();
    title.dispose();
    if (confirmed != true || !mounted) return;

    RouteOrigin? origin;
    final controller = context.read<ItineraryController>();
    if (mode == 'device') {
      origin = await controller.requestDeviceOrigin();
      if (!mounted || origin == null) return;
    } else {
      origin = RouteOrigin(
        label: city.label,
        latitude: city.latitude,
        longitude: city.longitude,
        mode: 'manual',
        state: city.state,
        city: city.city,
      );
    }
    final saved = await controller.generateAndSaveItinerary(
      title: planTitle,
      origin: origin,
      allSpots: context.read<SpotController>().spots,
      allRestaurants: context.read<LocalEatsController>().restaurants,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Itinerary saved.'
              : controller.errorMessage ?? 'The itinerary could not be saved.',
        ),
      ),
    );
  }
}

class _ManualOrigin {
  const _ManualOrigin({
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
  });

  final String city;
  final String state;
  final double latitude;
  final double longitude;

  String get label => '$city, $state';
}

const _manualOrigins = [
  _ManualOrigin(
    city: 'Kuala Lumpur',
    state: 'Kuala Lumpur',
    latitude: 3.1390,
    longitude: 101.6869,
  ),
  _ManualOrigin(
    city: 'George Town',
    state: 'Penang',
    latitude: 5.4141,
    longitude: 100.3288,
  ),
  _ManualOrigin(
    city: 'Ipoh',
    state: 'Perak',
    latitude: 4.5975,
    longitude: 101.0901,
  ),
  _ManualOrigin(
    city: 'Johor Bahru',
    state: 'Johor',
    latitude: 1.4927,
    longitude: 103.7414,
  ),
  _ManualOrigin(
    city: 'Melaka City',
    state: 'Melaka',
    latitude: 2.1896,
    longitude: 102.2501,
  ),
  _ManualOrigin(
    city: 'Kota Kinabalu',
    state: 'Sabah',
    latitude: 5.9804,
    longitude: 116.0735,
  ),
  _ManualOrigin(
    city: 'Kuching',
    state: 'Sarawak',
    latitude: 1.5533,
    longitude: 110.3592,
  ),
];
