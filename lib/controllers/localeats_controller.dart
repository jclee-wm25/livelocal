import 'package:flutter/foundation.dart';

abstract class LocalEatsRepository {}

class DemoLocalEatsRepository implements LocalEatsRepository {
  DemoLocalEatsRepository(dynamic authRepo);
}

class SupabaseLocalEatsRepository implements LocalEatsRepository {
  SupabaseLocalEatsRepository(dynamic client);
}

class LocalEatsController with ChangeNotifier {
  LocalEatsController({required LocalEatsRepository repository});

  bool get isLoading => false;
  String? get errorMessage => null;
  List<dynamic> get restaurants => [];
  List<dynamic> get pendingRestaurants => [];

  Future<void> loadData() async {}
  Future<void> loadPendingRestaurants() async {}
  Future<void> loadOwnedDiscounts() async {}
}
