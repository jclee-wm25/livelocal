import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/guide_controller.dart';
import '../models/guide_model.dart';
import 'guide_detail_screen.dart';
import '../shared/presentation/app_state_view.dart';

class NeighbourhoodExplorerScreen extends StatelessWidget {
  const NeighbourhoodExplorerScreen({super.key});

  static const _states = [
    'All',
    'Johor',
    'Kuala Lumpur',
    'Melaka',
    'Penang',
    'Perak',
    'Sabah',
    'Sarawak',
    'Selangor',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GuideController>();
    final guides = controller.approvedGuides;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        title: const Text('Neighbourhood guides'),
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadGuides,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curated routes for exploring locally',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Every published guide is curated and versioned by the LiveLocal team.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: controller.selectedState,
                      decoration: const InputDecoration(
                        labelText: 'State or territory',
                        border: OutlineInputBorder(),
                      ),
                      items: _states
                          .map(
                            (state) => DropdownMenuItem(
                              value: state,
                              child: Text(state),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) controller.setStateFilter(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (controller.isLoading && controller.guides.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.errorMessage != null &&
                controller.guides.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppStateView(
                  icon: Icons.wifi_off_outlined,
                  title: 'Guides could not be loaded',
                  message: controller.errorMessage!,
                  actionLabel: 'Try again',
                  onAction: controller.loadGuides,
                ),
              )
            else if (guides.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppStateView(
                  icon: Icons.explore_off_outlined,
                  title: 'No guides for ${controller.selectedState}',
                  message: 'Choose another state to see available routes.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                sliver: SliverList.separated(
                  itemCount: guides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _GuideCard(
                    guide: guides[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => GuideDetailScreen(guide: guides[index]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.onTap});

  final GuideModel guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.route_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      guide.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text('${guide.locationName}, ${guide.state}'),
              const SizedBox(height: 8),
              Text(
                guide.routeOverview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Meta(
                      icon: Icons.schedule_outlined,
                      text: guide.estimatedDuration),
                  _Meta(
                    icon: Icons.pin_drop_outlined,
                    text: '${guide.stops.length} stops',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}
