import 'package:flutter/material.dart';

import 'app.dart';
import 'src/app_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel();
  runApp(MesTachesApp(model: model));
  await model.start();
}
