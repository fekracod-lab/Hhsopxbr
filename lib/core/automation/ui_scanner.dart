import 'package:flutter/material.dart';

/// ماسح واجهة متقدم يقرأ النصوص والأزرار والحقول بدقة عالية
/// ويقدم وصفاً هيكلياً واضحاً للذكاء الاصطناعي
class UIScanner {
  /// تحليل مميزات كل تخصص/صفحة لتزويد الذكاء الاصطناعي بها
  static String _getPageFeatures(String route) {
    switch (route) {
      case '/vacancies':
        return '''
صفحة الوظائف وفرص العمل.
الميزات المتاحة للتحكم بها:
- البحث عن وظيفة: JOB_SEARCH: "نص البحث"
- تصفية القسم: JOB_CATEGORY: "تقنية/تعليم/صحة/هندسة/تجارة/خدمات/أخرى"
- تصفية الباحثين/فرص العمل/المحفوظات: JOB_FILTER: "seeker/employer/saved/all"
- ترتيب الوظائف: JOB_SORT: "date_desc/date_asc/likes_desc"
- إضافة إعلان وظيفة: JOB_ADD
''';
      case '/complaints':
        return '''
صفحة مركز الشكاوى والاقتراحات.
الميزات المتاحة للتحكم بها:
- البحث في الشكاوى: COMPLAINT_SEARCH: "نص البحث"
- تصفية نوع البلاغ: COMPLAINT_TYPE: "complaint/suggestion/all"
- تصفية حالة الشكوى: COMPLAINT_STATUS: "قيد المراجعة/قيد المعالجة/تم الحل/مرفوض/الكل"
- إضافة شكوى/اقتراح جديدة وتعبئتها تلقائياً بحقول قابلة للتعديل والمسح بالكامل: COMPLAINT_ADD: {"title": "عنوان الشكوى", "desc": "شرح تفاصيل البلاغ والوصف الكامل", "type": "complaint/suggestion"}
''';
      case '/studios':
        return '''
صفحة استوديوهات التصوير الاحترافي.
الميزات المتاحة للتحكم بها:
- البحث عن استوديو بالاسم: STUDIO_SEARCH: "اسم الاستوديو"
- تصفية نوع التصوير: STUDIO_FILTER: "تصوير زفاف/تصوير بورتريه/تصوير منتجات/تصوير أطفال/تصوير فيديو/عام/الكل"
- إضافة استوديو تصوير جديد: STUDIO_ADD
''';
      case '/restaurants':
        return '''
صفحة المطاعم وتوصيل الطعام.
الميزات المتاحة للتحكم بها:
- تصفية فئة المطاعم: RESTAURANT_CATEGORY: "المطاعم/الحلويات/العصائر/المنزلية/الكل"
- البحث عن وجبة أو مطعم: RESTAURANT_SEARCH: "نص البحث"
''';
      default:
        return 'الصفحة الرئيسية للتطبيق أو صفحة عامة.';
    }
  }

  /// يمسح شجرة الويدجيتس ويعيد وصفاً نصياً تفصيلياً مع حقن معلومات ومسار الصفحة وميزاتها
  static String scan(BuildContext context) {
    BuildContext? rootContext;
    context.visitAncestorElements((element) {
      if (element.widget is Scaffold || element.widget is Navigator) {
        rootContext = element;
      }
      return true; // continue up to find the highest Scaffold/Navigator
    });
    
    final scanContext = rootContext ?? context;
    final route = ModalRoute.of(scanContext)?.settings.name ?? '/home';
    final pageFeatures = _getPageFeatures(route);
    
    final elements = <Map<String, String>>[];

    void visitor(Element element) {
      final widget = element.widget;
      String? type;
      String? text;
      String? keyStr = widget.key?.toString();

      if (widget is Text && widget.data != null && widget.data!.trim().isNotEmpty) {
        type = 'Text';
        text = widget.data!.trim();
      } else if (widget is RichText) {
        final plainText = widget.text.toPlainText().trim();
        if (plainText.isNotEmpty) {
          type = 'Text';
          text = plainText;
        }
      } else if (widget is TextField || widget is TextFormField) {
        type = 'TextField';
        if (widget is TextField) {
          text = widget.decoration?.hintText ?? widget.decoration?.labelText ?? '';
        } else if (widget is TextFormField) {
          text = '';
        }
      } else if (widget is ElevatedButton) {
        type = 'Button';
        text = _extractChildText(element);
      } else if (widget is TextButton) {
        type = 'TextButton';
        text = _extractChildText(element);
      } else if (widget is OutlinedButton) {
        type = 'Button';
        text = _extractChildText(element);
      } else if (widget is IconButton) {
        type = 'IconButton';
        text = widget.tooltip ?? '';
      } else if (widget is FloatingActionButton) {
        type = 'FAB';
        text = widget.tooltip ?? _extractChildText(element);
      } else if (widget is ListTile) {
        type = 'ListTile';
        text = _extractChildText(element);
      } else if (widget is Card) {
        type = 'Card';
        text = _extractChildText(element);
      } else if (widget is InkWell || widget is GestureDetector) {
        final innerText = _extractChildText(element);
        if (innerText != null && innerText.isNotEmpty) {
          type = 'Clickable';
          text = innerText;
        }
      } else if (widget is BottomNavigationBar) {
        type = 'BottomNav';
        text = 'شريط التنقل السفلي';
      } else if (widget is TabBar) {
        type = 'TabBar';
        text = _extractChildText(element);
      } else if (widget is DropdownButton || widget is DropdownButtonFormField) {
        type = 'Dropdown';
        text = _extractChildText(element);
      }

      if (type != null && text != null && text.isNotEmpty) {
        elements.add({
          'type': type,
          'text': text,
          if (keyStr != null) 'key': keyStr,
        });
      }

      // استمر في مسح الأبناء
      element.visitChildren(visitor);
    }

    scanContext.visitChildElements(visitor);

    // بناء الوصف النصي
    final buffer = StringBuffer();
    buffer.writeln('[معلومات الصفحة الحالية]');
    buffer.writeln('المسار (Route): "$route"');
    buffer.writeln('الميزات والخصائص المدعومة في هذه الصفحة:');
    buffer.writeln(pageFeatures);
    buffer.writeln();

    buffer.writeln('[حالة_الواجهة]');
    for (int i = 0; i < elements.length && i < 60; i++) {
      final e = elements[i];
      buffer.write('- ${e['type']}: "${e['text']}"');
      if (e.containsKey('key')) {
        buffer.write(' (مفتاح: ${e['key']})');
      }
      buffer.writeln();
    }
    buffer.writeln('[نهاية_الواجهة]');
    return buffer.toString();
  }

  /// يستخلص النص المتواجد داخل عنصر فرعي (مثل زر أو قائمة)
  static String? _extractChildText(Element parentElement) {
    String? foundText;

    void childVisitor(Element child) {
      if (foundText != null && foundText!.length > 50) return;
      final w = child.widget;
      if (w is Text && w.data != null && w.data!.trim().isNotEmpty) {
        if (foundText == null) {
          foundText = w.data!.trim();
        } else {
          foundText = '$foundText | ${w.data!.trim()}';
        }
      } else if (w is RichText) {
        final plain = w.text.toPlainText().trim();
        if (plain.isNotEmpty) {
          foundText ??= plain;
        }
      } else if (w is Icon) {
        // تخطي الأيقونات
      } else {
        child.visitChildren(childVisitor);
      }
    }

    parentElement.visitChildren(childVisitor);
    return foundText;
  }

  /// يبحث عن عنصر في الواجهة حسب النص أو المفتاح ويعيد موقعه وأبعاده
  static Rect? findElementRect(BuildContext context, String target) {
    BuildContext? rootContext;
    context.visitAncestorElements((element) {
      if (element.widget is Scaffold || element.widget is Navigator) {
        rootContext = element;
      }
      return true;
    });
    
    final scanContext = rootContext ?? context;
    Rect? result;

    void visitor(Element element) {
      if (result != null) return;
      final widget = element.widget;

      bool isMatch = false;

      // فحص المفتاح
      if (widget.key?.toString().contains(target) == true) {
        isMatch = true;
      }

      // فحص النص
      if (!isMatch && widget is Text && widget.data?.contains(target) == true) {
        isMatch = true;
      }

      // فحص التلميح في حقول الإدخال
      if (!isMatch && widget is TextField) {
        if (widget.decoration?.hintText?.contains(target) == true ||
            widget.decoration?.labelText?.contains(target) == true) {
          isMatch = true;
        }
      }

      // فحص النص الداخلي للأزرار والعناصر القابلة للنقر
      if (!isMatch) {
        final innerText = _extractChildText(element);
        if (innerText?.contains(target) == true) {
          isMatch = true;
        }
      }

      if (isMatch) {
        final renderObject = element.renderObject;
        if (renderObject is RenderBox && renderObject.hasSize) {
          final position = renderObject.localToGlobal(Offset.zero);
          result = Rect.fromLTWH(
            position.dx,
            position.dy,
            renderObject.size.width,
            renderObject.size.height,
          );
        }
      } else {
        element.visitChildren(visitor);
      }
    }

    scanContext.visitChildElements(visitor);
    return result;
  }

  /// يبحث عن حقل إدخال ويُدخل نصاً فيه تلقائياً
  static bool fillTextField(BuildContext context, String target, String value) {
    BuildContext? rootContext;
    context.visitAncestorElements((element) {
      if (element.widget is Scaffold || element.widget is Navigator) {
        rootContext = element;
      }
      return true;
    });
    
    final scanContext = rootContext ?? context;
    bool filled = false;

    void visitor(Element element) {
      if (filled) return;
      final widget = element.widget;

      if (widget is TextField) {
        final hint = widget.decoration?.hintText ?? '';
        final label = widget.decoration?.labelText ?? '';
        if (hint.contains(target) || label.contains(target)) {
          if (widget.controller != null) {
            widget.controller!.text = value;
            filled = true;
            return;
          }
        }
      }

      if (widget is TextFormField) {
        // نحاول استخراج الـ controller من الـ state
        // نبحث في الأبناء عن TextField الفعلي
        element.visitChildren(visitor);
        return;
      }

      element.visitChildren(visitor);
    }

    scanContext.visitChildElements(visitor);
    return filled;
  }
}
