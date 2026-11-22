import 'package:flutter/material.dart';

/// App-wide keys, so non-widget code (MonitorController) can show snackbars
/// and dialogs without holding a BuildContext.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
