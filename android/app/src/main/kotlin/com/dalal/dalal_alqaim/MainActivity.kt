package com.dalal.dalal_alqaim

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)

		// 🛡️ تسجيل القنوات الرسمية المعيارية لنظام أندرويد لضمان استلام الإشعارات في الخلفية وحالة إغلاق التطبيق
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			val notificationManager: NotificationManager =
				getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

			// 1. القناة العاجلة لرحلات التكسي والتنبيهات ذات الأولوية القصوى
			val urgentAlertsChannel = NotificationChannel(
				"madar_urgent_alerts_v1",
				"طلبات مدار العاجلة",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "إشعارات الطلبات والرحلات الجديدة العاجلة"
				enableVibration(true)
				vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
			}

			// 2. قناة طلبات التوصيل، مرسال، الطرود، والمطاعم
			val deliveryChannel = NotificationChannel(
				"madar_delivery_urgent_v2",
				"طلبات التوصيل والمرسال العاجلة",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "إشعارات طلبات مرسال، الطرود، والمطاعم بصوت مرتفع"
				enableVibration(true)
			}

			// 3. القناة العامة للتحديثات التشغيلية والرسائل
			val generalChannel = NotificationChannel(
				"madar_general_v1",
				"إشعارات مدار العامة",
				NotificationManager.IMPORTANCE_DEFAULT
			).apply {
				description = "تحديثات النظام، الإعلانات، ومحادثات الدعم الفني"
			}

			// 4. قناة تنبيهات الأمان والتحقق
			val securityChannel = NotificationChannel(
				"madar_security_v1",
				"تنبيهات الأمان والحساب",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "تنبيهات أمان الحساب والعمليات الحساسة"
				enableVibration(true)
			}

			// 5. قناة طوارئ واستغاثة SOS القصوى
			val sosChannel = NotificationChannel(
				"madar_sos_v1",
				"نداءات الطوارئ والاستغاثة (SOS)",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "نداءات الاستغاثة وحالات الطوارئ الميدانية العاجلة"
				enableVibration(true)
				vibrationPattern = longArrayOf(0, 1500, 500, 1500, 500, 1500)
			}

			notificationManager.createNotificationChannel(urgentAlertsChannel)
			notificationManager.createNotificationChannel(deliveryChannel)
			notificationManager.createNotificationChannel(generalChannel)
			notificationManager.createNotificationChannel(securityChannel)
			notificationManager.createNotificationChannel(sosChannel)
		}
	}
}

