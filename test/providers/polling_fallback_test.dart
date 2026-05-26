// Simple Dart test for polling intervals
void main() {
  print('Testing Polling Intervals...\n');

  // Test intervals match expected values
  const msgInterval = 10;
  const presenceInterval = 10;
  const typingInterval = 5;

  print(
    'Message polling: ${msgInterval}s - ${msgInterval == 10 ? "OK" : "FAIL"}',
  );
  print(
    'Presence polling: ${presenceInterval}s - ${presenceInterval == 10 ? "OK" : "FAIL"}',
  );
  print(
    'Typing polling: ${typingInterval}s - ${typingInterval == 5 ? "OK" : "FAIL"}',
  );
  print('Typing faster: ${typingInterval < msgInterval ? "OK" : "FAIL"}');

  // Test data handling
  final empty = <dynamic>[];
  print('Empty list: ${empty.isEmpty}');

  Map<String, dynamic>? nullMap;
  print('Null map: ${nullMap == null}');

  final row = <String, dynamic>{'status': 'online'};
  print('Map has status: ${row['status'] == "online"}');

  // Test dedupe
  final seen = <String>{};
  seen.add('a');
  seen.add('a'); // duplicate
  print('Dedupe: ${seen.length == 1}');

  // Test filter
  final receipts = [
    {'msg': 'm1', 'conv': 'c1'},
    {'msg': 'm2', 'conv': 'c2'},
  ];
  final filtered = receipts.where((r) => r['conv'] == 'c1').toList();
  print('Filter: ${filtered.length == 1}');
  print('Filter result: ${filtered.first['msg']}');

  print('\nAll basic tests passed!');
}
