// Copyright 2025 Anspar Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:dart_opentimestamps/open_timestamps.dart';
import 'package:test/test.dart';

void main() {
  group('VerificationResult', () {
    test('success factory creates valid result', () {
      final attestedTime = DateTime(2024, 1, 15, 10, 30);
      final result = VerificationResult.success(
        attestedTime: attestedTime,
        bitcoinBlockHeight: 800000,
      );

      expect(result.isValid, isTrue);
      expect(result.attestedTime, equals(attestedTime));
      expect(result.bitcoinBlockHeight, equals(800000));
      expect(result.errors, isEmpty);
    });

    test('failure factory creates invalid result with errors', () {
      final errors = ['Invalid signature', 'Block not found'];
      final result = VerificationResult.failure(errors);

      expect(result.isValid, isFalse);
      expect(result.attestedTime, isNull);
      expect(result.bitcoinBlockHeight, isNull);
      expect(result.errors, equals(errors));
    });

    test('failure factory works with single error', () {
      final result = VerificationResult.failure(['Something went wrong']);

      expect(result.isValid, isFalse);
      expect(result.errors.length, equals(1));
      expect(result.errors.first, equals('Something went wrong'));
    });

    test('failure factory works with empty errors list', () {
      final result = VerificationResult.failure([]);

      expect(result.isValid, isFalse);
      expect(result.errors, isEmpty);
    });

    test('default constructor with all parameters', () {
      final attestedTime = DateTime.now();
      final result = VerificationResult(
        isValid: true,
        attestedTime: attestedTime,
        bitcoinBlockHeight: 123456,
        errors: ['warning'],
      );

      expect(result.isValid, isTrue);
      expect(result.attestedTime, equals(attestedTime));
      expect(result.bitcoinBlockHeight, equals(123456));
      expect(result.errors, equals(['warning']));
    });

    test('default constructor uses empty list for errors by default', () {
      const result = VerificationResult(isValid: false);

      expect(result.errors, isEmpty);
    });
  });
}
