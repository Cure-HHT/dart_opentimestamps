/// OpenTimestamps Dart implementation
/// 
/// Provides blockchain timestamping using the OpenTimestamps protocol.
library open_timestamps;

// Core types
export 'src/core/attestation.dart';
export 'src/core/operations.dart';
export 'src/core/timestamp.dart';

// Main API
export 'src/client/opentimestamps_client.dart';
export 'src/detached_timestamp_file.dart';

// Verification
export 'src/verification/verification_result.dart';

// Utilities
export 'src/utils/exceptions.dart';
