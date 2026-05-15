import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  print('Testing Windows Native Notification...');

  if (!Platform.isWindows) {
    print('Error: This script only works on Windows.');
    return;
  }

  final List<String> testAppIds = [
    'com.oasis.v2_fxkeb4dgdm144!oasisv2', // Official
    'Chrome',
    'MSEdge',
    'com.squirrel.Discord.Discord',
    'Microsoft.VisualStudioCode',
  ];

  for (final appId in testAppIds) {
    print('--- Attempting notification with App ID: $appId ---');
    final psScript =
        '''
\$code = @"
using System;
using Windows.UI.Notifications;
using Windows.Data.Xml.Dom;

public class Toast {
    public static void Show(string appId, string title, string body) {
        try {
            XmlDocument toastXml = ToastNotificationManager.GetTemplateContent(ToastTemplateType.ToastText02);
            XmlNodeList stringElements = toastXml.GetElementsByTagName("text");
            stringElements[0].AppendChild(toastXml.CreateTextNode(title));
            stringElements[1].AppendChild(toastXml.CreateTextNode(body));
            ToastNotification toast = new ToastNotification(toastXml);
            ToastNotificationManager.CreateToastNotifier(appId).Show(toast);
        } catch (Exception e) {
            Console.WriteLine("Error for " + appId + ": " + e.Message);
        }
    }
}
"@

if (-not ([VisualTreeHelper])) {
    try {
        Add-Type -TypeDefinition \$code -ReferencedAssemblies "Windows.UI.Notifications", "Windows.Data.Xml.Dom" -ErrorAction SilentlyContinue
    } catch {}
}
[Toast]::Show("$appId", "Oasis Test ($appId)", "Testing notification system with this ID.")
''';

    final tempFile = File(
      p.join(
        Directory.systemTemp.path,
        'oasis_test_notif_${appId.hashCode}.ps1',
      ),
    );
    try {
      await tempFile.writeAsString(psScript);
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        tempFile.path,
      ]);
      print('Result for $appId: Exit Code ${result.exitCode}');
      if (result.stdout.toString().trim().isNotEmpty) {
        print('Output: ${result.stdout.trim()}');
      }
      if (result.stderr.toString().trim().isNotEmpty) {
        print('Error Output: ${result.stderr.trim()}');
      }
    } catch (e) {
      print('Failed to run test for $appId: $e');
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
