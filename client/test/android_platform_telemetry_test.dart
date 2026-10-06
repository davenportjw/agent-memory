import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/local_memory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.example.client/gemma_edge');

  group('Android OS Device Telemetry Integration', () {
    late LocalMemoryService memoryService;

    setUp(() {
      memoryService = LocalMemoryService();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('syncPlatformTelemetry dynamically hydrates real Android OS battery, network, and hardware engine', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getDeviceTelemetry') {
          return <String, dynamic>{
            'batteryLevel': 0.73,
            'isCharging': false,
            'networkStatus': 'ONLINE_CELLULAR',
            'hardwareEngine': 'Android Google Pixel 8 (tensor) LiteRT',
            'isLiteRTLoaded': true,
          };
        }
        return null;
      });

      expect(memoryService.isUsingPlatformTelemetry, isFalse);

      final success = await memoryService.syncPlatformTelemetry();
      expect(success, isTrue);
      expect(memoryService.isUsingPlatformTelemetry, isTrue);

      final env = memoryService.environmentalState;
      expect(env.batteryLevel, 0.73);
      expect(env.isCharging, isFalse);
      expect(env.networkStatus, 'ONLINE_CELLULAR');
      expect(env.hardwareEngine, 'Android Google Pixel 8 (tensor) LiteRT');

      // Boot state must also reflect the live environmental state
      expect(memoryService.bootState.environmentalState.batteryLevel, 0.73);
      expect(memoryService.bootState.environmentalState.hardwareEngine, 'Android Google Pixel 8 (tensor) LiteRT');

      // Verify telemetry sync log entry
      expect(memoryService.simulationLogs.first, contains('Synced live hardware vitals from Android OS'));
    });

    test('syncPlatformTelemetry gracefully handles platform channel failure without disrupting memory service', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(code: 'UNAVAILABLE', message: 'Not on Android');
      });

      final success = await memoryService.syncPlatformTelemetry();
      expect(success, isFalse);
      expect(memoryService.isUsingPlatformTelemetry, isFalse);
      expect(memoryService.environmentalState.batteryLevel, 0.88);
    });
  });
}
