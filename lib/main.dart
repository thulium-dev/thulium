import 'package:flutter/material.dart';

import 'app.dart';
import 'diagnostics/diagnostic_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DiagnosticLog.instance.install();
  // Keep the executable entry point small; application composition lives in
  // app.dart so pages and reusable widgets can evolve independently.
  runApp(const ThuliumApp());
}
