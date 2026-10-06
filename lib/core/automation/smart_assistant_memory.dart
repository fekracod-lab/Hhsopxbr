import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

/// نظام الذاكرة المستمرة للمساعد الذكي سكوزمي
/// يحفظ تفضيلات المستخدم، عناوينه، أكلاته، لقبه العراقي، وملاحظاته في الجهاز والفايربيس
class SmartAssistantMemory {
  static final SmartAssistantMemory _instance = SmartAssistantMemory._internal();
  factory SmartAssistantMemory() => _instance;
  SmartAssistantMemory._internal();

  String? customNickname;
  String? homeAddress;
  String? workAddress;
  List<String> favoriteFoods = [];
  List<String> userNotes = [];
  String? lastMood;
  DateTime? lastMoodTime;
  int interactionCount = 0;

  bool _isLoaded = false;

  /// تحميل الذاكرة من SharedPreferences ومن Firestore
  Future<void> loadMemory() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      customNickname = prefs.getString('skozme_nickname');
      homeAddress = prefs.getString('skozme_home_address');
      workAddress = prefs.getString('skozme_work_address');
      lastMood = prefs.getString('skozme_last_mood');
      final moodTimeStr = prefs.getString('skozme_last_mood_time');
      if (moodTimeStr != null) {
        lastMoodTime = DateTime.tryParse(moodTimeStr);
      }
      favoriteFoods = prefs.getStringList('skozme_favorite_foods') ?? [];
      userNotes = prefs.getStringList('skozme_user_notes') ?? [];
      interactionCount = prefs.getInt('skozme_interaction_count') ?? 0;

      // مزامنة سحابية إذا كان المستخدم مسجلاً
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('ai_assistant')
            .doc('memory')
            .get();

        if (doc.exists) {
          final data = doc.data() ?? {};
          if (data['customNickname'] != null && customNickname == null) {
            customNickname = data['customNickname'];
          }
          if (data['homeAddress'] != null && homeAddress == null) {
            homeAddress = data['homeAddress'];
          }
          if (data['workAddress'] != null && workAddress == null) {
            workAddress = data['workAddress'];
          }
          if (data['favoriteFoods'] is List) {
            final list = List<String>.from(data['favoriteFoods']);
            for (var f in list) {
              if (!favoriteFoods.contains(f)) favoriteFoods.add(f);
            }
          }
          if (data['userNotes'] is List) {
            final list = List<String>.from(data['userNotes']);
            for (var n in list) {
              if (!userNotes.contains(n)) userNotes.add(n);
            }
          }
        }
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading Skozme memory: $e');
    }
  }

  /// حفظ اللقب المفضل للمستخدم
  Future<void> setNickname(String nickname) async {
    customNickname = nickname.trim();
    await _saveToStorage();
  }

  /// حفظ عنوان البيت
  Future<void> setHomeAddress(String address) async {
    homeAddress = address.trim();
    await _saveToStorage();
  }

  /// حفظ عنوان العمل/الدوام
  Future<void> setWorkAddress(String address) async {
    workAddress = address.trim();
    await _saveToStorage();
  }

  /// إضافة أكلة مفضلة
  Future<void> addFavoriteFood(String food) async {
    final cleanFood = food.trim();
    if (cleanFood.isNotEmpty && !favoriteFoods.contains(cleanFood)) {
      favoriteFoods.add(cleanFood);
      await _saveToStorage();
    }
  }

  /// إضافة ملاحظة عامة
  Future<void> addUserNote(String note) async {
    final cleanNote = note.trim();
    if (cleanNote.isNotEmpty && !userNotes.contains(cleanNote)) {
      userNotes.add(cleanNote);
      await _saveToStorage();
    }
  }

  /// تحديث الحالة المزاجية الأخيرة
  Future<void> setMood(String mood) async {
    lastMood = mood;
    lastMoodTime = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('skozme_last_mood', mood);
      await prefs.setString('skozme_last_mood_time', lastMoodTime!.toIso8601String());
    } catch (_) {}
  }

  /// زيادة عداد التفاعل
  Future<void> incrementInteraction() async {
    interactionCount++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('skozme_interaction_count', interactionCount);
    } catch (_) {}
  }

  /// مسح الذاكرة بالكامل
  Future<void> clearMemory() async {
    customNickname = null;
    homeAddress = null;
    workAddress = null;
    favoriteFoods.clear();
    userNotes.clear();
    lastMood = null;
    lastMoodTime = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('skozme_nickname');
      await prefs.remove('skozme_home_address');
      await prefs.remove('skozme_work_address');
      await prefs.remove('skozme_favorite_foods');
      await prefs.remove('skozme_user_notes');
      await prefs.remove('skozme_last_mood');
      await prefs.remove('skozme_last_mood_time');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('ai_assistant')
            .doc('memory')
            .delete();
      }
    } catch (e) {
      debugPrint('Error clearing memory: $e');
    }
  }

  /// حفظ البيانات محلياً وسحابياً
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (customNickname != null) await prefs.setString('skozme_nickname', customNickname!);
      if (homeAddress != null) await prefs.setString('skozme_home_address', homeAddress!);
      if (workAddress != null) await prefs.setString('skozme_work_address', workAddress!);
      await prefs.setStringList('skozme_favorite_foods', favoriteFoods);
      await prefs.setStringList('skozme_user_notes', userNotes);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('ai_assistant')
            .doc('memory')
            .set({
          'customNickname': customNickname,
          'homeAddress': homeAddress,
          'workAddress': workAddress,
          'favoriteFoods': favoriteFoods,
          'userNotes': userNotes,
          'lastMood': lastMood,
          'lastMoodTime': lastMoodTime != null ? Timestamp.fromDate(lastMoodTime!) : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving Skozme memory: $e');
    }
  }

  /// إرجاع ملخص الذاكرة المنسق للاستخدام في البرومبت ولإعلام المستخدم
  String getMemorySummary() {
    final List<String> parts = [];
    if (customNickname != null && customNickname!.isNotEmpty) {
      parts.add('• يناديك: **$customNickname**');
    }
    if (homeAddress != null && homeAddress!.isNotEmpty) {
      parts.add('• عنوان البيت: **$homeAddress**');
    }
    if (workAddress != null && workAddress!.isNotEmpty) {
      parts.add('• مكان الدوام/العمل: **$workAddress**');
    }
    if (favoriteFoods.isNotEmpty) {
      parts.add('• أكلاتك المفضلة: **${favoriteFoods.join("،")}**');
    }
    if (userNotes.isNotEmpty) {
      parts.add('• ملاحظات خاصة بيك:\n ${userNotes.map((n) => "- $n").join("\n ")}');
    }

    if (parts.isEmpty) {
      return 'ذاكرتي فارغة حالياً وما حافظ شي عنك يا غالي! تكدر تكلي "احفظ اني احب الكباب"أو "احفظ بيتي بالقائم" وحفظها فوراً ببالي!';
    }

    return ' **كل اللي حافظه سكوزمي بباله عنك:**\n\n${parts.join("\n")}\n\nتكدر بأي وقت تكلي "احفظ..."لإضافة معلومة جديدة، أو "امسح ذاكرتك" لمسح كلشي! ';
  }

  /// ملخص مخصص ليتم حقنه في Gemini LLM
  String getPromptContext() {
    final Map<String, dynamic> map = {};
    if (customNickname != null) map['preferred_name'] = customNickname;
    if (homeAddress != null) map['home_location'] = homeAddress;
    if (workAddress != null) map['work_location'] = workAddress;
    if (favoriteFoods.isNotEmpty) map['favorite_food'] = favoriteFoods;
    if (userNotes.isNotEmpty) map['user_notes'] = userNotes;
    if (lastMood != null) map['recent_mood'] = lastMood;
    return json.encode(map);
  }
}
