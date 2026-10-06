import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants/application/group_cart_controller.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_models.dart';

class MockGroupCartRepository extends RestaurantRepository {
  GroupCartEntity? stubGroupCart;
  bool createCalled = false;
  bool deactivateCalled = false;

  final StreamController<GroupCartEntity?> groupCartStreamController =
      StreamController<GroupCartEntity?>.broadcast();

  MockGroupCartRepository()
      : super(remoteDatasource: RestaurantRemoteDatasource());

  @override
  Future<GroupCartEntity?> getGroupCart(String code) async => stubGroupCart;

  @override
  Future<void> createGroupCart({
    required String code,
    required String hostId,
    required String hostName,
  }) async {
    createCalled = true;
    stubGroupCart = GroupCartEntity(
      code: code,
      hostId: hostId,
      hostName: hostName,
      active: true,
    );
  }

  @override
  Future<void> deactivateGroupCart(String code) async {
    deactivateCalled = true;
    stubGroupCart = null;
  }

  @override
  Stream<GroupCartEntity?> watchGroupCart(String code) =>
      groupCartStreamController.stream;

  void dispose() {
    groupCartStreamController.close();
  }
}

void main() {
  late MockGroupCartRepository mockRepo;
  late GroupCartController controller;

  setUp(() {
    mockRepo = MockGroupCartRepository();
    controller = GroupCartController(repository: mockRepo);
  });

  tearDown(() {
    controller.dispose();
    mockRepo.dispose();
  });

  group('GroupCartController Unit Tests', () {
    test('Initial state and effective cart ID before joining group', () {
      controller.setMyUid('user_123');

      expect(controller.groupCartId, isNull);
      expect(controller.isActive, isFalse);
      expect(controller.isHost, isFalse);
      expect(controller.effectiveCartId, equals('user_123'));
    });

    test('createGroupCart should set host state, action lock and update effectiveCartId and GroupCartManager', () async {
      controller.setMyUid('host_user');

      final code = await controller.createGroupCart(
        hostId: 'host_user',
        hostName: 'أحمد',
        forcedCode: '12345',
      );

      expect(code, equals('12345'));
      expect(mockRepo.createCalled, isTrue);
      expect(controller.groupCartId, equals('12345'));
      expect(controller.isActive, isTrue);
      expect(controller.isHost, isTrue);
      expect(controller.effectiveCartId, equals('12345'));
      expect(GroupCartManager.groupCartId, equals('12345'));
      expect(GroupCartManager.groupHostName, equals('أحمد'));
    });

    test('joinGroupCart should succeed on active group cart and update GroupCartManager', () async {
      controller.setMyUid('member_user');

      // 1. Inactive / Not Found
      mockRepo.stubGroupCart = null;
      final failResult = await controller.joinGroupCart('99999');
      expect(failResult, isFalse);
      expect(controller.isActive, isFalse);
      expect(controller.errorMessage, isNotNull);

      // 2. Active Group
      mockRepo.stubGroupCart = const GroupCartEntity(
        code: '55555',
        hostId: 'host_user',
        hostName: 'سارة',
        active: true,
      );

      final successResult = await controller.joinGroupCart('55555');
      expect(successResult, isTrue);
      expect(controller.groupCartId, equals('55555'));
      expect(controller.isActive, isTrue);
      expect(controller.isHost, isFalse);
      expect(controller.effectiveCartId, equals('55555'));
      expect(GroupCartManager.groupCartId, equals('55555'));
      expect(GroupCartManager.groupHostName, equals('سارة'));
    });

    test('leaveOrDeactivateGroupCart should deactivate if host and clear GroupCartManager', () async {
      controller.setMyUid('host_user');
      await controller.createGroupCart(
        hostId: 'host_user',
        hostName: 'أحمد',
        forcedCode: '12345',
      );

      expect(controller.isActive, isTrue);
      expect(GroupCartManager.groupCartId, equals('12345'));

      await controller.leaveOrDeactivateGroupCart();

      expect(mockRepo.deactivateCalled, isTrue);
      expect(controller.groupCartId, isNull);
      expect(controller.isActive, isFalse);
      expect(controller.effectiveCartId, equals('host_user'));
      expect(GroupCartManager.groupCartId, isNull);
      expect(GroupCartManager.groupHostName, isNull);
    });

    test('Stream emission of inactive group should automatically reset local group state and GroupCartManager', () async {
      controller.setMyUid('member_user');
      controller.restoreGroupCart(code: '88888', hostId: 'other_host', hostName: 'حسين');

      expect(controller.isActive, isTrue);
      expect(controller.effectiveCartId, equals('88888'));
      expect(GroupCartManager.groupCartId, equals('88888'));

      // Stream emits inactive cart
      mockRepo.groupCartStreamController.add(const GroupCartEntity(
        code: '88888',
        hostId: 'other_host',
        hostName: 'حسين',
        active: false,
      ));

      await pumpEventQueue();

      expect(controller.isActive, isFalse);
      expect(controller.groupCartId, isNull);
      expect(controller.effectiveCartId, equals('member_user'));
      expect(GroupCartManager.groupCartId, isNull);
    });
  });
}
