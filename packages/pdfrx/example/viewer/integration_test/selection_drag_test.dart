import 'package:integration_test/integration_test.dart';
import 'package:telosnex_web_test/telosnex_web_test.dart';

import '../../../test/pdf_viewer_selection_drag_test.dart' as selection;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  installWebTestSupport(binding);
  selectionDragIntegrationTests();
}

/// Also called by all.dart, the entry point of the web and iOS runs.
void selectionDragIntegrationTests() {
  selection.selectionDragTests(useFlutterInitialization: true);
}
