import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dalal_alqaim/features/delivery/presentation/controller/mersal_controller.dart';
import 'package:dalal_alqaim/features/delivery/presentation/controller/mersal_ui_state.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/customer_mersal_tracking_page.dart';
import 'package:dalal_alqaim/core/maps/google_maps_initializer.dart';

class MersalRequestPage extends StatelessWidget {
  const MersalRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MersalController(),
      child: const _MersalRequestView(),
    );
  }
}

class _MersalRequestView extends StatefulWidget {
  const _MersalRequestView();

  @override
  State<_MersalRequestView> createState() => _MersalRequestViewState();
}

class _MersalRequestViewState extends State<_MersalRequestView> {
  GoogleMapController? _mapController;
  bool _isFirstLoad = true;
  bool _isMapMoving = false;
  bool _isMapReady = false;

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();

  // Modern Theme Colors
  static const Color _primaryTeal = Color(0xFF00BFA5);
  static const Color _primaryDark = Color(0xFF004D40);
  static const Color _accentBlue = Color(0xFF0284C7);
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _borderLight = Color(0xFFE2E8F0);

  int _activeStep = 0; // 0: Location, 1: Items & Voice, 2: Review & Submit

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GoogleMapsInitializer.ensureInitialized();
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _descController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgLight,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // 1. Interactive Full Map Layer
            _buildMapLayer(),

            // 2. Center Location Pin Indicator (Only on step 0)
            if (_activeStep == 0) _buildCenterPin(),

            // 3. Top Floating App Bar
            _buildTopBar(),

            // 4. Bottom Sliding Order Wizard Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomWizardSheet(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 1. طبقة الخريطة التفاعلية مع تحديد GPS
  // ═══════════════════════════════════════════
  Widget _buildMapLayer() {
    if (!_isMapReady) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _primaryTeal,
          ),
        ),
      );
    }
    return Consumer<MersalController>(
      builder: (context, controller, _) {
        final location = controller.state.dropoffLocation;
        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: location ?? const LatLng(33.3152, 44.3661),
            zoom: location != null ? 16.5 : 7.0,
          ),
          onMapCreated: (mapCtrl) {
            _mapController = mapCtrl;
            if (_isFirstLoad) {
              controller.determinePosition(context).then((_) {
                if (controller.state.dropoffLocation != null) {
                  mapCtrl.animateCamera(
                    CameraUpdate.newLatLngZoom(controller.state.dropoffLocation!, 16.5),
                  );
                }
              });
              _isFirstLoad = false;
            }
          },
          onCameraMoveStarted: () => setState(() => _isMapMoving = true),
          onCameraIdle: () => setState(() => _isMapMoving = false),
          onCameraMove: (pos) {
            if (_activeStep == 0) {
              controller.updateLocationFromMap(pos.target);
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // 2. شريط علوي أنيق وزجاجي
  // ═══════════════════════════════════════════
  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // زر الرجوع
            _glassCircleButton(
              icon: Icons.arrow_forward_ios_rounded,
              onTap: () {
                if (_activeStep > 0) {
                  setState(() => _activeStep--);
                } else {
                  Navigator.pop(context);
                }
              },
            ),

            // شارة طلب مرسال
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _primaryTeal.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delivery_dining_rounded, color: _primaryTeal, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'طلب مِـرسال وشراء',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _textMain,
                    ),
                  ),
                ],
              ),
            ),

            // زر تحديد موقعي الحالي GPS
            _glassCircleButton(
              icon: Icons.my_location_rounded,
              onTap: () {
                final ctrl = Provider.of<MersalController>(context, listen: false);
                ctrl.determinePosition(context).then((_) {
                  if (ctrl.state.dropoffLocation != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(ctrl.state.dropoffLocation!, 16.5),
                    );
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 3. مؤشر موقع التوصيل في منتصف الخريطة
  // ═══════════════════════════════════════════
  Widget _buildCenterPin() {
    final double bottomOffset = _isMapMoving ? 190 : 210;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomOffset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _isMapMoving ? 0.0 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primaryTeal, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, color: _primaryTeal, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      'مكان تسليم الغراض',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.location_on_rounded, size: 54, color: _primaryDark),
                const Icon(Icons.location_on_rounded, size: 48, color: _primaryTeal),
                Positioned(
                  top: 13,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 4. لوحة الخطوات المرتبة (Wizard Bottom Sheet)
  // ═══════════════════════════════════════════
  Widget _buildBottomWizardSheet() {
    return Consumer<MersalController>(
      builder: (context, controller, _) {
        final isSubmitting = controller.state.status == MersalViewStatus.requesting;

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * (_activeStep == 0 ? 0.45 : 0.62),
          ),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مقبض السحب
              Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: _borderLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // شريط تقدم الخطوات بالعراقي
              _buildStepProgressHeader(),

              // محتوى الخطوة الحالي
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_activeStep == 0) _buildStep0Location(controller),
                      if (_activeStep == 1) _buildStep1Items(controller),
                      if (_activeStep == 2) _buildStep2Review(controller),

                      const SizedBox(height: 16),

                      // أزرار التنقل بين الخطوات
                      _buildWizardActionButtons(controller, isSubmitting),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // شريط مؤشر الخطوات الثلاث
  // ═══════════════════════════════════════════
  Widget _buildStepProgressHeader() {
    final stepTitles = ['١. موقع التسليم', '٢. قائمة الغراض', '٣. مراجعة وتأكيد'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        children: List.generate(3, (idx) {
          final isDone = idx < _activeStep;
          final isCurrent = idx == _activeStep;
          final isLast = idx == 2;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? _primaryTeal.withValues(alpha: 0.12)
                          : isDone
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? _primaryTeal
                            : isDone
                                ? const Color(0xFF86EFAC)
                                : _borderLight,
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        stepTitles[idx],
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: (isCurrent || isDone) ? FontWeight.w900 : FontWeight.w600,
                          color: isCurrent
                              ? _primaryDark
                              : isDone
                                  ? const Color(0xFF15803D)
                                  : _textSub,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 10, color: _textSub.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // الخطوة 1: تحديد موقع التسليم
  // ═══════════════════════════════════════════
  Widget _buildStep0Location(MersalController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'وين تحب نوصلك الغراض؟',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w900,
            fontSize: 15.5,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'حرك الخريطة فوك لتثبيت مكان بيتك أو موقع استلام الطلب بدقة',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _textSub),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded, color: _primaryTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموقع المختار على الخريطة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: _textMain,
                      ),
                    ),
                    Text(
                      controller.state.dropoffAddress.isNotEmpty
                          ? controller.state.dropoffAddress
                          : 'موقعك المباشر في القائم',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // الخطوة 2: كتابة الغراض والبصمة الصوتية
  // ═══════════════════════════════════════════
  Widget _buildStep1Items(MersalController controller) {
    final hasVoice = controller.state.hasVoiceNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شنو محتاج نجيبلك أو نوصلك؟',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w900,
            fontSize: 15.5,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'اكتب الغراض بالتفصيل أو سجل بصمة صوتية للكابتن',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _textSub),
        ),
        const SizedBox(height: 10),

        // حقل كتابة الغراض
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderLight, width: 1.2),
          ),
          child: TextField(
            controller: _descController,
            maxLines: 3,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              color: _textMain,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (val) => controller.updateDescription(val),
            decoration: InputDecoration(
              hintText: 'اكتب كل الغراض بالتفصيل..\n(مثال: 10 صمون حار، مسواك خضرة، كباب، علاج من الصيدلية...)',
              hintStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                color: const Color(0xFF94A3B8),
                height: 1.4,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // زر البصمة الصوتية
        if (!hasVoice)
          InkWell(
            onTap: () => _showRecordingBottomSheet(context, controller),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _accentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentBlue.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: _accentBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أو سجل بصمة صوتية للكابتن',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _accentBlue,
                          ),
                        ),
                        Text(
                          'اشرح بصوتك شنو تحب يجيبلك بالتفصيل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: _textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _accentBlue),
                ],
              ),
            ),
          )
        else
          _buildVoiceNoteCard(controller),

        const SizedBox(height: 12),

        // حقل اسم المحل (اختياري)
        Text(
          'اسم المحل أو المنطقة (اختياري)',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderLight, width: 1.2),
          ),
          child: TextField(
            controller: _storeController,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              color: _textMain,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (val) => controller.updateStoreName(val),
            decoration: InputDecoration(
              hintText: 'مثال: أسواق البركة، صيدلية السلام، مطعم القائم...',
              hintStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(Icons.storefront_rounded, color: _primaryTeal, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // الخطوة 3: مراجعة وتأكيد الطلب
  // ═══════════════════════════════════════════
  Widget _buildStep2Review(MersalController controller) {
    final desc = _descController.text.trim();
    final store = _storeController.text.trim();
    final hasVoice = controller.state.hasVoiceNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مراجعة وتأكيد الطلب',
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w900,
            fontSize: 15.5,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'تأكد من تفاصيل طلبك قبل إرساله للكباتن القريبين',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _textSub),
        ),
        const SizedBox(height: 12),

        // بطاقة ملخص الغراض
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_list_bulleted_rounded, color: _primaryTeal, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'قائمة الغراض:',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                desc.isNotEmpty ? desc : (hasVoice ? 'موصوفة عبر البصمة الصوتية' : 'لم يتم تحديد نص'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: _textMain,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (store.isNotEmpty) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 16, color: _textSub),
                    const SizedBox(width: 6),
                    Text(
                      'المحل / المكان: $store',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _textSub),
                    ),
                  ],
                ),
              ],
              if (hasVoice) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.mic_rounded, size: 16, color: _accentBlue),
                    const SizedBox(width: 6),
                    Text(
                      'مرفق بصمة صوتية للكابتن',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _accentBlue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // بطاقة الدفع والتسعير
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.payments_rounded, color: Color(0xFF15803D), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'الدفع كاش عند الاستلام • السعر يتفق عليه الكابتن وياك',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // أزرار التنقل بين الخطوات
  // ═══════════════════════════════════════════
  Widget _buildWizardActionButtons(MersalController controller, bool isSubmitting) {
    if (_activeStep == 0) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _activeStep = 1);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'التالي: اكتب الغراض',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeStep == 1) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: () => setState(() => _activeStep = 0),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: _borderLight),
              ),
              child: Text(
                'السابق',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: _textSub),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                final desc = _descController.text.trim();
                if (desc.isEmpty && !controller.state.hasVoiceNote) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'يرجى كتابة الغراض أو تسجيل بصمة صوتية أولاً',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: const Color(0xFFE53935),
                    ),
                  );
                  return;
                }
                HapticFeedback.lightImpact();
                setState(() => _activeStep = 2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: Text(
                'التالي: مراجعة وتأكيد',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 14.5, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      );
    }

    // Step 2: Final Submit
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton(
            onPressed: isSubmitting ? null : () => setState(() => _activeStep = 1),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: _borderLight),
            ),
            child: Text(
              'تعديل',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: _textSub),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    HapticFeedback.heavyImpact();
                    final reqId = await controller.submitRequest();
                    if (reqId != null && mounted) {
                      _showSuccessAndRedirect(context, reqId);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              shadowColor: _primaryTeal.withValues(alpha: 0.4),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'دز الطلب للكباتن',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showSuccessAndRedirect(BuildContext context, String reqId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _primaryTeal.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_primaryTeal, _primaryDark]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                'عاشت إيدك! تم إرسال طلبك',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'طلبك هسة معروض على كباتن مرسال القريبين منك، تكدر تتابع الطلب وحركة الكابتن على الخريطة فوراً!',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: _textSub, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close bottomsheet
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerMersalTrackingPage(requestId: reqId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'تتبع الطلب وحركة الكابتن',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 5. بطاقة البصمة الصوتية المسجلة
  // ═══════════════════════════════════════════
  Widget _buildVoiceNoteCard(MersalController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: _primaryTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم تسجيل البصمة الصوتية بنجاح',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _primaryDark,
                  ),
                ),
                Text(
                  'جاهزة للإرسال مع الطلب',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: _textSub),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => controller.deleteVoiceNote(),
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935), size: 22),
            tooltip: 'حذف البصمة',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 6. نافذة تسجيل البصمة الصوتية التفاعلية
  // ═══════════════════════════════════════════
  void _showRecordingBottomSheet(BuildContext context, MersalController controller) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final duration = controller.state.recordingDuration;
            final isRecording = controller.state.isRecording;

            if (!isRecording && controller.state.recordingDuration == 0) {
              Future.delayed(Duration.zero, () => controller.startRecording());
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'جاي نسجل بصمتك الصوتية',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: _textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اشرح للكابتن شنو يجيبلك بالضبط (معاك دقيقة كاملة)',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _textSub),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_rounded, color: Color(0xFFE53935), size: 38),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '00:${duration.toString().padLeft(2, '0')}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _textMain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              controller.cancelRecording();
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFE53935)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              'إلغاء',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFFE53935),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              controller.stopRecording();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text(
                              'حفظ البصمة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // 8. أزرار دائرية زجاجية أنيقة
  // ═══════════════════════════════════════════
  Widget _glassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 44,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _cardBg,
        border: Border.all(color: _borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Icon(icon, color: _textMain, size: size * 0.45),
        ),
      ),
    );
  }
}
