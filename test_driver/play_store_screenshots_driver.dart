import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDirectory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}play-assets'
    '${Platform.pathSeparator}staging${Platform.pathSeparator}phone',
  );

  await integrationDriver(
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      await outputDirectory.create(recursive: true);
      final outputFile = File(
        '${outputDirectory.path}${Platform.pathSeparator}$screenshotName.png',
      );
      await outputFile.writeAsBytes(screenshotBytes, flush: true);
      stdout.writeln('Screenshot salvo em ${outputFile.path}');
      return true;
    },
  );
}
