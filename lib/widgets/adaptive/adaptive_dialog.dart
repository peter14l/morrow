import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';

class AdaptiveDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget title,
    required Widget content,
    List<Widget>? actions,
  }) {
    final useFluent = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).useFluentUI;

    if (useFluent) {
      return fluent.showDialog<T>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: title,
          content: content,
          actions: actions,
        ),
      );
    }

    return material.showDialog<T>(
      context: context,
      builder: (context) => material.AlertDialog(
        title: title,
        content: content,
        actions: actions,
      ),
    );
  }

  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String content,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    material.Color? confirmColor,
    bool isDestructive = false,
  }) {
    final useFluent = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).useFluentUI;

    if (useFluent) {
      return fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: isDestructive
                  ? fluent.ButtonStyle(
                      backgroundColor: fluent.WidgetStateProperty.all(
                        fluent.Colors.red,
                      ),
                    )
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    }

    return material.showDialog<bool>(
      context: context,
      builder: (context) => material.AlertDialog(
        title: material.Text(title),
        content: material.Text(content),
        actions: [
          material.TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: material.Text(cancelLabel),
          ),
          material.ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: material.ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? material.Colors.red : null,
              foregroundColor: isDestructive ? material.Colors.white : null,
            ),
            child: material.Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
