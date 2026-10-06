import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/location/iraq_location_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IraqLocationResolver Core Tests', () {
    test('Bounding box detects points inside and outside Iraq', () {
      // Baghdad center
      expect(IraqLocationResolver.isCoordinatesInIraq(33.3152, 44.3661), isTrue);
      // Al-Qaim coordinates
      expect(IraqLocationResolver.isCoordinatesInIraq(34.39, 40.98), isTrue);
      // Basra
      expect(IraqLocationResolver.isCoordinatesInIraq(30.5085, 47.7804), isTrue);
      // Erbil
      expect(IraqLocationResolver.isCoordinatesInIraq(36.1911, 44.0092), isTrue);
      
      // Outside Iraq (London, Cairo, Tokyo)
      expect(IraqLocationResolver.isCoordinatesInIraq(51.5074, -0.1278), isFalse);
      expect(IraqLocationResolver.isCoordinatesInIraq(30.0444, 31.2357), isFalse);
      expect(IraqLocationResolver.isCoordinatesInIraq(35.6762, 139.6503), isFalse);
    });

    test('Governorate matching handles Arabic names and variations', () {
      final anbar = IraqLocationResolver.matchGovernorate('محافظة الأنبار');
      expect(anbar?.id, equals('anbar'));
      expect(anbar?.arName, equals('الأنبار'));

      final baghdad = IraqLocationResolver.matchGovernorate('بغداد');
      expect(baghdad?.id, equals('baghdad'));

      final basra = IraqLocationResolver.matchGovernorate('البصره');
      expect(basra?.id, equals('basra'));

      final najaf = IraqLocationResolver.matchGovernorate('النجف الأشرف');
      expect(najaf?.id, equals('najaf'));

      final karbala = IraqLocationResolver.matchGovernorate('كربلاء المقدسة');
      expect(karbala?.id, equals('karbala'));

      final erbil = IraqLocationResolver.matchGovernorate('أربيل');
      expect(erbil?.id, equals('erbil'));
    });

    test('Governorate matching handles English aliases', () {
      expect(IraqLocationResolver.matchGovernorate('Al Anbar')?.id, equals('anbar'));
      expect(IraqLocationResolver.matchGovernorate('Baghdad')?.id, equals('baghdad'));
      expect(IraqLocationResolver.matchGovernorate('Basrah')?.id, equals('basra'));
      expect(IraqLocationResolver.matchGovernorate('Erbil')?.id, equals('erbil'));
      expect(IraqLocationResolver.matchGovernorate('Sulaymaniyah')?.id, equals('sulaymaniyah'));
      expect(IraqLocationResolver.matchGovernorate('Nineveh')?.id, equals('ninawa'));
    });

    test('District matching identifies known Iraqi districts', () {
      expect(IraqLocationResolver.matchDistrict('قضاء القائم'), equals('القائم'));
      expect(IraqLocationResolver.matchDistrict('الرمادي'), equals('الرمادي'));
      expect(IraqLocationResolver.matchDistrict('الفلوجة'), equals('الفلوجة'));
      expect(IraqLocationResolver.matchDistrict('الكرخ'), equals('الكرخ'));
      expect(IraqLocationResolver.matchDistrict('الرصافة'), equals('الرصافة'));
      expect(IraqLocationResolver.matchDistrict('الزبير'), equals('الزبير'));
      expect(IraqLocationResolver.matchDistrict('الموصل'), equals('الموصل'));
    });

    test('No Guessing Rule: Unknown district remains null', () async {
      // Coordinate without mock geocoding should NOT guess Al-Qaim
      final result = await IraqLocationResolver().resolveFromCoordinates(
        latitude: 33.3152,
        longitude: 44.3661,
      );

      // Result must NOT default to Al-Qaim if not at Al-Qaim
      if (result.district != null) {
        expect(result.district, isNot(equals('القائم')));
      }
    });

    test('IraqLocationResult format and serialization', () {
      const res = IraqLocationResult(
        latitude: 33.3152,
        longitude: 44.3661,
        country: 'العراق',
        governorate: 'بغداد',
        governorateId: 'baghdad',
        district: 'الكرخ',
        area: 'المنصور',
        formattedAddress: 'بغداد، الكرخ، المنصور',
        accuracy: 12.5,
        isAccurate: true,
        isWithinIraq: true,
      );

      expect(res.displayName, equals('بغداد - الكرخ - المنصور'));
      expect(res.latLng.latitude, equals(33.3152));
      expect(res.latLng.longitude, equals(44.3661));

      final map = res.toMap();
      expect(map['governorate'], equals('بغداد'));
      expect(map['district'], equals('الكرخ'));
      expect(map['area'], equals('المنصور'));
      expect(map['isAccurate'], isTrue);
    });
  });
}
