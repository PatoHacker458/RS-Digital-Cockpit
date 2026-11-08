import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/garage_models.dart';
import '../providers/payment_garage_providers.dart';

/// Módulo "Renault Sport Digital Garage & Telemetry Pro" (15% de la Calificación):
/// 1) Tarjeta de crédito/débito interactiva con validación de Algoritmo de Luhn, MM/YY y CVV.
/// 2) Modelo de Prestación de Servicios (3 Planes de Suscripción: Clubman, Cup $99, Trophy $899).
/// 3) Modelo de Venta de Productos (E-Commerce de refacciones Clio 172 con carrito y orden en Firebase).
/// Cumplimiento estricto: Gestión 100% reactiva en Riverpod.
class DigitalGarageScreen extends ConsumerWidget {
  const DigitalGarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garageState = ref.watch(digitalGaragePaymentProvider);
    final garageNotifier = ref.read(digitalGaragePaymentProvider.notifier);
    final activeSkin = ref.watch(clusterSkinProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del Digital Garage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RENAULT SPORT DIGITAL GARAGE & TELEMETRY PRO',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 22,
                          color: primary,
                        ),
                      ),
                      const Text(
                        'Pasarela Stripe / RevenueCat • Validación Algoritmo de Luhn • Autorización Biométrica Pixel Tablet',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: RenaultSportPalette.oemShiftGreen.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: RenaultSportPalette.oemShiftGreen),
                    ),
                    child: Text(
                      'ACTIVO: ${garageState.activeSubscription.title.toUpperCase()}',
                      style: AppTheme.telemetryNumericStyle(
                        fontSize: 12,
                        color: RenaultSportPalette.oemShiftGreen,
                      ),
                    ),
                  ),
                ],
              ),

              if (garageState.paymentFeedback != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (garageState.isPaymentError
                            ? RenaultSportPalette.revLimiterRed
                            : RenaultSportPalette.oemShiftGreen)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: garageState.isPaymentError
                          ? RenaultSportPalette.revLimiterRed
                          : RenaultSportPalette.oemShiftGreen,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        garageState.isPaymentError
                            ? Icons.error_outline_rounded
                            : Icons.verified_rounded,
                        color: garageState.isPaymentError
                            ? RenaultSportPalette.revLimiterRed
                            : RenaultSportPalette.oemShiftGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          garageState.paymentFeedback!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // SECCIÓN 1: MODELO DE PRESTACIÓN DE SERVICIOS (3 PLANES DE SUSCRIPCIÓN)
              Text(
                '1. PLANES DE SUSCRIPCIÓN TELEMETRÍA SIRIUS 34 (SERVICIOS)',
                style: AppTheme.renaultSportHeaderStyle(fontSize: 16, color: primary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: RsSubscriptionTier.values.map((tier) {
                  final isCurrent = garageState.activeSubscription == tier;
                  return SizedBox(
                    width: 365,
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isCurrent
                              ? RenaultSportPalette.oemShiftGreen
                              : primary.withValues(alpha: 0.35),
                          width: isCurrent ? 2.2 : 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    tier.title,
                                    style: AppTheme.renaultSportHeaderStyle(
                                      fontSize: 17,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tier.priceLabel,
                                    style: AppTheme.telemetryNumericStyle(
                                      fontSize: 13,
                                      color: primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...tier.features.map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: RenaultSportPalette.oemShiftGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(f, style: const TextStyle(fontSize: 12.5)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isCurrent
                                    ? null
                                    : () => garageNotifier.subscribeToPlan(tier),
                                icon: Icon(
                                  isCurrent
                                      ? Icons.verified_rounded
                                      : Icons.fingerprint_rounded,
                                ),
                                label: Text(
                                  isCurrent
                                      ? 'PLAN ACTUALMENTE ACTIVO'
                                      : 'SUSCRIBIRSE CON HUELLA & TARJETA',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Selector de Skins Exclusivos (Clio V6 / Ragnotti Edition)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'SKINS DE INSTRUMENTOS (OTA GAUGE THEMES):',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 14,
                          color: RenaultSportPalette.siriusLiquidYellow,
                        ),
                      ),
                      ...ClusterSkinEdition.values.map((skin) {
                        final selected = skin == activeSkin;
                        return ChoiceChip(
                          label: Text(skin.label),
                          selected: selected,
                          onSelected: (_) =>
                              ref.read(clusterSkinProvider.notifier).selectSkin(skin),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // SECCIÓN 2: CAPTURA NATIVA DE TARJETA CON ALGORITMO DE LUHN + E-COMMERCE CLIO 172
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  // Columna Izquierda: Tarjeta Interactiva 3D + Formulario Luhn
                  SizedBox(
                    width: 480,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TARJETA BANCARIA (VALIDADOR LUHN)',
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 16,
                                    color: primary,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: garageNotifier.flipCardSide,
                                  icon: const Icon(Icons.flip_camera_android_rounded, size: 16),
                                  label: Text(
                                    garageState.showCardBackSide
                                        ? 'VER ANVERSO'
                                        : 'GIRAR REVERSO CVV',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Tarjeta Interactiva Animada (100% Riverpod Notifier)
                            GestureDetector(
                              onTap: garageNotifier.flipCardSide,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                height: 195,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: garageState.showCardBackSide
                                        ? const <Color>[
                                            Color(0xFF1E293B),
                                            Color(0xFF0F172A),
                                          ]
                                        : <Color>[
                                            const Color(0xFF181C24),
                                            primary.withValues(alpha: 0.85),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: garageState.isCardLuhnValid
                                        ? RenaultSportPalette.oemShiftGreen
                                        : RenaultSportPalette.revLimiterRed,
                                    width: 1.8,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: garageState.showCardBackSide
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            height: 36,
                                            color: Colors.black87,
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  height: 34,
                                                  color: Colors.white24,
                                                  alignment: Alignment.centerRight,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                                  child: Text(
                                                    'CVV ${garageState.cardCvv}',
                                                    style: AppTheme.telemetryNumericStyle(
                                                      fontSize: 16,
                                                      color: RenaultSportPalette
                                                          .siriusLiquidYellow,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'RENAULT SPORT TELEMETRY PRO SECURITY CHIP',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                LuhnCardValidator.detectCardBrand(
                                                  garageState.cardNumber,
                                                ),
                                                style: AppTheme.renaultSportHeaderStyle(
                                                  fontSize: 15,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: (garageState.isCardLuhnValid
                                                          ? RenaultSportPalette.oemShiftGreen
                                                          : RenaultSportPalette.revLimiterRed)
                                                      .withValues(alpha: 0.25),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  garageState.isCardLuhnValid
                                                      ? 'LUHN CHECK OK'
                                                      : 'LUHN INVÁLIDO',
                                                  style: AppTheme.telemetryNumericStyle(
                                                    fontSize: 10,
                                                    color: garageState.isCardLuhnValid
                                                        ? RenaultSportPalette.oemShiftGreen
                                                        : RenaultSportPalette.revLimiterRed,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            garageState.cardNumber.isEmpty
                                                ? '•••• •••• •••• ••••'
                                                : garageState.cardNumber,
                                            style: AppTheme.digitalDisplayStyle(
                                              fontSize: 19,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'TITULAR DEL CLIO RS',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.white60,
                                                    ),
                                                  ),
                                                  Text(
                                                    garageState.cardHolder,
                                                    style: AppTheme.telemetryNumericStyle(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  const Text(
                                                    'EXPIRA',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.white60,
                                                    ),
                                                  ),
                                                  Text(
                                                    garageState.cardExpiry,
                                                    style: AppTheme.telemetryNumericStyle(
                                                      fontSize: 13,
                                                      color: garageState.isExpiryValid
                                                          ? RenaultSportPalette
                                                              .siriusLiquidYellow
                                                          : RenaultSportPalette.revLimiterRed,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: garageState.cardNumber,
                              onChanged: garageNotifier.updateCardNumber,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Número de Tarjeta (16 dígitos con Algoritmo de Luhn)',
                                prefixIcon: const Icon(Icons.credit_card_rounded),
                                suffixIcon: Icon(
                                  garageState.isCardLuhnValid
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: garageState.isCardLuhnValid
                                      ? RenaultSportPalette.oemShiftGreen
                                      : RenaultSportPalette.revLimiterRed,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: garageState.cardHolder,
                              onChanged: garageNotifier.updateCardHolder,
                              decoration: const InputDecoration(
                                labelText: 'Nombre en la Tarjeta',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: garageState.cardExpiry,
                                    onChanged: garageNotifier.updateCardExpiry,
                                    decoration: InputDecoration(
                                      labelText: 'Expiración (MM/YY)',
                                      prefixIcon: const Icon(Icons.calendar_month_rounded),
                                      suffixIcon: Icon(
                                        garageState.isExpiryValid
                                            ? Icons.check_circle_outline
                                            : Icons.error_outline,
                                        size: 18,
                                        color: garageState.isExpiryValid
                                            ? RenaultSportPalette.oemShiftGreen
                                            : RenaultSportPalette.revLimiterRed,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: garageState.cardCvv,
                                    onChanged: garageNotifier.updateCardCvv,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'CVV (Gira tarjeta)',
                                      prefixIcon: const Icon(Icons.security_rounded),
                                      suffixIcon: Icon(
                                        garageState.isCvvValid
                                            ? Icons.check_circle_outline
                                            : Icons.error_outline,
                                        size: 18,
                                        color: garageState.isCvvValid
                                            ? RenaultSportPalette.oemShiftGreen
                                            : RenaultSportPalette.revLimiterRed,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Columna Derecha: Catálogo E-Commerce de Refacciones Clio 172 & Carrito
                  SizedBox(
                    width: 635,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '2. CATÁLOGO DE REFACCIONES OEM CLIO RS 172 (E-COMMERCE)',
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 16,
                                    color: primary,
                                  ),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.shopping_cart_rounded, size: 16),
                                  label: Text('${garageState.totalCartItems} items'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...kClio172PartsCatalog.map((part) {
                              final qty = garageState.cartQuantities[part.sku] ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: qty > 0
                                        ? primary
                                        : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            part.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Text(
                                            'OEM: ${part.oemPartNumber} • ${part.category}',
                                            style: AppTheme.telemetryNumericStyle(
                                              fontSize: 11,
                                              color: RenaultSportPalette.siriusLiquidYellow,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            part.technicalSpec,
                                            style: const TextStyle(fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${part.priceMxn.toStringAsFixed(0)} MXN',
                                          style: AppTheme.telemetryNumericStyle(
                                            fontSize: 14,
                                            color: primary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton.outlined(
                                              onPressed: qty > 0
                                                  ? () => garageNotifier
                                                      .removePartFromCart(part.sku)
                                                  : null,
                                              icon: const Icon(Icons.remove, size: 16),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                '$qty',
                                                style: AppTheme.telemetryNumericStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                            ),
                                            IconButton.filled(
                                              onPressed: () =>
                                                  garageNotifier.addPartToCart(part.sku),
                                              icon: const Icon(Icons.add, size: 16),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL DEL PEDIDO (IVA INCLUIDO):',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      '\$${garageState.cartSubtotalMxn.toStringAsFixed(2)} MXN',
                                      style: AppTheme.digitalDisplayStyle(
                                        fontSize: 22,
                                        color: RenaultSportPalette.oemShiftGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: garageState.isProcessingPayment
                                      ? null
                                      : garageNotifier.checkoutSparePartsCart,
                                  icon: const Icon(Icons.fingerprint_rounded),
                                  label: const Text(
                                    'PAGAR PEDIDO Y REGISTRAR EN FIREBASE',
                                  ),
                                ),
                              ],
                            ),

                            if (garageState.completedOrders.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'HISTORIAL DE ÓRDENES EN FIREBASE REALTIME DB:',
                                style: AppTheme.telemetryNumericStyle(
                                  fontSize: 11,
                                  color: primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...garageState.completedOrders.take(3).map(
                                    (ord) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: RenaultSportPalette.oemShiftGreen,
                                      ),
                                      title: Text(
                                        '${ord.orderId} — ${ord.description}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${ord.maskedCard} • ${ord.authMethod}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: Text(
                                        '\$${ord.totalAmountMxn.toStringAsFixed(2)} MXN',
                                        style: AppTheme.telemetryNumericStyle(
                                          fontSize: 12,
                                          color: RenaultSportPalette.oemShiftGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
