import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/api_config.dart';
import 'api_service.dart';

class ApiLauncher {
  ApiLauncher(this._apiService);

  final ApiService _apiService;
  Process? _apiProcess;

  Future<void> ensureRunning() async {
    final alive = await _apiService.healthCheck();
    if (alive) {
      return;
    }

    if (kDebugMode) {
      throw Exception(
        'Local API is not reachable at ${ApiConfig.baseUrl}. '
        'Start the FastAPI server in development mode.',
      );
    }

    final executablePath = await _resolveApiExecutablePath();
    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'app_store_reviews.db');
    final browserPath = p.join(supportDir.path, 'browsers');

    _apiProcess = await Process.start(
      executablePath,
      ['--db-path', dbPath],
      environment: {'PATCHRIGHT_BROWSERS_PATH': browserPath},
    );

    await _waitForHealth();
  }

  Future<void> _waitForHealth() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final alive = await _apiService.healthCheck();
        if (alive) {
          return;
        }
      } catch (_) {
        // Keep polling until timeout.
      }
    }
    throw Exception('API failed to start within timeout');
  }

  Future<String> _resolveApiExecutablePath() async {
    final appDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isWindows) {
      return p.join(
        appDir,
        'data',
        'flutter_assets',
        'assets',
        'api_server',
        'api_server.exe',
      );
    }
    if (Platform.isMacOS) {
      return p.normalize(
        p.join(appDir, '..', 'Resources', 'api_server', 'api_server'),
      );
    }
    return p.join(
      appDir,
      'data',
      'flutter_assets',
      'assets',
      'api_server',
      'api_server',
    );
  }

  void stop() {
    _apiProcess?.kill();
    _apiProcess = null;
  }
}
