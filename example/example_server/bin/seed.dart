import 'dart:io';
import 'package:example_client/example_client.dart';

/// Command-line script to inject sample Author and Article data into the development database.
///
/// Usage:
///   dart run bin/seed.dart
///   dart run bin/seed.dart --clear
void main(List<String> args) async {
  final clearExisting = args.contains('--clear');
  final serverUrl = Platform.environment['SERVERPOD_API_URL'] ?? 'http://localhost:8080/';

  stdout.writeln('🌱 Serverpod Data Seeder');
  stdout.writeln('Connecting to server at: $serverUrl');

  final client = Client(serverUrl);

  try {
    stdout.writeln(clearExisting ? 'Clearing and seeding fresh data...' : 'Seeding sample data...');

    final result = await client.seed.seedSampleData(clearExisting: clearExisting);

    stdout.writeln('\n✅ ${result.message}');
    stdout.writeln('   - Authors Created:  ${result.authorsCreated}');
    stdout.writeln('   - Articles Created: ${result.articlesCreated}');
    stdout.writeln('\nYou can now view this data in Serverpod DevTools (ER Schema & Live DB Inspector)!');
    exit(0);
  } catch (e) {
    stderr.writeln('\n❌ Failed to seed database: $e');
    stderr.writeln('\nEnsure your Serverpod server is running:');
    stderr.writeln('  cd example/example_server && dart run bin/main.dart');
    stderr.writeln('  (or: serverpod start)');
    exit(1);
  } finally {
    client.close();
  }
}
