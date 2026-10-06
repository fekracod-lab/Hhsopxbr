// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final file = File('lib/pages/teachers_directory_page.dart');
  if (file.existsSync()) {
    var content = file.readAsStringSync();
    content = content.replaceAll('\u00A0', ' ');
    file.writeAsStringSync(content);
    print(
      'Successfully replaced non-breaking spaces with normal spaces in teachers_directory_page.dart',
    );
  } else {
    print('File not found!');
  }
}
