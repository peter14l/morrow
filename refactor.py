import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'showModalBottomSheet' not in content:
        return False

    # Match showModalBottomSheet(context: context, and replace with context.showResponsiveSheet(
    # Also handles material.showModalBottomSheet and generic type parameters
    pattern = r'(?:material\.)?showModalBottomSheet(?:<[^>]+>)?\s*\(\s*context:\s*(?:this\.)?context,'
    new_content = re.sub(pattern, 'context.showResponsiveSheet(', content)

    if new_content != content:
        if 'showResponsiveSheet' in new_content and 'context_extensions.dart' not in new_content:
            new_content = "import 'package:oasis/core/extensions/context_extensions.dart';\n" + new_content
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

def main():
    modified = 0
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart') and file != 'context_extensions.dart':
                filepath = os.path.join(root, file)
                try:
                    if process_file(filepath):
                        modified += 1
                except Exception as e:
                    pass
    print(f'Modified {modified} files.')

if __name__ == '__main__':
    main()
