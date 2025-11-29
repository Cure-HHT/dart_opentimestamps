/// Example: Create a timestamp with OpenTimestamps
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:open_timestamps/open_timestamps.dart';

Future<void> main() async {
  print('OpenTimestamps Example - Creating Timestamp\n');

  // Create test file
  final file = File('example_data.txt');
  if (!await file.exists()) {
    await file.writeAsString('Hello, OpenTimestamps!');
  }

  // Hash the file
  final data = await file.readAsBytes();
  final hash = sha256.convert(data).bytes;

  print('File: ${file.path}');
  print('SHA-256: ${_toHex(hash)}\n');

  try {
    // Create timestamp (currently unimplemented)
    final client = OpenTimestampsClient();
    final proof = await client.stamp(Uint8List.fromList(hash));

    // Save proof
    final proofFile = File('${file.path}.ots');
    await proofFile.writeAsBytes(proof);

    print('✓ Timestamp created!');
    print('  Proof: ${proofFile.path}');
    print('\nWait ~60 min for Bitcoin confirmation.');
  } on UnimplementedError {
    print('⚠ Implementation in progress!');
    print('  This is the project skeleton.');
  }
}

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
