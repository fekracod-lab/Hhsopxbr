package com.example.dalal_alqaim

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import android.content.Context

class MainActivity: FlutterActivity() {
	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		super.onCreate(savedInstanceState)
		createRideRequestsChannel()
	}

	private fun createRideRequestsChannel() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			val channelId = "ride_requests_channel"
			val channelName = "طلبات الرحلات"
			val channelDescription = "إشعارات طلبات الرحلات للسائقين"
			val importance = NotificationManager.IMPORTANCE_HIGH
			val channel = NotificationChannel(channelId, channelName, importance)
			channel.description = channelDescription
			channel.enableLights(true)
			channel.enableVibration(true)
			val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
			notificationManager.createNotificationChannel(channel)
		}
	}
}
