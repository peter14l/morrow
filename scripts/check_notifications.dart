import 'dart:io';

void main() async {
  print('Checking Windows Notification Registry Settings...');

  if (!Platform.isWindows) return;

  const script = r'''
$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
$name = "ToastEnabled"
try {
    $val = (Get-ItemProperty -Path $path -ErrorAction SilentlyContinue).$name
    Write-Host "Global Notifications (ToastEnabled): $val"
} catch {
    Write-Host "Could not read global ToastEnabled setting."
}

$path2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
Write-Host "`nSearching for App-specific settings in Registry:"
if (Test-Path $path2) {
    Get-ChildItem -Path $path2 | Where-Object { $_.Name -like "*oasis*" } | Select-Object Name
} else {
    Write-Host "Notification settings path not found."
}
''';

  final result = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    script,
  ], runInShell: true);
  print(result.stdout);
}
