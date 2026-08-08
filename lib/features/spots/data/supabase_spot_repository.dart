import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../models/spot_model.dart';
import '../domain/spot_repository.dart';

class SupabaseSpotRepository implements SpotRepository {
  SupabaseSpotRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SpotModel>> fetchPublicSpots({
    String? query,
    String? state,
    String? category,
    required int offset,
    required int limit,
  }) async {
    try {
      var request = _client.from('published_spots').select();
      if (state != null && state != 'All') request = request.eq('state', state);
      if (category != null && category != 'All') {
        request = request.eq('category', category);
      }
      final normalizedQuery = query?.trim() ?? '';
      if (normalizedQuery.isNotEmpty) {
        final safe = normalizedQuery.replaceAll(RegExp(r'[%_,()]'), ' ');
        request = request.or(
          'name.ilike.%$safe%,city.ilike.%$safe%,description.ilike.%$safe%',
        );
      }
      final response = await request
          .order('updated_at', ascending: false)
          .range(offset, offset + limit - 1);
      return Future.wait(
        (response as List<dynamic>).map(
          (row) => _mapPublicSpot(Map<String, dynamic>.from(row as Map)),
        ),
      );
    } on PostgrestException catch (error) {
      throw _dataError(error, 'Local spots could not be loaded.');
    }
  }

  @override
  Future<List<SpotModel>> fetchPendingModeration() async {
    try {
      final response = await _client
          .from('spot_revisions')
          .select('*, spots!inner(id, moderation_version)')
          .inFilter(
              'status', ['submitted', 'under_review']).order('submitted_at');
      return Future.wait(
        (response as List<dynamic>).map((raw) async {
          final row = Map<String, dynamic>.from(raw as Map);
          final spot = Map<String, dynamic>.from(row['spots'] as Map);
          return SpotModel(
            id: spot['id'] as String,
            revisionId: row['id'] as String,
            moderationVersion:
                (spot['moderation_version'] as num?)?.toInt() ?? 1,
            name: row['name'] as String,
            category: row['category'] as String,
            description: row['description'] as String,
            state: row['state'] as String,
            city: row['city'] as String,
            address: row['address'] as String,
            priceRange: row['price_range'] as String,
            bestTime: row['best_time'] as String,
            thingsToDo: row['things_to_do'] as String,
            imageUrl: await _signedImage(row['image_path'] as String?),
            submittedBy: row['author_id'] as String? ?? '',
            status: row['status'] as String,
            latitude: (row['latitude'] as num?)?.toDouble(),
            longitude: (row['longitude'] as num?)?.toDouble(),
          );
        }),
      );
    } on PostgrestException catch (error) {
      throw _dataError(error, 'Pending spot submissions could not be loaded.');
    }
  }

  @override
  Future<List<SpotModel>> fetchOwnedSubmissions() async {
    try {
      final response = await _client.rpc('list_my_spot_submissions');
      return Future.wait((response as List<dynamic>).map((raw) async {
        final row = Map<String, dynamic>.from(raw as Map);
        return SpotModel(
          id: row['spot_id'] as String,
          revisionId: row['revision_id'] as String,
          moderationVersion: (row['moderation_version'] as num?)?.toInt() ?? 1,
          name: row['name'] as String,
          category: row['category'] as String,
          description: row['description'] as String,
          state: row['state'] as String,
          city: row['city'] as String,
          address: row['address'] as String,
          priceRange: row['price_range'] as String,
          bestTime: row['best_time'] as String,
          thingsToDo: row['things_to_do'] as String,
          imageUrl: await _signedImage(row['image_path'] as String?),
          imagePath: row['image_path'] as String?,
          submittedBy: _client.auth.currentUser?.id ?? '',
          status: row['status'] as String,
          decisionReason: row['decision_reason'] as String?,
          hasApprovedRevision: row['has_approved_revision'] as bool? ?? false,
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
        );
      }));
    } on PostgrestException catch (error) {
      throw _dataError(error, 'Your spot submissions could not be loaded.');
    }
  }

  @override
  Future<SpotDraftResult> createDraft({
    required SpotDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    String? uploadedPath;
    try {
      if (imageBytes != null) {
        final mimeType = imageMimeType ?? '';
        uploadedPath = await _uploadImage(imageBytes, mimeType);
      }

      final response = await _client.rpc('create_spot_draft', params: {
        'p_name': input.name,
        'p_category': input.category,
        'p_description': input.description,
        'p_state': input.state,
        'p_city': input.city,
        'p_address': input.address,
        'p_price_range': input.priceRange,
        'p_best_time': input.bestTime,
        'p_things_to_do': input.thingsToDo,
        'p_image_path': uploadedPath,
        'p_latitude': input.latitude,
        'p_longitude': input.longitude,
      });
      final map = Map<String, dynamic>.from(response as Map);
      final duplicates =
          (map['probable_duplicates'] as List<dynamic>? ?? []).map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return ProbableSpotDuplicate(
          id: item['id'] as String,
          name: item['name'] as String,
          address: item['address'] as String,
          city: item['city'] as String,
          state: item['state'] as String,
        );
      }).toList();
      return SpotDraftResult(
        spotId: map['spot_id'] as String,
        revisionId: map['revision_id'] as String,
        probableDuplicates: duplicates,
        imagePath: map['image_path'] as String?,
      );
    } on AppException {
      rethrow;
    } on StorageException catch (error) {
      throw AppException(
        code: AppErrorCode.unavailable,
        userMessage: 'The spot photo could not be uploaded. Try again.',
        technicalMessage: error.message,
        cause: error,
      );
    } on PostgrestException catch (error) {
      if (uploadedPath != null) {
        try {
          await _client.storage.from('spot-images').remove([uploadedPath]);
        } catch (cleanupError) {
          if (kDebugMode) {
            debugPrint('Spot image cleanup failed: $cleanupError');
          }
        }
      }
      throw _dataError(error, 'The spot draft could not be saved.');
    }
  }

  @override
  Future<SpotDraftResult> saveRevisionDraft({
    required SpotModel source,
    required SpotDraftInput input,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    String? uploadedPath;
    try {
      if (imageBytes != null) {
        uploadedPath = await _uploadImage(imageBytes, imageMimeType ?? '');
      }
      final response = await _client.rpc('save_spot_revision_draft', params: {
        'p_source_revision_id': source.revisionId,
        'p_name': input.name,
        'p_category': input.category,
        'p_description': input.description,
        'p_state': input.state,
        'p_city': input.city,
        'p_address': input.address,
        'p_price_range': input.priceRange,
        'p_best_time': input.bestTime,
        'p_things_to_do': input.thingsToDo,
        'p_image_path': uploadedPath,
        'p_latitude': input.latitude,
        'p_longitude': input.longitude,
      });
      final map = Map<String, dynamic>.from(response as Map);
      return _draftResult(map);
    } on StorageException catch (error) {
      throw AppException(
        code: AppErrorCode.unavailable,
        userMessage: 'The revised spot photo could not be uploaded.',
        technicalMessage: error.message,
        cause: error,
      );
    } on PostgrestException catch (error) {
      if (uploadedPath != null) {
        await _removeFailedUpload(uploadedPath);
      }
      throw _dataError(error, 'The spot revision could not be saved.');
    }
  }

  @override
  Future<void> deleteDraft({
    required String revisionId,
    String? imagePath,
  }) async {
    try {
      await _client.rpc(
        'delete_spot_draft',
        params: {'p_revision_id': revisionId},
      );
    } on PostgrestException catch (error) {
      throw _dataError(error, 'The spot draft could not be discarded.');
    }
  }

  @override
  Future<void> withdrawRevision(String revisionId) async {
    try {
      await _client.rpc(
        'withdraw_my_spot_revision',
        params: {'p_revision_id': revisionId},
      );
    } on PostgrestException catch (error) {
      throw _dataError(error, 'The spot submission could not be withdrawn.');
    }
  }

  @override
  Future<void> submitRevision({
    required String revisionId,
    String? duplicateOverrideReason,
  }) async {
    try {
      await _client.rpc('submit_spot_revision', params: {
        'p_revision_id': revisionId,
        'p_duplicate_override_reason': duplicateOverrideReason,
      });
    } on PostgrestException catch (error) {
      throw _dataError(
        error,
        error.code == '23505'
            ? 'A probable duplicate needs to be resolved before submission.'
            : 'The spot could not be submitted.',
      );
    }
  }

  @override
  Future<void> confirmImageRights(String revisionId) async {
    try {
      await _client.rpc(
        'confirm_spot_image_rights',
        params: {'p_revision_id': revisionId},
      );
    } on PostgrestException catch (error) {
      throw _dataError(
        error,
        'Photo rights could not be confirmed for this draft.',
      );
    }
  }

  @override
  Future<void> moderateRevision({
    required String revisionId,
    required String decision,
    required String reason,
    required int expectedVersion,
  }) async {
    try {
      await _client.rpc('admin_moderate_spot_revision', params: {
        'p_revision_id': revisionId,
        'p_decision': decision,
        'p_reason': reason,
        'p_expected_version': expectedVersion,
      });
    } on PostgrestException catch (error) {
      throw _dataError(
        error,
        error.code == '40001'
            ? 'This submission changed. Refresh and try again.'
            : 'The moderation decision could not be saved.',
      );
    }
  }

  Future<SpotModel> _mapPublicSpot(Map<String, dynamic> row) async {
    return SpotModel(
      id: row['id'] as String,
      revisionId: row['revision_id'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      description: row['description'] as String,
      state: row['state'] as String,
      city: row['city'] as String,
      address: row['address'] as String,
      priceRange: row['price_range'] as String,
      bestTime: row['best_time'] as String,
      thingsToDo: row['things_to_do'] as String,
      imageUrl: await _signedImage(row['image_path'] as String?),
      rating: (row['rating_average'] as num?)?.toDouble() ?? 0,
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
      submittedBy: '',
      status: 'approved',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }

  Future<String> _signedImage(String? path) async {
    if (path == null || path.isEmpty) return '';
    return _client.storage.from('spot-images').createSignedUrl(path, 3600);
  }

  Future<String> _uploadImage(Uint8List bytes, String mimeType) async {
    _validateImage(bytes, mimeType);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException(
        code: AppErrorCode.authentication,
        userMessage: 'Sign in to submit a spot.',
      );
    }
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage.from('spot-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );
    return path;
  }

  SpotDraftResult _draftResult(Map<String, dynamic> map) {
    final duplicates =
        (map['probable_duplicates'] as List<dynamic>? ?? []).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return ProbableSpotDuplicate(
        id: item['id'] as String,
        name: item['name'] as String,
        address: item['address'] as String,
        city: item['city'] as String,
        state: item['state'] as String,
      );
    }).toList();
    return SpotDraftResult(
      spotId: map['spot_id'] as String,
      revisionId: map['revision_id'] as String,
      probableDuplicates: duplicates,
      imagePath: map['image_path'] as String?,
    );
  }

  Future<void> _removeFailedUpload(String path) async {
    try {
      await _client.storage.from('spot-images').remove([path]);
    } catch (cleanupError) {
      if (kDebugMode) {
        debugPrint('Spot image cleanup failed: $cleanupError');
      }
    }
  }

  void _validateImage(Uint8List bytes, String mimeType) {
    const maxBytes = 8 * 1024 * 1024;
    final validMime = {'image/jpeg', 'image/png', 'image/webp'};
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        !validMime.contains(mimeType)) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'Choose a JPEG, PNG or WebP photo up to 8 MB.',
      );
    }
    final matches = switch (mimeType) {
      'image/jpeg' => bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8,
      'image/png' => bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50,
      'image/webp' => bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP',
      _ => false,
    };
    if (!matches) {
      throw const AppException(
        code: AppErrorCode.validation,
        userMessage: 'The selected file is not a valid supported image.',
      );
    }
  }

  AppException _dataError(PostgrestException error, String message) {
    if (error.message == 'UGC_RULES_ACCEPTANCE_REQUIRED') {
      return AppException(
        code: AppErrorCode.forbidden,
        userMessage: 'UGC_RULES_ACCEPTANCE_REQUIRED',
        technicalMessage: error.message,
        cause: error,
      );
    }
    if (error.code == '22023' && error.message == 'UGC_CONTENT_RESTRICTED') {
      return AppException(
        code: AppErrorCode.validation,
        userMessage:
            'Your content contains restricted words. Please revise it and try again.',
        technicalMessage: error.message,
        cause: error,
      );
    }
    return AppException(
      code: error.code == '40001'
          ? AppErrorCode.conflict
          : AppErrorCode.unexpected,
      userMessage: message,
      technicalMessage: error.message,
      cause: error,
    );
  }
}
