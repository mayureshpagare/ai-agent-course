// Run on a device or emulator:  flutter test integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'journeys/happy_path.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('happy path: pair, pick agent, send, approve, answer, rename, delete', runHappyPath);
}
