import 'package:flutter_test/flutter_test.dart';
import 'package:clio_rs_172_cockpit_telemetry_hub/features/auth_profile/models/pilot_profile.dart';
import 'package:clio_rs_172_cockpit_telemetry_hub/features/digital_garage_payments/models/garage_models.dart';
import 'package:clio_rs_172_cockpit_telemetry_hub/features/telemetry/models/obd_telemetry_frame.dart';
import 'package:clio_rs_172_cockpit_telemetry_hub/features/telemetry/services/elm327_service.dart';

void main() {
  group('1. Parser OBD-II KWP2000 (ECU Siemens Sirius 34 - F4R 736)', () {
    test('Decodifica RPM (PID 010C), Velocidad (010D), TPS (0111) y Temp (0105)', () {
      // 410C 6978 -> ((105 * 256) + 120) / 4 = 6750.0 RPM (Shift-Light Verde OEM)
      expect(Sirius34KwpParser.parseRpm('410C6978'), equals(6750.0));

      // 410D B4 -> 180 km/h
      expect(Sirius34KwpParser.parseSpeedKmh('410DB4'), equals(180));

      // 4111 FF -> 100.0 % (WOT - Mariposa totalmente abierta)
      expect(Sirius34KwpParser.parseThrottleTps('4111FF'), closeTo(100.0, 0.01));

      // 4105 82 -> 130 - 40 = 90.0 °C (Temperatura operativa F4R)
      expect(Sirius34KwpParser.parseTemperatureC('410582', '4105'), equals(90.0));
    });

    test('Fidelidad Mecánica Shift-Light: Motor Frío (<75°C) vs Caliente (>=75°C)', () {
      final coldFrame = ObdTelemetryFrame.initial().copyWith(
        coolantTempC: 68.0,
        rpm: 5100.0,
      );
      expect(coldFrame.isEngineCold, isTrue);
      expect(coldFrame.shiftLightStage, equals(ShiftLightStage.coldProtectionWarning));

      final warmGreenShiftFrame = ObdTelemetryFrame.initial().copyWith(
        coolantTempC: 89.0,
        rpm: 6850.0,
      );
      expect(warmGreenShiftFrame.isEngineCold, isFalse);
      expect(warmGreenShiftFrame.shiftLightStage, equals(ShiftLightStage.optimalGreenShift));

      final fuelCutFrame = warmGreenShiftFrame.copyWith(rpm: 7260.0);
      expect(fuelCutFrame.shiftLightStage, equals(ShiftLightStage.fuelCutLimiterFlash));
    });
  });

  group('2. Reglas de Seguridad Firebase Auth & Edición de Avatar', () {
    test('Habilita edición de avatar SOLO para proveedor password y bloquea Google/GitHub', () {
      final emailPilot = PilotProfile(
        uid: 'u1',
        email: 'piloto@renaultsport.fr',
        displayName: 'Piloto Email',
        chassisNumber: 'VF1CB1N0F31040172',
        avatarUrl: 'https://example.com/a.jpg',
        emailVerified: false,
        providerIds: const <String>['password'],
        lastSyncedAt: DateTime.now(),
      );

      expect(emailPilot.canEditAvatar, isTrue);
      expect(emailPilot.requiresEmailVerificationGate, isTrue);

      final googlePilot = emailPilot.copyWith(
        providerIds: const <String>['google.com'],
        emailVerified: true,
      );
      expect(googlePilot.canEditAvatar, isFalse);

      final githubPilot = emailPilot.copyWith(
        providerIds: const <String>['github.com'],
        emailVerified: true,
      );
      expect(githubPilot.canEditAvatar, isFalse);
    });
  });

  group('3. Pasarela de Pagos: Validación con Algoritmo de Luhn', () {
    test('Verifica tarjetas válidas e inválidas según checksum Luhn mod 10', () {
      expect(LuhnCardValidator.isValidLuhn('4532 0151 1283 0366'), isTrue);
      expect(LuhnCardValidator.isValidLuhn('4532 0151 1283 0367'), isFalse);
      expect(LuhnCardValidator.isValidExpiry('08/29'), isTrue);
      expect(LuhnCardValidator.isValidCvv('172'), isTrue);
    });
  });
}

