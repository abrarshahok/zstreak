import '../domain/entitlement_repository.dart';
import 'revenue_cat_service.dart';

class RevenueCatEntitlementRepository implements EntitlementRepository {
  RevenueCatEntitlementRepository(this._service);

  final RevenueCatService _service;

  @override
  Future<bool> hasActiveEntitlement() => _service.hasActiveEntitlement();
}
