import '../../domain/entities/pricing_policy.dart';
import '../../domain/entities/pricing_snapshot.dart';
import '../../domain/enums/pricing_enums.dart';
import '../../domain/repositories/i_pricing_repository.dart';
import '../datasources/pricing_remote_datasource.dart';

/// تطبيق مستودع التسعير (PricingRepository)
class PricingRepository implements IPricingRepository {
  final PricingRemoteDatasource _remoteDatasource;

  PricingRepository({PricingRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? PricingRemoteDatasource();

  @override
  Future<PricingPolicy> getActivePolicy(PricingServiceType serviceType) {
    return _remoteDatasource.getActivePolicy(serviceType);
  }

  @override
  Future<PricingSnapshot> saveSnapshot(PricingSnapshot snapshot) {
    return _remoteDatasource.saveSnapshot(snapshot);
  }

  @override
  Future<PricingSnapshot?> getSnapshot(String snapshotId) {
    return _remoteDatasource.getSnapshot(snapshotId);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) {
    return _remoteDatasource.verifyIdempotencyKey(idempotencyKey);
  }
}
