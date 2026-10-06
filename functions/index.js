const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// ─── القنوات الرسمية المعيارية المعتمدة لنظام أندرويد (Canonical Android Channels) ───
const CANONICAL_CHANNELS = {
  URGENT_ALERTS: "madar_urgent_alerts_v1",     // رحلات التكسي، التنبيهات العاجلة
  DELIVERY_URGENT: "madar_delivery_urgent_v2", // طلبات التوصيل، مرسال، الطرود، المطاعم
  GENERAL: "madar_general_v1",                 // تحديثات عامة، محادثات الدعم
  SECURITY: "madar_security_v1",               // تنبيهات الأمان، كشف الاحتيال
  SOS: "madar_sos_v1",                         // نداءات الاستغاثة والطوارئ القصوى
};

/// 🛡️ التأكد من مطابقة معرف القناة للقنوات المعتمدة مع تحويل القنوات القديمة تلقائياً
function resolveCanonicalChannel(channelId, fallback = CANONICAL_CHANNELS.URGENT_ALERTS) {
  if (!channelId) return fallback;
  if (channelId === "madar_taxi_orders" || channelId === "ride_requests_channel") {
    return CANONICAL_CHANNELS.URGENT_ALERTS;
  }
  if (channelId === "delivery_sound_channel") {
    return CANONICAL_CHANNELS.DELIVERY_URGENT;
  }
  const valid = Object.values(CANONICAL_CHANNELS);
  if (valid.includes(channelId)) return channelId;
  return fallback;
}

/// 🧹 تعقيم وتطبيع بيانات FCM لتكون جميع القيم سلاسل نصية بحتة (Strict Strings Enforcement)
function sanitizeFcmData(rawData) {
  if (!rawData || typeof rawData !== "object") return {};
  const sanitized = {};
  for (const [k, v] of Object.entries(rawData)) {
    if (v === null || v === undefined) continue;
    if (typeof v === "object") {
      try {
        sanitized[k] = JSON.stringify(v);
      } catch (_) {
        sanitized[k] = String(v);
      }
    } else {
      sanitized[k] = String(v);
    }
  }
  return sanitized;
}

// ─── OneSignal Standby (معطل للإرسال الموازي لمنع الازدواجية) ───
async function sendOneSignal(playerIds, headingAr, contentAr, data) {
  // تم تحييد OneSignal عن إرسال الإشعارات الموازية ليصبح FCM هو المسار الحصري المعتمد
  console.log(`[OneSignal Standby] Skipped parallel push for ${playerIds?.length || 0} devices (FCM is authoritative).`);
  return;
}

// ─── حفظ سجل الإشعار في Firestore للمستخدم ───
async function saveNotificationHistory(userId, title, body, type, data) {
  if (!userId || !title) return;
  try {
    await admin.firestore().collection("notifications").add({
      userId: String(userId),
      title: title,
      body: body,
      type: type || "system",
      data: data || {},
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`[Firestore History] Saved in-app notification for user: ${userId}`);
  } catch (err) {
    console.error(`[Firestore History] Error saving notification for user ${userId}:`, err);
  }
}

/// 🔍 جلب جميع توكنات أجهزة المستخدم مع دعم الأجهزة المتعددة والتوافق العكسي
async function resolveDeviceTokensForUser(userId) {
  if (!userId) return [];
  const uidStr = String(userId);
  const tokens = new Set();
  try {
    // 1. سجل الأجهزة المتعددة (Multi-Device Registry)
    const devSnap = await admin.firestore()
      .collection("users")
      .doc(uidStr)
      .collection("notification_devices")
      .where("enabled", "==", true)
      .get();
    devSnap.forEach((doc) => {
      const t = doc.data()?.fcmToken;
      if (t && typeof t === "string" && t.length > 10) tokens.add(t);
    });

    // 2. التوافق العكسي: قراءة الحقل القديم users/{uid}.fcmToken
    const userDoc = await admin.firestore().collection("users").doc(uidStr).get();
    const uToken = userDoc.data()?.fcmToken;
    if (uToken && typeof uToken === "string" && uToken.length > 10) tokens.add(uToken);

    // 3. التوافق العكسي: قراءة drivers/{uid}.fcmToken
    const driverDoc = await admin.firestore().collection("drivers").doc(uidStr).get();
    const dToken = driverDoc.data()?.fcmToken;
    if (dToken && typeof dToken === "string" && dToken.length > 10) tokens.add(dToken);
  } catch (err) {
    console.error(`Error resolving device tokens for user ${uidStr}:`, err);
  }
  return Array.from(tokens);
}

/// 🧹 تنظيف وتعطيل التوكنات التالفة أو غير المسجلة (Token Pruner)
async function pruneInvalidToken(token) {
  if (!token || typeof token !== "string") return;
  try {
    const batch = admin.firestore().batch();
    let count = 0;

    // تعطيل التوكن في سجل الأجهزة
    const devSnap = await admin.firestore()
      .collectionGroup("notification_devices")
      .where("fcmToken", "==", token)
      .get();
    devSnap.forEach((doc) => {
      batch.update(doc.ref, {
        enabled: false,
        disabledAt: admin.firestore.FieldValue.serverTimestamp(),
        disabledReason: "token_unregistered",
      });
      count++;
    });

    // إزالة التوكن القديم من users
    const userSnap = await admin.firestore().collection("users").where("fcmToken", "==", token).get();
    userSnap.forEach((doc) => {
      batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
      count++;
    });

    // إزالة التوكن القديم من drivers
    const driverSnap = await admin.firestore().collection("drivers").where("fcmToken", "==", token).get();
    driverSnap.forEach((doc) => {
      batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
      count++;
    });

    if (count > 0) {
      await batch.commit();
      console.log(`[Token Pruner] Pruned ${count} records for invalid token prefix: ${token.slice(0, 8)}...`);
    }
  } catch (err) {
    console.error(`[Token Pruner] Failed to prune token:`, err);
  }
}

/// 🔍 B1: تصنيف أخطاء FCM إلى مؤقتة (قابلة لإعادة المحاولة) أو نهائية
function isTransientFcmError(errorCode, errorMessage) {
  if (!errorCode && !errorMessage) return false;
  const code = String(errorCode || "").toLowerCase();
  const msg = String(errorMessage || "").toLowerCase();

  // أخطاء FCM المؤقتة المعروفة
  if (
    code === "messaging/server-unavailable" ||
    code === "messaging/internal-error" ||
    code === "messaging/quota-exceeded" ||
    code === "messaging/too-many-requests" ||
    code === "messaging/device-message-rate-exceeded"
  ) {
    return true;
  }

  // أخطاء انقطاع الاتصال المؤقت للشبكة
  if (
    code.includes("econnreset") ||
    code.includes("etimedout") ||
    code.includes("econnrefused") ||
    code.includes("esockettimedout") ||
    msg.includes("econnreset") ||
    msg.includes("etimedout") ||
    msg.includes("timeout") ||
    msg.includes("socket hang up") ||
    msg.includes("network error")
  ) {
    return true;
  }

  return false;
}

/// ⏱️ B3: حساب وقت المحاولة التالية باستخدام Exponential Backoff مع Jitter لمنع الـ Retry Storms
function calculateNextRetryTimestamp(retryCount) {
  const count = Math.max(1, retryCount || 1);
  // Attempt 1: 10s + jitter (0-3s)
  // Attempt 2: 20s + jitter (0-6s)
  // Attempt 3: 40s + jitter (0-12s)
  const baseBackoff = 10 * Math.pow(2, count - 1);
  const jitter = Math.floor(Math.random() * (count * 3 + 1));
  const totalSeconds = baseBackoff + jitter;
  const nextDate = new Date(Date.now() + totalSeconds * 1000);
  return admin.firestore.Timestamp.fromDate(nextDate);
}

// ─── 🚀 المرسل الحصري المعتمد لإشعارات FCM (Authoritative FCM Sender with Per-Token Tracking) ───
async function sendAuthoritativeFCM(tokens, titleAr, bodyAr, data = {}, options = {}) {
  const valid = [...new Set((tokens || []).filter((t) => t && typeof t === "string" && t.length > 10))];
  if (valid.length === 0) {
    return {
      successCount: 0,
      failureCount: 0,
      prunedCount: 0,
      successfulTokens: [],
      retryableTokens: [],
      terminalTokens: [],
      hasTransientFailure: false,
    };
  }

  const channelId = resolveCanonicalChannel(options.channelId || data.channelId);
  const priority = options.priority || "high";
  const sanitizedData = sanitizeFcmData({
    ...data,
    channelId: channelId,
  });

  const message = {
    tokens: valid,
    notification: { title: titleAr || "تنبيه مدار", body: bodyAr || "" },
    data: sanitizedData,
    android: {
      priority: "high",
      notification: {
        channelId: channelId,
        sound: "default",
        priority: priority === "critical" ? "max" : "high",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "content-available": 1,
        },
      },
    },
  };

  try {
    const res = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Authoritative FCM] Multicast on ${channelId}: ${res.successCount} OK, ${res.failureCount} Fail`);

    const successfulTokens = [];
    const retryableTokens = [];
    const terminalTokens = [];
    let prunedCount = 0;

    if (res.failureCount > 0) {
      const prunePromises = [];
      res.responses.forEach((resp, idx) => {
        const token = valid[idx];
        if (resp.success) {
          successfulTokens.push(token);
        } else {
          const errCode = resp.error?.code;
          const errMsg = resp.error?.message;
          console.warn(`[Authoritative FCM] Token error ${errCode} for token ${token.slice(0, 8)}...`);

          if (isTransientFcmError(errCode, errMsg)) {
            retryableTokens.push(token);
          } else {
            terminalTokens.push(token);
            if (
              errCode === "messaging/registration-token-not-registered" ||
              errCode === "messaging/invalid-registration-token"
            ) {
              prunePromises.push(pruneInvalidToken(token));
              prunedCount++;
            }
          }
        }
      });

      if (prunePromises.length > 0) {
        await Promise.all(prunePromises);
      }
    } else {
      successfulTokens.push(...valid);
    }

    return {
      successCount: res.successCount,
      failureCount: res.failureCount,
      prunedCount: prunedCount,
      successfulTokens: successfulTokens,
      retryableTokens: retryableTokens,
      terminalTokens: terminalTokens,
      hasTransientFailure: retryableTokens.length > 0,
    };
  } catch (err) {
    console.error("[Authoritative FCM] Multicast delivery fatal network/provider error:", err);
    const isTransient = isTransientFcmError(err.code, err.message);
    return {
      successCount: 0,
      failureCount: valid.length,
      prunedCount: 0,
      successfulTokens: [],
      retryableTokens: isTransient ? valid : [],
      terminalTokens: isTransient ? [] : valid,
      hasTransientFailure: isTransient,
      error: err.message,
    };
  }
}

// دالة التوافق القديمة sendFCM تستدعي الآن sendAuthoritativeFCM
async function sendFCM(tokens, titleAr, bodyAr, data) {
  return await sendAuthoritativeFCM(tokens, titleAr, bodyAr, data);
}

// ─── إرسال ذكي وموحد لمستخدم فردي مع التوافق وسجل الإشعارات ───
async function sendSmartPushToUser(userDocOrData, title, body, data, notifType) {
  if (!userDocOrData) return;
  const uid = userDocOrData.uid || userDocOrData.userId || userDocOrData.id;

  if (uid) {
    await saveNotificationHistory(uid, title, body, notifType, data);
  }

  const tokens = await resolveDeviceTokensForUser(uid);
  if (tokens.length > 0) {
    await sendAuthoritativeFCM(tokens, title, body, data);
  } else {
    console.warn(`[sendSmartPushToUser] No valid device tokens found for user: ${uid}`);
  }
}

// ═══════════════════════════════════════════
//  1️⃣ إشعار السائقين عند طلب رحلة جديد
// ═══════════════════════════════════════════
exports.notifyDriversOnNewRide = functions.firestore
  .document("ride_requests/{rideId}")
  .onCreate(async (snap, context) => {
    try {
      const ride = snap.data() || {};
      const customerName = ride.userName || "زبون مدار";
      const address = ride.address || ride.pickupAddress || "بدون عنوان محدد";
      const rideType = ride.rideType || "توصيل تكسي";
      const price = ride.price ? `${ride.price} د.ع` : "";

      const title = "🚖 طلب مشوار جديد واصلك!";
      const body = `${rideType} • من ${customerName}\n📍 الانطلاق: ${address}${price ? "\n💰 الأجرة: " + price : ""}\nاضغط واقبل المشوار على السريع! ⚡`;

      const driversSnap = await admin.firestore().collection("drivers").where("availability", "==", "online").get();

      const osIds = [];
      const fcmTokens = [];
      driversSnap.forEach((doc) => {
        const d = doc.data();
        if (d?.fcmToken) fcmTokens.push(d.fcmToken);
        else if (d?.oneSignalId) osIds.push(d.oneSignalId);
      });

      const notifData = { type: "new_ride", rideId: context.params.rideId, pickupAddress: address, customerName };
      console.log(`Found ${driversSnap.size} online drivers (FCM: ${fcmTokens.length}, OS: ${osIds.length})`);

      if (fcmTokens.length > 0) {
        await sendFCM(fcmTokens, title, body, notifData);
      } else if (osIds.length > 0) {
        await sendOneSignal(osIds, title, body, notifData);
      }
      return null;
    } catch (err) {
      console.error("notifyDriversOnNewRide:", err);
      return null;
    }
  });

// ═══════════════════════════════════════════
//  2️⃣ إشعار الزبون عند تغيّر حالة الرحلة
// ═══════════════════════════════════════════
exports.notifyCustomerOnRideStatusChange = functions.firestore
  .document("ride_requests/{rideId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status === after.status) return null;

      const customerUid = after.userId || after.uid;
      if (!customerUid) return null;

      const msgs = {
        accepted: { title: "✅ هلا بيك! الكابتن قبل طلبك", body: "الكابتن صار بطريقه إلك هسة، جهز روحك 🚗" },
        arrived: { title: "📍 الكابتن وصل يمك!", body: "الكابتن واكف بموقع الاستلام وينتظرك، لا تتأخر عليه ✨" },
        in_progress: { title: "🚗 توكلنا على الله، بدت الرحلة!", body: "رحلتك ويا الكابتن بدت، توصل بالسلامة يارب" },
        completed: { title: "🏁 الحمد لله على السلامة، نورتنا!", body: "وصلت بالسلامة، شكراً لاختيارك مدار، قيّم الكابتن وانطينا رايك ⭐" },
        cancelled: { title: "❌ انلغى المشوار", body: after.cancelReason || "نعتذر منك، تم إلغاء طلب المشوار" },
      };

      const msg = msgs[after.status];
      if (!msg) return null;

      const userDoc = await admin.firestore().collection("users").doc(customerUid).get();
      const u = userDoc.data() || {};
      u.uid = customerUid;
      const data = { type: "ride_status", rideId: context.params.rideId, status: after.status };

      await sendSmartPushToUser(u, msg.title, msg.body, data, "taxi");
      console.log(`Notified customer ${customerUid}: ${after.status}`);
      return null;
    } catch (err) {
      console.error("notifyCustomerOnRideStatusChange:", err);
      return null;
    }
  });

// ═══════════════════════════════════════════
//  3️⃣ إشعار السائق عند إلغاء الزبون
// ═══════════════════════════════════════════
exports.notifyDriverOnRideCancellation = functions.firestore
  .document("ride_requests/{rideId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status === after.status || after.status !== "cancelled") return null;

      const driverId = after.driverId || after.assignedDriver;
      if (!driverId) return null;

      const driverDoc = await admin.firestore().collection("drivers").doc(driverId).get();
      const d = driverDoc.data() || {};
      d.uid = driverId;

      const title = "❌ الزبون لغى المشوار";
      const body = `${after.userName || "الزبون"} لغى طلب الرحلة، خيرها بغيرها كابتن!`;
      const data = { type: "ride_cancelled", rideId: context.params.rideId };

      await sendSmartPushToUser(d, title, body, data, "taxi");
      return null;
    } catch (err) {
      console.error("notifyDriverOnRideCancellation:", err);
      return null;
    }
  });

// ═══════════════════════════════════════════
//  4️⃣ إشعار المطعم عند طلب جديد
// ═══════════════════════════════════════════
exports.notifyRestaurantOnNewOrder = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {
    try {
      const order = snap.data() || {};
      const restaurantId = order.restaurantDocId || order.restaurantId || order.restaurantOwnerId;
      if (!restaurantId) return null;

      const customerName = order.customerName || "زبون مدار";
      const itemCount = (order.items || []).length;
      const total = order.grandTotal || order.total || 0;

      const title = "🍔 طلبية جديدة وصلت للمطبخ!";
      const body = `الزبون ${customerName} طلب (${itemCount}) أصناف\n💰 الحساب: ${total} د.ع\nادخل أكد الطلب وبلش بالشوي والتجهيز! 👨‍🍳🔥`;

      const restaurantDoc = await admin.firestore().collection("users").doc(restaurantId).get();
      const r = restaurantDoc.data() || {};
      r.uid = restaurantId;

      const notifData = {
        type: "restaurant_order",
        orderId: context.params.orderId,
        restaurantId: restaurantId,
      };

      await sendSmartPushToUser(r, title, body, notifData, "restaurant");
      console.log(`Notified restaurant ${restaurantId} about new order`);
      return null;
    } catch (err) {
      console.error("notifyRestaurantOnNewOrder:", err);
      return null;
    }
  });

// ═══════════════════════════════════════════
//  5️⃣ إشعار الزبون والكباتن عند تغيّر حالة الطلب
// ═══════════════════════════════════════════
exports.notifyCustomerOnOrderStatusChange = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status === after.status) return null;

      const customerUid = after.userId || after.customerId;
      const orderId = context.params.orderId;
      const restaurantName = after.restaurantName || "المطعم";

      // ── إشعار الزبون باللهجة العراقية ──
      const msgs = {
        accepted: { title: "✅ المطعم استلم طلبيتك!", body: `مطعم "${restaurantName}" قبل الطلب وبلش يجهز بالأكل الطيب 😋` },
        preparing: { title: "👨‍🍳 جاري التحضير والشوي!", body: "الشيف ديحضر ويشوي بطلبيتك هسة حتى تجيك حارة ونار 🔥" },
        ready: { title: "🎉 أكلك جهز وطازة!", body: "الأكل صار جاهز وبانتظار كابتن التوصيل يركب الدراجة ويوصله إلك 🛵" },
        delivered: { title: "📦 بألف عافية وصحة وهنا!", body: "استلمت أكلك بسلامة، صحة وهنا على كلبك، قيّم المطعم والكابتن ⭐" },
        rejected: { title: "❌ نعتذر منك، المطعم اعتذر عن الطلب", body: after.rejectReason || "عذراً منك، المطعم معتذر عن استقبال الطلب حالياً" },
        cancelled: { title: "❌ تم إلغاء الطلبية", body: after.cancelReason || "تم إلغاء الطلبية" },
      };

      if (customerUid && msgs[after.status]) {
        const msg = msgs[after.status];
        const userDoc = await admin.firestore().collection("users").doc(customerUid).get();
        const u = userDoc.data() || {};
        u.uid = customerUid;
        const data = {
          type: "order_status",
          orderId: orderId,
          status: after.status,
        };
        await sendSmartPushToUser(u, msg.title, msg.body, data, "restaurant");
        console.log(`Notified customer ${customerUid}: order ${after.status}`);
      }

      // ── بث عاجل لمناديب التوصيل فور جهوزية الأكل (ready) ──
      if (after.status === "ready") {
        const { fcmTokens, osIds } = await getDeliveryCaptainsPushTargets();
        const driverTitle = "🛵 طلبية أكل حارة جهزت وبانتظار التوصيل!";
        const driverBody = `مطعم "${restaurantName}" جهز الوجبة وهسة حارة وطازة.. ادخل استلم الطلبية حتى توصلها للزبون ⚡`;
        const driverData = {
          type: "food_order_ready",
          orderId: orderId,
          restaurantId: after.restaurantDocId || after.restaurantId || "",
          restaurantName: restaurantName,
        };

        if (fcmTokens.length > 0) {
          await sendFCM(fcmTokens, driverTitle, driverBody, driverData);
        }
        if (osIds.length > 0) {
          await sendOneSignal(osIds, driverTitle, driverBody, driverData);
        }
        console.log(`Broadcasted ready food order ${orderId} to delivery drivers (FCM: ${fcmTokens.length}, OS: ${osIds.length})`);
      }

      return null;
    } catch (err) {
      console.error("notifyCustomerOnOrderStatusChange:", err);
      return null;
    }
  });

// ─── جلب كل كباتن ومندوبي التوصيل الفعالين في النظام ───
async function getDeliveryCaptainsPushTargets() {
  const fcmTokens = new Set();
  const osIds = new Set();

  try {
    // 1. جلب من جدول users لأصحاب أدوار التوصيل
    const usersSnap = await admin.firestore().collection("users")
      .where("role", "in", ["delivery_boy", "delivery_captain", "delivery", "delegate", "driver"])
      .get();
    usersSnap.forEach((doc) => {
      const d = doc.data();
      if (d?.fcmToken) fcmTokens.add(d.fcmToken);
      if (d?.oneSignalId) osIds.add(d.oneSignalId);
    });

    // 2. جلب من جدول drivers
    const driversSnap = await admin.firestore().collection("drivers").get();
    driversSnap.forEach((doc) => {
      const d = doc.data();
      if (d?.availability !== "offline") {
        if (d?.fcmToken) fcmTokens.add(d.fcmToken);
        if (d?.oneSignalId) osIds.add(d.oneSignalId);
      }
    });

    // 3. جلب من جدول delivery_captains
    const delCapSnap = await admin.firestore().collection("delivery_captains").get();
    delCapSnap.forEach((doc) => {
      const d = doc.data();
      if (d?.fcmToken) fcmTokens.add(d.fcmToken);
      if (d?.oneSignalId) osIds.add(d.oneSignalId);
    });
  } catch (err) {
    console.error("Error in getDeliveryCaptainsPushTargets:", err);
  }

  return {
    fcmTokens: Array.from(fcmTokens),
    osIds: Array.from(osIds),
  };
}

// ═══════════════════════════════════════════
//  6️⃣ إشعار السائقين عند طلب مرسال جديد (باللهجة العراقية وصوت مستمر)
// ═══════════════════════════════════════════
exports.notifyDriversOnNewMersal = functions.firestore
  .document("mersal_requests/{requestId}")
  .onCreate(async (snap, context) => {
    try {
      const req = snap.data() || {};
      const customerName = req.userName || req.customerName || "زبون مدار";
      const desc = req.storeName || req.requestDescription || req.description || "طلب شراء وتوصيل";

      const title = "📦 طلب مرسال جديد وصلك يا كابتن!";
      const body = `زبون مدار (${customerName}) طالب توصيلة مرسال من (${desc})\nسارع بفتح التطبيق وحدد سعرك واستلم الطلب! 🛵⚡`;

      const { fcmTokens, osIds } = await getDeliveryCaptainsPushTargets();

      const data = {
        type: "mersal_request",
        requestId: context.params.requestId,
        channelId: "madar_delivery_urgent_v2",
      };

      if (fcmTokens.length > 0) {
        await sendFCM(fcmTokens, title, body, data);
      }
      if (osIds.length > 0) {
        await sendOneSignal(osIds, title, body, data);
      }
      return null;
    } catch (err) { console.error("notifyDriversOnNewMersal:", err); return null; }
  });

// ═══════════════════════════════════════════
//  7️⃣ إشعار الزبون عند تغيّر حالة المرسال (باللهجة العراقية)
// ═══════════════════════════════════════════
exports.notifyMersalStatusChange = functions.firestore
  .document("mersal_requests/{requestId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status === after.status) return null;

      const uid = after.userId || after.uid;
      if (!uid) return null;

      const price = after.price ? ` بسعر ${after.price} د.ع` : "";
      const msgs = {
        accepted: { title: "🛵 الكابتن وافق على طلبك!", body: `الكابتن وافق على توصيل مرسال${price} وهو هسة متوجه لمكان الشراء 👍` },
        arrived_at_pickup: { title: "📍 الكابتن وصل لنقطة الشراء!", body: "الكابتن هسة واصل للمحل دياخذ الأمانة والغراض مالتك 🛍️" },
        picked_up: { title: "🛍️ الكابتن استلم الغراض!", body: "تم استلام الطلب وبطريقه لعنوانك هسة طاير 🛵💨" },
        on_the_way: { title: "🛵 الكابتن صار قريب عليك!", body: "الكابتن بالطريق لعنوانك، خليك جاهز للاستلام 📍" },
        delivered: { title: "🎉 وصلت طلبيتك بألف عافية!", body: "تم تسليم طلب مرسال بسلامة، صحة وهنا ولا تنسى تقييم الكابتن ⭐" },
        completed: { title: "🎉 وصلت طلبيتك بألف عافية!", body: "تم تسليم طلب مرسال بسلامة، صحة وهنا ولا تنسى تقييم الكابتن ⭐" },
        cancelled: { title: "❌ نعتذر منك، انلغى الطلب", body: after.cancelReason || "تم إلغاء طلب مرسال، نعتذر على أي إزعاج 🤍" },
      };

      const msg = msgs[after.status];
      if (!msg) return null;

      const userDoc = await admin.firestore().collection("users").doc(uid).get();
      const u = userDoc.data() || {};
      u.uid = uid;
      const data = { type: "mersal_status", requestId: context.params.requestId, status: after.status };

      await sendSmartPushToUser(u, msg.title, msg.body, data, "mersal");
      return null;
    } catch (err) { console.error("notifyMersalStatusChange:", err); return null; }
  });



// ═══════════════════════════════════════════
//  8️⃣ إشعار السائقين عند طلب مندوب جديد
// ═══════════════════════════════════════════
exports.notifyDriversOnNewDelegate = functions.firestore
  .document("delegate_requests/{requestId}")
  .onCreate(async (snap, context) => {
    try {
      const req = snap.data() || {};
      const customerName = req.userName || req.customerName || "زبون مدار";
      const desc = req.description || req.details || "مهمة مندوب وتفويض";

      const title = "🛵 طلب تفويض ومندوب جديد!";
      const body = `من الزبون: ${customerName}\n📝 تفاصيل المهمة: ${desc}\nدوس هنا واقبل المهمة كابتن ⚡`;

      const { osIds, fcmTokens } = await getDeliveryCaptainsPushTargets();

      const data = {
        type: "delegate_request",
        requestId: context.params.requestId,
        channelId: CANONICAL_CHANNELS.DELIVERY_URGENT,
        sound: "delivery_alert",
      };

      if (fcmTokens.length > 0) {
        await sendAuthoritativeFCM(fcmTokens, title, body, data, { channelId: CANONICAL_CHANNELS.DELIVERY_URGENT });
      }
      return null;
    } catch (err) { console.error("notifyDriversOnNewDelegate:", err); return null; }
  });

// ═══════════════════════════════════════════
//  9️⃣ إشعار الزبون عند تغيّر حالة المندوب
// ═══════════════════════════════════════════
exports.notifyDelegateStatusChange = functions.firestore
  .document("delegate_requests/{requestId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status === after.status) return null;

      const uid = after.userId || after.uid;
      if (!uid) return null;

      const msgs = {
        accepted: { title: "✅ المندوب قبل مهمتك!", body: "المندوب صار وياك وبلش ينفذ طلبك خطوة بخطوة 🤝" },
        arrived_at_pickup: { title: "📍 المندوب وصل لمكان المهمة!", body: "المندوب متواجد حالياً بالموقع المحدد" },
        picked_up: { title: "📦 المندوب أنجز المرحلة الأولى!", body: "المندوب جهز الغراض وبطريقه إلك" },
        on_the_way: { title: "🚗 المندوب بالطريق إلك!", body: "المندوب متوجه إلك لتسليم المهمة" },
        completed: { title: "🎉 كملت مهمة المندوب بنجاح!", body: "تم إنجاز المهمة وتسليم كل المطلوب على أتم وجه، بالعافية!" },
        cancelled: { title: "❌ تم إلغاء طلب المندوب", body: after.cancelReason || "تم إلغاء طلب المندوب" },
      };

      const msg = msgs[after.status];
      if (!msg) return null;

      const userDoc = await admin.firestore().collection("users").doc(uid).get();
      const u = userDoc.data() || {};
      u.uid = uid;
      const data = { type: "delegate_status", requestId: context.params.requestId, status: after.status };

      await sendSmartPushToUser(u, msg.title, msg.body, data, "delegate");
      return null;
    } catch (err) { console.error("notifyDelegateStatusChange:", err); return null; }
  });

// ═══════════════════════════════════════════
//  10️⃣ تغيير كلمة المرور من قبل الأدمن
// ═══════════════════════════════════════════
exports.adminChangePassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "غير مصرح لك يا غالي");
  const callerDoc = await admin.firestore().collection("users").doc(context.auth.uid).get();
  if (!callerDoc.exists || (callerDoc.data().role !== "admin" && callerDoc.data().role !== "limited_admin")) {
    throw new functions.https.HttpsError("permission-denied", "ليس لديك صلاحية الأدمن");
  }
  const targetUid = data.uid;
  const newPassword = data.newPassword;
  if (!targetUid || !newPassword || newPassword.length < 6) {
    throw new functions.https.HttpsError("invalid-argument", "المعرف غير صحيح أو كلمة المرور قصيرة");
  }
  try {
    await admin.auth().updateUser(targetUid, { password: newPassword });
    return { success: true, message: "تم تغيير كلمة المرور بنجاح" };
  } catch (error) {
    console.error("adminChangePassword error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ===============================================
//  11 - Notify store owner on new madar order
// ===============================================
exports.notifyStoreOwnerOnNewMadarOrder = functions.firestore
  .document("stores/{storeId}/madar_orders/{orderId}")
  .onCreate(async (snap, context) => {
    try {
      const order = snap.data() || {};
      const storeId = context.params.storeId;
      const orderId = context.params.orderId;
      const ownerId = order.ownerId;
      const customerName = order.customerName || "زبون مدار";
      const total = order.total || 0;
      const storeName = order.storeName || "المتجر";

      if (!ownerId) {
        console.log("notifyStoreOwnerOnNewMadarOrder: No ownerId found, skipping.");
        return null;
      }

      const title = "🛍️ طلبية جديدة للمتجر!";
      const body = `وصلك طلب جديد من الزبون ${customerName} بمبلغ ${total} د.ع\nادخل وشوف المواد المطلوبة! 🛒`;

      const notifData = {
        type: "new_store_order",
        orderId: orderId,
        storeId: storeId,
        ownerId: ownerId,
        customerName: customerName,
        total: String(total),
      };

      const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
      const ownerData = ownerDoc.data() || {};
      ownerData.uid = ownerId;

      await sendSmartPushToUser(ownerData, title, body, notifData, "store");

      // -- Notify ALL delivery captains (from users + drivers + delivery_captains) --
      const { fcmTokens: driverFcmTokens, osIds: driverOsIds } = await getDeliveryCaptainsPushTargets();

      const driverTitle = "\uD83D\uDEF5 طلبية متجر جاهزة للتوصيل!";
      const driverBody = `متجر "${storeName}" جهز الطلبية وصارت جاهزة للكابتن يستلمها هسة!`;
      const driverData = {
        type: "store_order_ready",
        orderId: orderId,
        storeId: storeId,
        storeName: storeName,
      };

      if (driverFcmTokens.length > 0) {
        await sendFCM(driverFcmTokens, driverTitle, driverBody, driverData);
      }
      if (driverOsIds.length > 0) {
        await sendOneSignal(driverOsIds, driverTitle, driverBody, driverData);
      }

      console.log("Notified store owner " + ownerId + " and " + driverFcmTokens.length + " delivery captains about new order " + orderId);
      return null;
    } catch (err) {
      console.error("notifyStoreOwnerOnNewMadarOrder:", err);
      return null;
    }
  });

// ===============================================
//  12 - Notify drivers on store order ready + customer on status change
// ===============================================
exports.notifyOnMadarOrderStatusChange = functions.firestore
  .document("stores/{storeId}/madar_orders/{orderId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status === after.status) return null;

      const storeId = context.params.storeId;
      const orderId = context.params.orderId;
      const newStatus = after.status;
      const storeName = after.storeName || "المتجر";
      const customerId = after.customerId;

      // -- Notify delivery drivers when order is accepted/ready --
      if (newStatus === "accepted" || newStatus === "ready") {
        const driverTitle = "🛵 طلبية متجر جاهزة للتوصيل!";
        const driverBody = `تم تجهيز طلب جديد في متجر "${storeName}" وهو جاهز للتوصيل للزبون الآن.`;
        const driverData = {
          type: "store_order_ready",
          orderId: orderId,
          storeId: storeId,
          storeName: storeName,
        };

        const driversSnap = await admin.firestore().collection("drivers").where("availability", "==", "online").get();
        const fcmTokens = [];
        const osIds = [];
        driversSnap.forEach((doc) => {
          const d = doc.data();
          if (d && d.fcmToken) fcmTokens.push(d.fcmToken);
          else if (d && d.oneSignalId) osIds.push(d.oneSignalId);
        });

        console.log("Found " + driversSnap.size + " online drivers for store order " + orderId);
        if (fcmTokens.length > 0) {
          await sendFCM(fcmTokens, driverTitle, driverBody, driverData);
        } else if (osIds.length > 0) {
          await sendOneSignal(osIds, driverTitle, driverBody, driverData);
        }
      }

      // -- Notify drivers to stop ringing when order is accepted or cancelled --
      if (newStatus === "delivering" || newStatus === "cancelled") {
        const stopData = {
          type: newStatus === "delivering" ? "store_order_accepted" : "store_order_cancelled",
          orderId: orderId,
          storeId: storeId,
        };
        const driversSnap = await admin.firestore().collection("drivers").where("availability", "==", "online").get();
        const fcmTokens = [];
        const osIds = [];
        driversSnap.forEach((doc) => {
          const d = doc.data();
          if (d && d.fcmToken) fcmTokens.push(d.fcmToken);
          else if (d && d.oneSignalId) osIds.push(d.oneSignalId);
        });

        const stopPromises = [];
        if (fcmTokens.length > 0) {
          stopPromises.push(sendFCM(fcmTokens, "", "", stopData));
        }
        if (osIds.length > 0) {
          stopPromises.push(sendOneSignal(osIds, "", "", stopData));
        }
        await Promise.all(stopPromises);
        console.log("Sent stop alarm notification to drivers for order " + orderId);
      }

      // -- Notify customer on order status change --
      if (customerId) {
        let msg = null;
        if (newStatus === "accepted") msg = { title: "تم قبول طلبك! 📦", body: `تم قبول طلبك من متجر "${storeName}" وجاري تجهيز المواد.` };
        else if (newStatus === "ready") msg = { title: "طلبك جاهز! ✅", body: `متجر "${storeName}" كمل تجهيز طلبك وبانتظار كابتن التوصيل.` };
        else if (newStatus === "delivering") msg = { title: "طلبك بالطريق! 🛵", body: `الكابتن استلم غراضك من متجر "${storeName}" وجاي يوصلها إلك.` };
        else if (newStatus === "delivered" || newStatus === "completed") msg = { title: "وصلت مشترياتك بألف عافية! 🎉", body: `تم توصيل مشترياتك من متجر "${storeName}" بنجاح، نتمنى تعجبك!` };
        else if (newStatus === "cancelled") msg = { title: "انلغى طلب المتجر ❌", body: `تم إلغاء طلبك من متجر "${storeName}".` };

        if (msg) {
          const userDoc = await admin.firestore().collection("users").doc(customerId).get();
          const u = userDoc.data() || {};
          u.uid = customerId;
          const custData = {
            type: "store_order_status_updated",
            orderId: orderId,
            storeId: storeId,
            status: newStatus,
          };

          await sendSmartPushToUser(u, msg.title, msg.body, custData, "store");
          console.log("Notified customer " + customerId + ": store order " + newStatus);
        }
      }

      return null;
    } catch (err) {
      console.error("notifyOnMadarOrderStatusChange:", err);
      return null;
    }
  });

// ═══════════════════════════════════════════
//  13️⃣ معالجة طلبات الإشعارات المرسلة من الكلاينت عبر Firestore
// ═══════════════════════════════════════════
exports.processNotificationRequest = functions.firestore
  .document("notification_requests/{id}")
  .onCreate(async (snap, context) => {
    try {
      const request = snap.data() || {};
      const type = request.type;
      const payload = request.payload || {};

      let title = "";
      let body = "";
      let targetUserIds = null;
      let targetRoles = null;

      switch (type) {
        case "user_notification":
          const targetUserId = payload.user_id || payload.userId;
          if (targetUserId) targetUserIds = [targetUserId.toString()];
          title = payload.title || "تحديث جديد واصلك 🔔";
          body = payload.body || "";
          break;
        case "support_message":
        case "support_request":
          targetRoles = ["support", "admin"];
          title = payload.title || "رسالة دعم فني جديدة 🛠️";
          body = payload.body || payload.message || "هناك استفسار أو طلب دعم فني من أحد المستخدمين.";
          break;
        case "taxi_broadcast":
          targetRoles = ["taxi_captain", "driver", "captain"];
          title = payload.title || "تعميم عاجل للكباتن 📢";
          body = payload.body || "يرجى الاطلاع على التعميم الإداري الجديد.";
          break;
        case "taxi_request_created":
        case "new_ride":
        case "ride_request":
        case "taxi_request":
        case "new_request":
          targetRoles = ["taxi_captain", "driver", "captain"];
          title = "🚖 طلب سفري جديد متوفر!";
          body = "هناك طلب مشوار جديد بالقرب منك، افتح التطبيق واكسب المشوار!";
          break;
        case "freight_request_created":
          targetRoles = ["delivery_captain", "transport_captain"];
          title = "🚛 طلب نقل لوري وشحن جديد!";
          body = "هناك طلب شحن وحمولة جديدة متاحة في القائم، اضغط للتفاصيل.";
          break;
        case "mersal_request_created":
        case "mersal_request":
        case "new_mersal_request":
        case "new_mersal":
          targetRoles = ["delivery_captain", "driver", "captain", "delivery_boy", "delegate", "delivery"];
          title = "📦 طلب مرسال وشراء جديد!";
          body = payload.description || payload.category ? `طلب جديد من ${payload.customerName || "الزبون"}: ${payload.description || payload.category}` : "هناك طلب مرسال وشراء جديد متاح بالقائم، افتح التطبيق وحدد السعر!";
          break;
        case "parcel_request_created":
          targetRoles = ["delivery_boy", "delivery_captain", "delivery", "delegate", "driver", "captain"];
          title = "📦 طلب توصيل طرد جديد!";
          body = "هناك طلب توصيل طرد متاح في القائم، سارع بالقبول!";
          break;
        case "delegate_request_created":
          targetRoles = ["delivery_boy", "delivery_captain", "delivery", "delegate", "driver", "captain"];
          title = "🤝 طلب تفويض ومندوب جديد!";
          body = "طلب مندوب جديد متاح بمنطقتك، اضغط للمعاينة والتنفيذ.";
          break;
        case "food_order":
          targetRoles = ["delivery_boy", "delivery_captain", "delivery", "delegate", "driver", "captain"];
          title = payload.title || "🍔 طلبية طعام جديدة للتوصيل!";
          body = payload.body || "هناك طلب طعام جديد متاح للتوصيل للزبون!";
          break;
        case "restaurant_order_created":
          const restId = payload.restaurant_id || payload.restaurantDocId;
          if (restId) targetUserIds = [restId.toString()];
          title = "🍳 طلبية جديدة للمطعم!";
          body = "وصلتك طلبية طعام معلقة تحتاج تأكيد وتحضير على السريع.";
          break;
        case "new_store_order":
          const ownerId = payload.ownerId;
          if (ownerId) targetUserIds = [ownerId.toString()];
          title = "🛍️ طلبية جديدة للمتجر!";
          body = `وصلك طلب جديد من الزبون ${payload.customerName || "زبون مدار"}`;
          break;
        case "store_order_ready":
          targetRoles = ["delivery_boy", "delivery_captain", "delivery", "delegate", "driver", "captain"];
          title = "🛍️ طلبية متجر جاهزة للتوصيل!";
          body = `تم تجهيز طلب جديد في متجر "${payload.storeName || "المتجر"}" وجاهز للنقل والتوصيل 🛵`;
          break;
        case "food_order_ready":
          targetRoles = ["delivery_boy", "delivery_captain", "delivery", "delegate", "driver", "captain"];
          title = "🍔 وجبة أكل جاهزة للاستلام!";
          body = `مطعم "${payload.restaurantName || "المطعم"}" جهز الأكل وبانتظار كابتن التوصيل ليستلمه ويوصله للزبون 🛵⚡`;
          break;
        case "ride_status_updated":
          const rideId = payload.ride_id || payload.rideId;
          if (rideId) {
            const rideSnap = await admin.firestore().collection("ride_requests").doc(rideId.toString()).get();
            const rideData = rideSnap.data() || {};
            if (rideData.userId) targetUserIds = [rideData.userId.toString()];
            const status = payload.status || "pending";
            if (status === "accepted") {
              title = "🚖 الكابتن قبل رحلتك!";
              body = "تم قبول طلب السفري وبدأ الكابتن بالتحرك باتجاهك.";
            } else if (status === "arrived") {
              title = "📍 الكابتن وصل يمك!";
              body = "الكابتن وصل لموقع الاستلام وينتظرك.";
            } else if (status === "in_progress") {
              title = "🚀 بدت الرحلة!";
              body = "توكلنا على الله، رحلتك بالطريق الآن.";
            } else if (status === "completed") {
              title = "🎉 الحمد لله على السلامة!";
              body = "تمت رحلتك بنجاح، شكراً لاختيارك مدار!";
            } else if (status === "cancelled" || status === "driver_cancelled") {
              title = "❌ انلغت الرحلة";
              body = "تم إلغاء طلب السفري الخاص بك.";
            }
          }
          break;
        case "parcel_status_updated":
          const pRequestId = payload.request_id || payload.requestId;
          if (pRequestId) {
            const pSnap = await admin.firestore().collection("parcel_delivery_requests").doc(pRequestId.toString()).get();
            const pData = pSnap.data() || {};
            if (pData.userId) targetUserIds = [pData.userId.toString()];
            const pStatus = payload.status || "pending";
            if (pStatus === "accepted") {
              title = "🚚 الكابتن قبل توصيل طردك!";
              body = "تم قبول طلب توصيل الطرد وبدأ الكابتن بالتحرك.";
            } else if (pStatus === "delivered" || pStatus === "completed") {
              title = "🎉 وصل الطرد بأمان!";
              body = "تم توصيل طردك بنجاح وبدون أي تأخير.";
            }
          }
          break;
        case "mersal_status_updated":
          const mRequestId = payload.request_id || payload.requestId;
          if (mRequestId) {
            const mSnap = await admin.firestore().collection("mersal_requests").doc(mRequestId.toString()).get();
            const mData = mSnap.data() || {};
            if (mData.userId) targetUserIds = [mData.userId.toString()];
            const mStatus = payload.status || "pending";
            const priceVal = payload.price || mData.price;
            const priceText = priceVal ? ` بسعر ${priceVal} د.ع` : "";
            if (mStatus === "accepted") {
              title = "🛵 المندوب قبل طلب مرسال!";
              body = `المندوب قبل طلبك${priceText} وهو بطريقه لموقع الاستلام هسة 🚗`;
            } else if (mStatus === "arrived_at_pickup" || mStatus === "arrived") {
              title = "📍 المندوب وصل لمكان الاستلام!";
              body = "المندوب وصل لنقطة استلام الأمانة / المحل.";
            } else if (mStatus === "picked_up") {
              title = "📦 المندوب استلم الغراض!";
              body = "تم استلام الطلب وبطريقه لنقطة التسليم 💨";
            } else if (mStatus === "on_the_way") {
              title = "🚗 المندوب بالطريق إلك!";
              body = "المندوب طاير إلك لتسليم الطلب.";
            } else if (mStatus === "completed" || mStatus === "delivered") {
              title = "🎉 وصلت الأمانة بسلامة!";
              body = "تم تسليم طلب مرسال الخاص بك بنجاح، شكراً لاختيارك مدار! ⭐";
            } else if (mStatus === "cancelled") {
              title = "❌ تم إلغاء طلب مرسال";
              body = "تم إلغاء طلب مرسال.";
            }
          }
          break;
        case "delegate_status_updated":
          const dRequestId = payload.request_id || payload.requestId;
          if (dRequestId) {
            const dSnap = await admin.firestore().collection("delegate_requests").doc(dRequestId.toString()).get();
            const dData = dSnap.data() || {};
            if (dData.userId) targetUserIds = [dData.userId.toString()];
            const dStatus = payload.status || "pending";
            if (dStatus === "accepted") {
              title = "🤝 المندوب قبل مهمتك!";
              body = "المندوب قبل التفويض وبلش ينفذ طلبك.";
            } else if (dStatus === "completed") {
              title = "🎉 كملت المهمة بنجاح!";
              body = "تم إكمال التوصيل وتأدية المهمة على أتم وجه!";
            }
          }
          break;
        case "order_status_updated":
          const oOrderId = payload.order_id || payload.orderId;
          if (oOrderId) {
            const oSnap = await admin.firestore().collection("orders").doc(oOrderId.toString()).get();
            const oData = oSnap.data() || {};
            const userId = oData.customerId || oData.userId;
            if (userId) targetUserIds = [userId.toString()];
            title = payload.title || "تحديث حالة طلبيتك 🍔";
            body = payload.body || "تم تحديث حالة طلب طعامك.";
          }
          break;
        case "store_order_status_updated":
          const sOrderId = payload.order_id || payload.orderId;
          if (sOrderId) {
            const sSnap = await admin.firestore().collectionGroup("madar_orders").where("orderId", "==", sOrderId.toString()).limit(1).get();
            if (!sSnap.empty) {
              const sData = sSnap.docs[0].data();
              const userId = sData.customerId || sData.userId;
              if (userId) targetUserIds = [userId.toString()];
            }
            title = payload.title || "تحديث حالة طلب المتجر 🛍️";
            body = payload.body || "تم تحديث حالة طلبك من المتجر.";
          }
          break;
        case "complaint_created":
        case "new_complaint":
          targetRoles = ["complaints_admin", "admin"];
          title = "⚠️ شكوى جديدة واصلة للنظام";
          body = payload.body || payload.message || "تم تسجيل شكوى جديدة تتطلب مراجعة الإدارة.";
          break;
        case "new_store_registration_request":
          targetRoles = ["admin", "main_admin", "limited_admin", "governorate_manager"];
          title = "🏪 طلب تسجيل متجر جديد";
          body = `تم تقديم طلب جديد لتسجيل متجر "${payload.storeName || "متجر جديد"}".`;
          break;
        default:
          title = payload.title || request.title || "تنبيه جديد من مدار 🔔";
          body = payload.body || request.body || "لديك إشعار جديد في تطبيق مدار.";
          const directTarget = request.targetUserId || request.userId || payload.targetUserId || payload.userId;
          if (directTarget) targetUserIds = [directTarget.toString()];
          break;
      }

      if (!title || !body) {
        await snap.ref.update({
          status: "FAILED_MALFORMED",
          error: "Missing title or body in notification request",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});
        return null;
      }

      const fcmTokens = [];
      
      const isDeliveryTarget = targetRoles && (
        targetRoles.includes("delivery_captain") ||
        targetRoles.includes("delivery_boy") ||
        targetRoles.includes("delivery") ||
        targetRoles.includes("delegate")
      );

      if (isDeliveryTarget) {
        const delivTargets = await getDeliveryCaptainsPushTargets();
        fcmTokens.push(...delivTargets.fcmTokens);
      }

      if (targetUserIds && targetUserIds.length > 0) {
        for (const uid of targetUserIds) {
          // Save in-app notification history
          await saveNotificationHistory(uid, title, body, type, payload);

          // 🔍 حل توكنات الأجهزة المتعددة
          const userTokens = await resolveDeviceTokensForUser(uid);
          userTokens.forEach((t) => fcmTokens.push(t));
        }
      } else if (targetRoles && targetRoles.length > 0 && !isDeliveryTarget) {
        const usersSnap = await admin.firestore().collection("users").where("role", "in", targetRoles).get();
        for (const doc of usersSnap.docs) {
          const uTokens = await resolveDeviceTokensForUser(doc.id);
          uTokens.forEach((t) => fcmTokens.push(t));
        }

        if (targetRoles.includes("driver") || targetRoles.includes("captain") || targetRoles.includes("taxi_captain")) {
          const driversSnap = await admin.firestore().collection("drivers").where("availability", "==", "online").get();
          for (const doc of driversSnap.docs) {
            const dTokens = await resolveDeviceTokensForUser(doc.id);
            dTokens.forEach((t) => fcmTokens.push(t));
          }
        }
      }

      const channelId = resolveCanonicalChannel(
        request.channelId || (isDeliveryTarget ? CANONICAL_CHANNELS.DELIVERY_URGENT : CANONICAL_CHANNELS.URGENT_ALERTS)
      );

      const notifData = {
        type: type || "system",
        channelId: channelId,
        sound: isDeliveryTarget ? "order_alarm" : "default",
        ...payload,
      };

      const uniqueFcm = [...new Set(fcmTokens.filter(Boolean))];

      let deliveryResult = { successCount: 0, failureCount: 0, prunedCount: 0 };
      if (uniqueFcm.length > 0) {
        deliveryResult = await sendAuthoritativeFCM(uniqueFcm, title, body, notifData, {
          channelId: channelId,
          priority: request.priority || "high",
        });
      }

      // 🛡️ B2, B3, B5: معالجة حالة الفشل المؤقت وإعادة المحاولة الذكية (FCM Real Transient Retry)
      const currentRetry = (request.retryCount || 0);
      const maxRetries = request.maxRetries || 3;

      if (deliveryResult.hasTransientFailure) {
        if (currentRetry < maxRetries) {
          const nextRetryAt = calculateNextRetryTimestamp(currentRetry + 1);
          await snap.ref.update({
            status: "FAILED_RETRYABLE",
            retryCount: currentRetry + 1,
            nextRetryAt: nextRetryAt,
            retryableTokens: deliveryResult.retryableTokens,
            successfulTokens: deliveryResult.successfulTokens,
            deliveredTokensCount: deliveryResult.successCount,
            failedTokensCount: deliveryResult.failureCount,
            prunedTokensCount: deliveryResult.prunedCount,
            lastFailureCode: "transient_fcm_error",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`[FCM Retry Schedule] Request ${snap.id} scheduled for retry ${currentRetry + 1} at ${nextRetryAt.toDate().toISOString()}`);
          return null;
        } else {
          await snap.ref.update({
            status: "DEAD_LETTER",
            retryCount: currentRetry,
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
            finalFailureReason: "max_retries_exceeded",
            deliveredTokensCount: deliveryResult.successCount,
            failedTokensCount: deliveryResult.failureCount,
            prunedTokensCount: deliveryResult.prunedCount,
            successfulTokens: deliveryResult.successfulTokens,
          });
          console.warn(`[FCM Retry Exceeded] Request ${snap.id} reached max retries (${maxRetries}). Moved to DEAD_LETTER.`);
          return null;
        }
      }

      const finalStatus = deliveryResult.successCount > 0
        ? (deliveryResult.failureCount === 0 ? "SENT" : "PARTIAL_SUCCESS")
        : (uniqueFcm.length === 0 ? "FAILED_NO_TOKENS" : "FAILED_TERMINAL");

      await snap.ref.update({
        status: finalStatus,
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        deliveredTokensCount: deliveryResult.successCount,
        failedTokensCount: deliveryResult.failureCount,
        prunedTokensCount: deliveryResult.prunedCount,
        successfulTokens: deliveryResult.successfulTokens,
        retryableTokens: [],
      }).catch(() => {});

      return null;
    } catch (err) {
      console.error("Error in processNotificationRequest:", err);
      const isTransient = isTransientFcmError(err.code, err.message);
      const currentRetry = (request.retryCount || 0);
      const maxRetries = request.maxRetries || 3;

      if (isTransient && currentRetry < maxRetries) {
        const nextRetryAt = calculateNextRetryTimestamp(currentRetry + 1);
        await snap.ref.update({
          status: "FAILED_RETRYABLE",
          retryCount: currentRetry + 1,
          nextRetryAt: nextRetryAt,
          error: err.message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});
      } else {
        await snap.ref.update({
          status: currentRetry >= maxRetries ? "DEAD_LETTER" : "FAILED_TERMINAL",
          error: err.message,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});
      }
      return null;
    }
  });

// ═══════════════════════════════════════════
//  14️⃣ إشعار طوارئ واستغاثة عاجل (Emergency SOS Authoritative Trigger)
// ═══════════════════════════════════════════
exports.notifyOnEmergencySos = functions.firestore
  .document("emergency_sos_alerts/{alertId}")
  .onCreate(async (snap, context) => {
    try {
      const alert = snap.data() || {};
      const alertId = context.params.alertId;
      const driverName = alert.driverName || alert.userName || "سائق مدار";
      const driverPhone = alert.driverPhone || alert.phone || "غير متوفر";
      const location = alert.location || alert.address || "موقع محدد عبر GPS";

      const title = "🚨 نداء استغاثة وطوارئ عاجل (SOS)!";
      const body = `سائق مدار (${driverName}) بحاجة ماسة للمساعدة الفورية!\n📞 هاتف: ${driverPhone}\n📍 الموقع: ${location}`;

      const targetTokens = new Set();

      // 1. جلب توكنات الإدارة
      const adminsSnap = await admin.firestore().collection("users")
        .where("role", "in", ["admin", "super_admin", "main_admin", "limited_admin"])
        .get();
      for (const doc of adminsSnap.docs) {
        const tokens = await resolveDeviceTokensForUser(doc.id);
        tokens.forEach((t) => targetTokens.add(t));
      }

      // 2. جلب توكنات الكباتن المتصلين للمساندة السريعة
      const driversSnap = await admin.firestore().collection("drivers").where("availability", "==", "online").get();
      for (const doc of driversSnap.docs) {
        const tokens = await resolveDeviceTokensForUser(doc.id);
        tokens.forEach((t) => targetTokens.add(t));
      }

      const sosData = {
        type: "emergency_sos",
        alertId: alertId,
        priority: "critical",
        driverName: driverName,
        driverPhone: driverPhone,
        channelId: CANONICAL_CHANNELS.SOS,
      };

      if (targetTokens.size > 0) {
        await sendAuthoritativeFCM(
          Array.from(targetTokens),
          title,
          body,
          sosData,
          { channelId: CANONICAL_CHANNELS.SOS, priority: "critical" }
        );
        console.log(`[SOS Dispatch] Sent emergency SOS alert ${alertId} to ${targetTokens.size} devices.`);
      }
      return null;
    } catch (err) {
      console.error("notifyOnEmergencySos error:", err);
      return null;
    }
  });

// ═══════════════════════════════════════════
//  15️⃣ B4: عامل إعادة المحاولة السحابي الدوري الآمن (Server-Side Retry Worker)
// ═══════════════════════════════════════════
async function executeNotificationRetryBatch(batchLimit = 20) {
  const now = admin.firestore.Timestamp.now();
  const querySnap = await admin.firestore()
    .collection("notification_requests")
    .where("status", "==", "FAILED_RETRYABLE")
    .where("nextRetryAt", "<=", now)
    .limit(batchLimit)
    .get();

  if (querySnap.empty) return { retriedCount: 0 };

  console.log(`[Retry Worker] Found ${querySnap.size} eligible notification requests for retry.`);
  let processed = 0;

  for (const doc of querySnap.docs) {
    // 🔒 قفل التأجير الذري (Atomic Lease Lock) لمنع تكرار الإرسال بين الـ Workers المتزامنين
    let lockAcquired = false;
    try {
      await admin.firestore().runTransaction(async (t) => {
        const currentDoc = await t.get(doc.ref);
        if (!currentDoc.exists || currentDoc.data()?.status !== "FAILED_RETRYABLE") {
          return;
        }
        t.update(doc.ref, {
          status: "RETRYING",
          retryingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        lockAcquired = true;
      });
    } catch (lockErr) {
      console.warn(`[Retry Worker] Could not acquire lock for request ${doc.id}:`, lockErr.message);
      continue;
    }

    if (!lockAcquired) continue;

    try {
      const request = doc.data() || {};
      const tokensToRetry = (request.retryableTokens && request.retryableTokens.length > 0)
        ? request.retryableTokens
        : (request.targetTokens || []);

      if (tokensToRetry.length === 0) {
        await doc.ref.update({
          status: "FAILED_TERMINAL",
          finalFailureReason: "no_tokens_to_retry",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        continue;
      }

      const channelId = resolveCanonicalChannel(request.channelId);
      const notifData = {
        type: request.type || "system",
        channelId: channelId,
        ...(request.payload || {}),
      };

      // 🔁 إرسال الجزء الفاشل فقط دون إعادة إرسال التوكنات الناجحة (Partial Multicast Retry)
      const result = await sendAuthoritativeFCM(
        tokensToRetry,
        request.title,
        request.body,
        notifData,
        { channelId: channelId, priority: request.priority || "high" }
      );

      const currentRetry = (request.retryCount || 1);
      const maxRetries = request.maxRetries || 3;

      if (result.hasTransientFailure) {
        if (currentRetry < maxRetries) {
          const nextRetry = calculateNextRetryTimestamp(currentRetry + 1);
          await doc.ref.update({
            status: "FAILED_RETRYABLE",
            retryCount: currentRetry + 1,
            nextRetryAt: nextRetry,
            retryableTokens: result.retryableTokens,
            successfulTokens: [...(request.successfulTokens || []), ...result.successfulTokens],
            deliveredTokensCount: (request.deliveredTokensCount || 0) + result.successCount,
            lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`[Retry Worker] Request ${doc.id} failed transiently again. Rescheduled attempt ${currentRetry + 1}.`);
        } else {
          await doc.ref.update({
            status: "DEAD_LETTER",
            retryCount: currentRetry,
            finalFailureReason: "max_retries_exceeded",
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
            successfulTokens: [...(request.successfulTokens || []), ...result.successfulTokens],
          });
          console.warn(`[Retry Worker] Request ${doc.id} reached max retries (${maxRetries}). Moved to DEAD_LETTER.`);
        }
      } else if (result.successCount > 0) {
        await doc.ref.update({
          status: result.failureCount === 0 ? "SENT" : "PARTIAL_SUCCESS",
          deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
          deliveredTokensCount: (request.deliveredTokensCount || 0) + result.successCount,
          failedTokensCount: result.failureCount,
          retryableTokens: [],
          successfulTokens: [...(request.successfulTokens || []), ...result.successfulTokens],
        });
        console.log(`[Retry Worker] Request ${doc.id} successfully delivered on retry!`);
      } else {
        await doc.ref.update({
          status: "FAILED_TERMINAL",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          finalFailureReason: "terminal_failure_on_retry",
        });
      }

      processed++;
    } catch (err) {
      console.error(`[Retry Worker] Error retrying request ${doc.id}:`, err);
      await doc.ref.update({
        status: "FAILED_RETRYABLE",
        lastError: err.message,
      }).catch(() => {});
    }
  }

  return { retriedCount: processed };
}

// مشغل الـ Retry المجدول كل دقيقة عبر PubSub
exports.processNotificationRetryWorker = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    return await executeNotificationRetryBatch(20);
  });

// تصدير دالة استدعاء برمجية لاختبار الـ Retry والتحقق منه فورياً
exports.retryEligibleNotificationRequests = functions.https.onCall(async (data, context) => {
  return await executeNotificationRetryBatch(data?.limit || 20);
});

// ==============================================================================
// ==============================================================================
// 🔐 AHYXI OTP SECURE SERVER-SIDE HANDLERS (No client-side secrets & Rate Limited)
// ==============================================================================
const AHYXI_BASE_URL = "https://api.ahyxi.com/api/external";
const AHYXI_API_KEY = process.env.AHYXI_OTP_API_KEY || "otp_92030686fb70f4d8bf513b5e4f616d7c652f03b68703695f41a86055f62f81a6";

// Rate limiting map for OTP requests (phone -> { count, firstRequestTs })
const otpRateLimitMap = new Map();

/// إرسال رمز التحقق OTP عبر السيرفر بأمان مع عزل المفتاح وحماية التكرار
exports.sendAhyxiOtp = functions.https.onCall(async (data, context) => {
  const rawPhone = data?.phoneNumber;
  if (!rawPhone || typeof rawPhone !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "رقم الهاتف مطلوب بصيغة صحيحة");
  }

  // تنظيف وتوحيد رقم الهاتف العراقي
  const cleanPhone = String(rawPhone).replace(/[^\d+]/g, "").trim();
  if (cleanPhone.length < 10 || cleanPhone.length > 16) {
    throw new functions.https.HttpsError("invalid-argument", "رقم الهاتف غير صالح");
  }

  // حماية التردد (Rate Limiting: بحد أقصى 5 محاولات إرسال كل 10 دقائق لكل رقم)
  const now = Date.now();
  const rateRecord = otpRateLimitMap.get(cleanPhone) || { count: 0, firstRequestTs: now };
  if (now - rateRecord.firstRequestTs > 10 * 60 * 1000) {
    rateRecord.count = 1;
    rateRecord.firstRequestTs = now;
  } else {
    rateRecord.count++;
    if (rateRecord.count > 5) {
      throw new functions.https.HttpsError("resource-exhausted", "تجاوزت الحد المسموح لإرسال الرموز. يرجى الانتظار 10 دقائق والمحاولة ثانية.");
    }
  }
  otpRateLimitMap.set(cleanPhone, rateRecord);

  const externalUserId = data?.externalUserId || context.auth?.uid || `usr_${Date.now()}`;

  try {
    const response = await fetch(`${AHYXI_BASE_URL}/send-otp`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": AHYXI_API_KEY,
      },
      body: JSON.stringify({
        externalUserId: String(externalUserId),
        phoneNumber: cleanPhone,
      }),
    });

    const resJson = await response.json().catch(() => ({}));
    if (response.ok) {
      return {
        isSuccess: true,
        message: "تم إرسال رمز التحقق بنجاح إلى هاتفك",
        statusCode: response.status,
        data: resJson,
      };
    } else {
      return {
        isSuccess: false,
        message: resJson?.message || `فشل إرسال رمز التحقق (${response.status})`,
        statusCode: response.status,
      };
    }
  } catch (err) {
    console.error("[Ahyxi Server OTP Send Error]: Connection issue");
    throw new functions.https.HttpsError("internal", "فشل الاتصال بمزود الرسائل. يرجى التحقق من الشبكة.");
  }
});

/// التحقق من رمز OTP وإصدار Firebase Auth Custom Token موقع من السيرفر
exports.verifyAhyxiOtp = functions.https.onCall(async (data, context) => {
  const rawPhone = data?.phoneNumber;
  const otp = data?.otp;
  const name = data?.name || "مستخدم مدار";
  const role = data?.role || "customer";

  if (!rawPhone || !otp) {
    throw new functions.https.HttpsError("invalid-argument", "رقم الهاتف ورمز التحقق مطلوبان");
  }

  const cleanPhone = String(rawPhone).replace(/[^\d+]/g, "").trim();
  const cleanOtp = String(otp).trim();

  if (cleanOtp.length < 4 || cleanOtp.length > 8) {
    throw new functions.https.HttpsError("invalid-argument", "رمز التحقق غير صالح");
  }

  try {
    const response = await fetch(`${AHYXI_BASE_URL}/verify-otp`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": AHYXI_API_KEY,
      },
      body: JSON.stringify({
        phoneNumber: cleanPhone,
        otp: cleanOtp,
      }),
    });

    const resJson = await response.json().catch(() => ({}));
    if (!response.ok) {
      return {
        isSuccess: false,
        message: resJson?.message || "رمز التحقق غير صحيح أو منتهي الصلاحية",
        statusCode: response.status,
      };
    }

    // بعد نجاح التحقق: إنشاء أو جلب معرف مستخدم آمن وفريد لرقم الهاتف
    const normalizedDigits = cleanPhone.replace(/[^0-9]/g, "");
    let uid;
    
    try {
      const existingUser = await admin.auth().getUserByPhoneNumber(cleanPhone).catch(() => null);
      if (existingUser) {
        uid = existingUser.uid;
      } else {
        const userQuery = await admin.firestore().collection("users").where("phone", "==", cleanPhone).limit(1).get();
        if (!userQuery.empty) {
          uid = userQuery.docs[0].id;
        } else {
          const newUser = await admin.auth().createUser({
            phoneNumber: cleanPhone.startsWith("+") ? cleanPhone : `+${normalizedDigits}`,
            displayName: name,
          }).catch(async () => {
            return await admin.auth().createUser({
              displayName: name,
            });
          });
          uid = newUser.uid;
        }
      }
    } catch (_) {
      uid = `usr_${normalizedDigits}`;
    }

    // مزامنة مستند المستخدم في Firestore
    const userDocRef = admin.firestore().collection("users").doc(uid);
    const userSnap = await userDocRef.get();
    if (!userSnap.exists) {
      await userDocRef.set({
        uid: uid,
        phone: cleanPhone,
        name: name,
        role: role,
        status: role === "customer" ? "active" : "pending",
        isApproved: role === "customer",
        isPhoneVerified: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await userDocRef.update({
        phone: cleanPhone,
        isPhoneVerified: true,
        lastLogin: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // توليد Custom Token موثق وموقع من Firebase Admin
    const customToken = await admin.auth().createCustomToken(uid, {
      phone: cleanPhone,
      role: role,
      isPhoneVerified: true,
    });

    return {
      isSuccess: true,
      message: "تم التحقق من الرمز بنجاح",
      customToken: customToken,
      uid: uid,
    };
  } catch (err) {
    console.error("[Ahyxi Server OTP Verify Error]:", err.message);
    throw new functions.https.HttpsError("internal", "فشل التحقق من الرمز عبر السيرفر");
  }
});

// ==============================================================================
// 🛡️ ADMIN CUSTOM CLAIMS SYNCHRONIZATION TRIGGER (Storage Rules & Auth Security)
// ==============================================================================
exports.syncUserCustomClaims = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    if (!change.after.exists) {
      // تم حذف المستخدم
      return null;
    }

    const data = change.after.data();
    const role = data?.role?.toString().toLowerCase() || "customer";
    const adminRoles = ["admin", "super_admin", "main_admin", "limited_admin", "complaints_admin"];
    const isAdmin = adminRoles.includes(role);

    try {
      const currentClaims = (await admin.auth().getUser(userId).catch(() => null))?.customClaims || {};
      if (currentClaims.role !== role || currentClaims.admin !== isAdmin) {
        await admin.auth().setCustomUserClaims(userId, {
          ...currentClaims,
          role: role,
          admin: isAdmin,
        });
        console.log(`[Custom Claims Sync] Updated claims for user ${userId}: role=${role}, admin=${isAdmin}`);
      }
    } catch (err) {
      console.warn(`[Custom Claims Sync] Could not set claims for user ${userId}:`, err.message);
    }
    return null;
  });

// ==============================================================================
// 🤖 SMART ASSISTANT GEMINI AI PROXY (Authenticated & Server-Side Protected)
// ==============================================================================
exports.askSmartAssistant = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول لاستخدام المساعد الذكي");
  }

  const prompt = data?.prompt;
  if (!prompt || typeof prompt !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "نص السؤال مطلوب");
  }

  // فحص أقصى طول للنص لمنع الإغراق (Input Length Protection: max 2000 chars)
  const trimmedPrompt = prompt.trim();
  if (trimmedPrompt.length > 2000) {
    throw new functions.https.HttpsError("invalid-argument", "نص السؤال يتجاوز الحد الأقصى المسموح به (2000 حرف)");
  }

  const geminiKey = process.env.GEMINI_API_KEY;
  if (!geminiKey) {
    // إجابة ذكية مسبقة إذا لم يتم تكوين المفتاح بعد في السيرفر
    const defaultReply = "تدلل عيوني! أنا سكوزمي مساعدك الذكي في مدار. شتريد أساعدك بيه اليوم؟ حجز تكسي، طلب أكل، لو متابعة طلباتك؟";
    return {
      success: true,
      reply: defaultReply,
      text: defaultReply,
    };
  }

  try {
    const systemInstruction = "أنت 'سكوزمي' المساعد الذكي الرسمي لمنصة مدار في العراق. تجيب بلباقة واحترافية وباللهجة العراقية الودودة والمحترمة، وتساعد في حجز التكسي، طلبات المطاعم، تسوق المتاجر، والتوصيل.";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`;

    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          { role: "user", parts: [{ text: `${systemInstruction}\n\nالسؤال: ${trimmedPrompt}` }] }
        ],
      }),
    });

    const resJson = await res.json();
    const candidateText = resJson?.candidates?.[0]?.content?.parts?.[0]?.text;
    const finalReply = candidateText || "تدلل عيوني، بخدمتك بأي وقت لأي طلب بمدار.";
    return {
      success: true,
      reply: finalReply,
      text: finalReply,
    };
  } catch (err) {
    console.error("[Smart Assistant Error]: AI proxy communication issue");
    const fallbackReply = "عيوني، صار خلل بسيط بالاتصال. شلون أكدر أساعدك بطلبات مدار الثانية؟";
    return {
      success: true,
      reply: fallbackReply,
      text: fallbackReply,
    };
  }
});

