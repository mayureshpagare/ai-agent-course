// The integration test's journey, run on the VM so `flutter test` covers it
// without a device. The same journey runs on a device via
// integration_test/app_test.dart.
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/journeys/happy_path.dart';

void main() {
  testWidgets('happy path: pair, pick agent, send, approve, answer, rename, delete', runHappyPath);
}
