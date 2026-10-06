import '../../domain/entities/dispatch_candidate.dart';
import '../../domain/entities/dispatch_offer.dart';
import '../../domain/entities/dispatch_session.dart';
import '../../domain/enums/dispatch_enums.dart';
import '../../domain/repositories/i_dispatch_repository.dart';
import '../datasources/dispatch_remote_datasource.dart';

/// تطبيق مستودع التوزيع وتعيين السائقين (DispatchRepository)
class DispatchRepository implements IDispatchRepository {
  final DispatchRemoteDatasource _remoteDatasource;

  DispatchRepository({DispatchRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? DispatchRemoteDatasource();

  @override
  Future<List<DispatchCandidate>> getOnlineDrivers({required DispatchType dispatchType}) {
    return _remoteDatasource.getOnlineDrivers(dispatchType: dispatchType);
  }

  @override
  Future<DispatchSession> createSession(DispatchSession session) {
    return _remoteDatasource.createSession(session);
  }

  @override
  Future<DispatchSession?> getSession(String sessionId) {
    return _remoteDatasource.getSession(sessionId);
  }

  @override
  Future<DispatchOffer> createOffer(DispatchOffer offer) {
    return _remoteDatasource.createOffer(offer);
  }

  @override
  Future<DispatchOffer?> getOffer(String offerId) {
    return _remoteDatasource.getOffer(offerId);
  }

  @override
  Future<bool> acceptOfferAtomic({
    required String offerId,
    required String driverId,
    required String orderId,
    required DispatchType dispatchType,
  }) {
    return _remoteDatasource.acceptOfferAtomic(
      offerId: offerId,
      driverId: driverId,
      orderId: orderId,
      dispatchType: dispatchType,
    );
  }

  @override
  Future<bool> rejectOffer({
    required String offerId,
    required String driverId,
    required String reason,
  }) {
    return _remoteDatasource.rejectOffer(
      offerId: offerId,
      driverId: driverId,
      reason: reason,
    );
  }

  @override
  Future<void> updateSessionStatus(String sessionId, DispatchStatus status) {
    return _remoteDatasource.updateSessionStatus(sessionId, status);
  }
}
