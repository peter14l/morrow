import 'dart:io';

void main() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }

  String content = file.readAsStringSync();

  // 1. Update Version Name and Increment Build Number
  // Current format is version: x.y.z+n
  final versionRegExp = RegExp(r'version: (\d+\.\d+\.\d+)\+(\d+)');
  final match = versionRegExp.firstMatch(content);

  if (match != null) {
    final String currentVersionName = match.group(1)!;
    final int currentBuildNumber = int.parse(match.group(2)!);

    // We set base to 4.1.0 as requested, then increment build number
    const String newVersionName = '4.1.0';
    final int newBuildNumber = currentBuildNumber + 1;

    final String oldVersionLine =
        'version: $currentVersionName+$currentBuildNumber';
    final String newVersionLine = 'version: $newVersionName+$newBuildNumber';

    content = content.replaceFirst(oldVersionLine, newVersionLine);
    print('Updated pubspec version: $newVersionLine');

    // 2. Update MSIX version if present
    // MSIX version usually follows x.y.z.0 format
    final msixRegExp = RegExp(r'msix_version: (\d+\.\d+\.\d+)\.0');
    if (msixRegExp.hasMatch(content)) {
      final String oldMsixLine = 'msix_version: $currentVersionName.0';
      // For MSIX, we can use the same version name.
      // Note: MSIX requires 4 segments (e.g., 4.1.0.0)
      const String newMsixLine = 'msix_version: $newVersionName.0';
      content = content.replaceFirst(msixRegExp, newMsixLine);
      print('Updated MSIX version: $newMsixLine');
    }

    file.writeAsStringSync(content);
  } else {
    print('Error: Could not find version line in pubspec.yaml');
    exit(1);
  }
}
