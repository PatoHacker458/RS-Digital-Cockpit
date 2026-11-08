/// Nivel de Suscripción del Módulo "Renault Sport Digital Garage & Telemetry Pro"
enum RsSubscriptionTier {
  rsClubmanFree(
    id: 'rs_clubman_free',
    title: 'Plan 1: RS Clubman',
    priceLabel: 'GRATIS',
    amountMxn: 0.0,
    billingCycle: 'Permanente',
    features: <String>[
      'Telemetría básica K-Line (RPM 010C, Velocidad 010D, Temp 0105)',
      'Shift-Light inteligente frío/caliente (5,000 / 6,750 RPM)',
      'Simulador de Circuito Clio 172 integrado',
    ],
  ),
  rsCupMonthly(
    id: 'rs_cup_monthly_99',
    title: 'Plan 2: RS Cup Telemetry',
    priceLabel: '\$99 MXN / mes',
    amountMxn: 99.0,
    billingCycle: 'Mensual (RevenueCat / Stripe)',
    features: <String>[
      'Telemetría extendida Siemens Sirius 34 (MAP 010B, Avance 010E, Carga 0104)',
      'Grabación en tiempo real en Firebase ("Blackbox Live")',
      'Alertas térmicas y de correa de distribución vía FCM Push',
    ],
  ),
  rsTrophyAnnual(
    id: 'rs_trophy_pro_899',
    title: 'Plan 3: RS Trophy Pro',
    priceLabel: '\$899 MXN / año',
    amountMxn: 899.0,
    billingCycle: 'Anual (Ahorra 25%)',
    features: <String>[
      'Diagnóstico completo y borrado de códigos DTC (Modo 03 / Modo 04 Sirius 34)',
      'Cronómetro de vuelta GPS nativo y telemetría de fuerzas G',
      'Skins exclusivos desbloqueados: Clio V6 Phase 2 & Jean Ragnotti Edition',
      'Exportación completa de logs KWP2000',
    ],
  );

  final String id;
  final String title;
  final String priceLabel;
  final double amountMxn;
  final String billingCycle;
  final List<String> features;

  const RsSubscriptionTier({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.amountMxn,
    required this.billingCycle,
    required this.features,
  });
}

/// Producto de E-Commerce (Refacción / Accesorio original para Renault Clio II RS 172)
class Clio172SparePartProduct {
  final String sku;
  final String name;
  final String oemPartNumber;
  final String category;
  final String technicalSpec;
  final double priceMxn;

  const Clio172SparePartProduct({
    required this.sku,
    required this.name,
    required this.oemPartNumber,
    required this.category,
    required this.technicalSpec,
    required this.priceMxn,
  });
}

/// Orden procesada y registrada en Firebase Realtime Database
class GarageOrderReceipt {
  final String orderId;
  final String description;
  final double totalAmountMxn;
  final String maskedCard;
  final String authMethod;
  final DateTime createdAt;

  const GarageOrderReceipt({
    required this.orderId,
    required this.description,
    required this.totalAmountMxn,
    required this.maskedCard,
    required this.authMethod,
    required this.createdAt,
  });
}

/// Validador Determinista de Tarjetas Bancarias (Algoritmo de Luhn ISO/IEC 7812)
class LuhnCardValidator {
  const LuhnCardValidator._();

  /// Ejecuta el Algoritmo de Luhn sobre los dígitos de la tarjeta
  static bool isValidLuhn(String rawNumber) {
    final digitsOnly = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 13 || digitsOnly.length > 19) {
      return false;
    }

    var sum = 0;
    var alternate = false;
    for (var i = digitsOnly.length - 1; i >= 0; i--) {
      var n = int.parse(digitsOnly[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) {
          n = (n % 10) + 1;
        }
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10 == 0);
  }

  /// Valida formato MM/YY y que la tarjeta no esté vencida
  static bool isValidExpiry(String rawExpiry) {
    final clean = rawExpiry.trim();
    final regex = RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$');
    final match = regex.firstMatch(clean);
    if (match == null) return false;

    final month = int.parse(match.group(1)!);
    final year2 = int.parse(match.group(2)!);
    final fullYear = 2000 + year2;

    final now = DateTime.now();
    final expiryDate = DateTime(fullYear, month + 1, 0);
    return expiryDate.isAfter(now);
  }

  /// Valida CVV de 3 o 4 dígitos
  static bool isValidCvv(String rawCvv) {
    final clean = rawCvv.trim();
    return RegExp(r'^[0-9]{3,4}$').hasMatch(clean);
  }

  static String detectCardBrand(String rawNumber) {
    final digits = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('4')) return 'VISA RENAULT SPORT';
    if (digits.startsWith('5')) return 'MASTERCARD CUP';
    if (digits.startsWith('34') || digits.startsWith('37')) return 'AMEX TROPHY';
    return 'STRIPE / TARJETA BANCARIA';
  }
}

