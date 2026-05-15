import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import '../core/utils/error_parser.dart';

class CustomSnackbar {
  static bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static void showError(BuildContext context, dynamic errorOrMessage) {
    final message = errorOrMessage is String
        ? errorOrMessage
        : ErrorParser.parse(errorOrMessage);

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.useFluentUI && _isDesktop(context)) {
      fluent.displayInfoBar(
        context,
        builder: (context, close) => fluent.InfoBar(
          title: const Text('Error'),
          content: Text(message),
          severity: fluent.InfoBarSeverity.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.useFluentUI && _isDesktop(context)) {
      fluent.displayInfoBar(
        context,
        builder: (context, close) => fluent.InfoBar(
          title: const Text('Success'),
          content: Text(message),
          severity: fluent.InfoBarSeverity.success,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
