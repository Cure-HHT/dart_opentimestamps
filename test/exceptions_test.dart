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

import 'package:dart_opentimestamps/dart_opentimestamps.dart';
import 'package:test/test.dart';

void main() {
  group('OpenTimestampsException', () {
    test('stores message correctly', () {
      const exception = OpenTimestampsException('Test error message');
      expect(exception.message, equals('Test error message'));
    });

    test('toString includes class name and message', () {
      const exception = OpenTimestampsException('Something went wrong');
      expect(
        exception.toString(),
        equals('OpenTimestampsException: Something went wrong'),
      );
    });

    test('implements Exception interface', () {
      const exception = OpenTimestampsException('test');
      expect(exception, isA<Exception>());
    });
  });

  group('ProofParseException', () {
    test('stores message correctly', () {
      const exception = ProofParseException('Invalid proof format');
      expect(exception.message, equals('Invalid proof format'));
    });

    test('extends OpenTimestampsException', () {
      const exception = ProofParseException('test');
      expect(exception, isA<OpenTimestampsException>());
    });

    test('toString inherited from parent', () {
      const exception = ProofParseException('Parse failed');
      expect(exception.toString(), contains('Parse failed'));
    });
  });

  group('CalendarException', () {
    test('stores message correctly', () {
      const exception = CalendarException('Calendar server unavailable');
      expect(exception.message, equals('Calendar server unavailable'));
    });

    test('extends OpenTimestampsException', () {
      const exception = CalendarException('test');
      expect(exception, isA<OpenTimestampsException>());
    });
  });

  group('VerificationException', () {
    test('stores message correctly', () {
      const exception = VerificationException('Verification failed');
      expect(exception.message, equals('Verification failed'));
    });

    test('extends OpenTimestampsException', () {
      const exception = VerificationException('test');
      expect(exception, isA<OpenTimestampsException>());
    });
  });

  group('Exception throwing and catching', () {
    test('can catch as OpenTimestampsException', () {
      Exception? caught;
      try {
        throw const ProofParseException('test');
      } on OpenTimestampsException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught, isA<ProofParseException>());
    });

    test('can catch as generic Exception', () {
      Exception? caught;
      try {
        throw const CalendarException('calendar error');
      } on Exception catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
    });
  });
}
