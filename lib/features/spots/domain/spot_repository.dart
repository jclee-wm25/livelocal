import 'dart:typed_data';

import '../../../models/spot_model.dart';

class SpotDraftInput {
  const SpotDraftInput({
    required this.name,
    required this.category,
    required this.description,
    required this.state,
    required this.city,
    required this.address,
    required this.priceRange,
    required this.bestTime,
    required this.thingsToDo,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String category;
  final String description;
  final String state;
  final String city;
  final String address;
  final String priceRange;
  final String bestTime;
  final String thingsToDo;
  final double? latitude;
  final double? longitude;
}

class ProbableSpotDuplicate {
  const ProbableSpotDuplicate({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
}

class SpotDraftResult {
  const SpotDraftResult({
    required this.spotId,
    required this.revisionId,
    required this.probableDuplicates,
    this.imagePath,
  });

  final String spotId;
  final String revisionId;
  final List<ProbableSpotDuplicate> probableDuplicates;
  final String? imagePath;
}

abstract interface class SpotRepository {
  Future<List<SpotModel>> fetchPublicSpots({
    String? query,
    String? state,
    String? category,
    required int offset,
    required int limit,
  });

  Future<List<SpotModel>> fetchPendingModeration();

  Future<SpotDraftResult> createDraft({
    required SpotDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
  });

  Future<void> submitRevision({
    required String revisionId,
    String? duplicateOverrideReason,
  });

  Future<void> deleteDraft({
    required String revisionId,
    String? imagePath,
  });

  Future<void> moderateRevision({
    required String revisionId,
    required String decision,
    required String reason,
    required int expectedVersion,
  });
}
