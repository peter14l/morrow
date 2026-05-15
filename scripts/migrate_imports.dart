import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found.');
    return;
  }

  final featuresDir = Directory(p.join('lib', 'features'));
  if (!featuresDir.existsSync()) {
    print('lib/features directory not found.');
    return;
  }

  // 1. Map all files in lib/features
  final featureFiles = <String, List<String>>{};
  await for (final entity in featuresDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final basename = p.basename(entity.path);
      featureFiles.putIfAbsent(basename, () => []).add(entity.path);
    }
  }

  // 2. Identify potential duplicates in old directories
  final oldDirs = ['models', 'providers', 'screens', 'services', 'widgets']
      .map((d) => Directory(p.join('lib', d)))
      .where((d) => d.existsSync())
      .toList();

  final duplicates = <String, String>{}; // old path -> new path

  for (final dir in oldDirs) {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final basename = p.basename(entity.path);
        if (featureFiles.containsKey(basename)) {
          final newPaths = featureFiles[basename]!;
          if (newPaths.length == 1) {
            duplicates[entity.path] = newPaths.first;
          } else {
            // Try to match by some heuristic or ask for manual check
            print('Collision for $basename: $newPaths. Skipping.');
          }
        }
      }
    }
  }

  print('Found ${duplicates.length} duplicates to migrate.');

  // 3. For each file in lib, parse imports and update them
  final allDartFiles = <File>[];
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      allDartFiles.add(entity);
    }
  }

  int updatedFilesCount = 0;

  for (final file in allDartFiles) {
    bool fileModified = false;
    final lines = await file.readAsLines();
    final newLines = <String>[];

    for (var line in lines) {
      if (!line.trim().startsWith('import') &&
          !line.trim().startsWith('export')) {
        newLines.add(line);
        continue;
      }

      // Extract path within quotes
      final RegExp quoteExp = RegExp(
        r"['"
        "]([^'"
        "]+)['"
        ']',
      );
      final match = quoteExp.firstMatch(line);
      if (match == null) {
        newLines.add(line);
        continue;
      }

      final importPath = match.group(1)!;
      String absoluteResolvedPath = '';

      if (importPath.startsWith('package:oasis/')) {
        absoluteResolvedPath = p.normalize(
          p.join('lib', importPath.substring('package:oasis/'.length)),
        );
      } else if (importPath.startsWith('dart:') ||
          importPath.startsWith('package:')) {
        // External package, do nothing
      } else {
        // Relative import
        final fileDir = file.parent.path;
        absoluteResolvedPath = p.normalize(p.join(fileDir, importPath));
      }

      if (absoluteResolvedPath.isNotEmpty) {
        // Check if it matches any old duplicate
        final matchedOldPath = duplicates.keys.cast<String?>().firstWhere(
          (old) => p.equals(old!, absoluteResolvedPath),
          orElse: () => null,
        );

        if (matchedOldPath != null) {
          final newPath = duplicates[matchedOldPath]!;
          // Construct the new package import
          final newPackagePath =
              'package:oasis/${p.split(newPath).skip(1).join('/')}'; // skip 'lib'

          final newLine = line.replaceFirst(importPath, newPackagePath);
          newLines.add(newLine);
          fileModified = true;
          continue;
        }
      }

      newLines.add(line);
    }

    if (fileModified) {
      await file.writeAsString('${newLines.join('\n')}\n');
      updatedFilesCount++;
    }
  }

  print('Updated imports in $updatedFilesCount files.');

  // 4. Delete the old duplicated files
  int deletedCount = 0;
  for (final oldPath in duplicates.keys) {
    final f = File(oldPath);
    if (f.existsSync()) {
      await f.delete();
      deletedCount++;
    }
  }

  print('Deleted $deletedCount old duplicate files.');
}
