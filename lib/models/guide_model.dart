class GuideModel {
  final String id;
  final String title;
  final String locationName;
  final String state;
  final String routeOverview;
  final List<String> stops;
  final List<String> walkingSequence;
  final String estimatedDuration;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;

  GuideModel({
    required this.id,
    required this.title,
    required this.locationName,
    required this.state,
    required this.routeOverview,
    required this.stops,
    required this.walkingSequence,
    required this.estimatedDuration,
    this.status = 'approved',
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'location_name': locationName,
        'state': state,
        'route_overview': routeOverview,
        'stops': stops,
        'walking_sequence': walkingSequence,
        'estimated_duration': estimatedDuration,
        'status': status,
        'rejection_reason': rejectionReason,
      };

  factory GuideModel.fromMap(Map<String, dynamic> map) => GuideModel(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        locationName: map['location_name'] ?? '',
        state: map['state'] ?? '',
        routeOverview: map['route_overview'] ?? '',
        stops: List<String>.from(map['stops'] ?? []),
        walkingSequence: List<String>.from(map['walking_sequence'] ?? []),
        estimatedDuration: map['estimated_duration'] ?? '',
        status: map['status'] ?? 'approved',
        rejectionReason: map['rejection_reason'],
      );
}
