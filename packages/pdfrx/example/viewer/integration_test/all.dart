// Every integration test in one app: the web and iOS runs build and launch
// the app once, so they run this entry point instead of the files one by one.
// It is not named *_test.dart: the desktop and Android runs use those files.
import 'package:integration_test/integration_test.dart';
import 'package:telosnex_web_test/telosnex_web_test.dart';

import 'pdf_text_only_test.dart' as text_only;
import 'pdfium_android_loading_test.dart' as loading;
import 'selection_drag_test.dart' as selection_drag;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  installWebTestSupport(binding);
  loading.pdfiumLoadingTests();
  text_only.pdfTextOnlyTests();
  selection_drag.selectionDragIntegrationTests();
}
