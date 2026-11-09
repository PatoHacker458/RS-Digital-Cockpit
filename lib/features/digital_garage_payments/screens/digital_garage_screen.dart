import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/garage_models.dart';
import '../providers/payment_garage_providers.dart';

/// Apartado **GARAGE**:
/// Planes de suscripción, selector de carátulas del tacómetro, tarjeta bancaria
/// interactiva con validación Luhn y catálogo de refacciones OEM.
class DigitalGarageScreen extends ConsumerWidget {
  const DigitalGarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garageState = ref.watch(digitalGaragePaymentProvider);
    final garageNotifier = ref.read(digitalGaragePaymentProvider.notifier);
    final activeSkin = ref.watch(clusterSkinProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera limpia
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'RS DIGITAL GARAGE',
                    style: AppTheme.renaultSportHeaderStyle(
                      fontSize: 20,
                      color: primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          RenaultSportPalette.oemShiftGreen.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: RenaultSportPalette.oemShiftGreen),
                    ),
                    child: Text(
                      garageState.activeSubscription.title.toUpperCase(),
                      style: AppTheme.telemetryNumericStyle(
                        fontSize: 11.5,
                        color: RenaultSportPalette.oemShiftGreen,
                      ),
                    ),
                  ),
                ],
              ),

              if (garageState.paymentFeedback != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (garageState.isPaymentError
                            ? RenaultSportPalette.revLimiterRed
                            : RenaultSportPalette.oemShiftGreen)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
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
                        size: 20,
                        color: garageState.isPaymentError
                            ? RenaultSportPalette.revLimiterRed
                            : RenaultSportPalette.oemShiftGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          garageState.paymentFeedback!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 1. Planes de Suscripción Responsivos
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTabletWide = constraints.maxWidth >= 820;
                  final cardWidth = isTabletWide
                      ? (constraints.maxWidth - 28) / 3
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: RsSubscriptionTier.values.map((tier) {
                      final isCurrent = garageState.activeSubscription == tier;
                      return SizedBox(
                        width: cardWidth,
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isCurrent
                                  ? RenaultSportPalette.oemShiftGreen
                                  : primary.withValues(alpha: 0.35),
                              width: isCurrent ? 2.0 : 1.1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tier.title,
                                        style: AppTheme.renaultSportHeaderStyle(
                                          fontSize: 15.5,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tier.priceLabel,
                                        style: AppTheme.telemetryNumericStyle(
                                          fontSize: 12,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...tier.features.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 15,
                                          color:
                                              RenaultSportPalette.oemShiftGreen,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            f,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: isCurrent
                                        ? null
                                        : () => garageNotifier
                                            .subscribeToPlan(tier),
                                    icon: Icon(
                                      isCurrent
                                          ? Icons.verified_rounded
                                          : Icons.fingerprint_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isCurrent ? 'PLAN ACTIVO' : 'ACTIVAR PLAN',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Selector de Carátula (Skin) del Tacómetro
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'ESTILO DE TACÓMETRO:',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 13.5,
                          color: RenaultSportPalette.siriusLiquidYellow,
                        ),
                      ),
                      ...ClusterSkinEdition.values.map((skin) {
                        final selected = skin == activeSkin;
                        return ChoiceChip(
                          label: Text(
                            skin.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selected,
                          onSelected: (_) => ref
                              .read(clusterSkinProvider.notifier)
                              .selectSkin(skin),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Tarjeta Bancaria (Luhn) + Catálogo de Refacciones Responsivo
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 820;

                  final paymentCardSection = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'MÉTODO DE PAGO',
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 15,
                                    color: primary,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: garageNotifier.flipCardSide,
                                icon: const Icon(
                                  Icons.flip_camera_android_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  garageState.showCardBackSide
                                      ? 'VER FRENTE'
                                      : 'VER CVV',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Tarjeta Interactiva Animada
                          GestureDetector(
                            onTap: garageNotifier.flipCardSide,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              height: 175,
                              padding: const EdgeInsets.all(18),
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
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: garageState.isCardLuhnValid
                                      ? RenaultSportPalette.oemShiftGreen
                                      : RenaultSportPalette.revLimiterRed,
                                  width: 1.6,
                                ),
                              ),
                              child: garageState.showCardBackSide
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          height: 32,
                                          color: Colors.black87,
                                        ),
                                        const SizedBox(height: 14),
                                        Container(
                                          height: 32,
                                          color: Colors.white24,
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'CVV ${garageState.cardCvv}',
                                            style:
                                                AppTheme.telemetryNumericStyle(
                                              fontSize: 15,
                                              color: RenaultSportPalette
                                                  .siriusLiquidYellow,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                LuhnCardValidator
                                                    .detectCardBrand(
                                                  garageState.cardNumber,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTheme
                                                    .renaultSportHeaderStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: (garageState
                                                            .isCardLuhnValid
                                                        ? RenaultSportPalette
                                                            .oemShiftGreen
                                                        : RenaultSportPalette
                                                            .revLimiterRed)
                                                    .withValues(alpha: 0.25),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                garageState.isCardLuhnValid
                                                    ? 'VÁLIDA'
                                                    : 'INVÁLIDA',
                                                style: AppTheme
                                                    .telemetryNumericStyle(
                                                  fontSize: 10,
                                                  color: garageState
                                                          .isCardLuhnValid
                                                      ? RenaultSportPalette
                                                          .oemShiftGreen
                                                      : RenaultSportPalette
                                                          .revLimiterRed,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            garageState.cardNumber.isEmpty
                                                ? '•••• •••• •••• ••••'
                                                : garageState.cardNumber,
                                            style:
                                                AppTheme.digitalDisplayStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                garageState.cardHolder,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTheme
                                                    .telemetryNumericStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              garageState.cardExpiry,
                                              style: AppTheme
                                                  .telemetryNumericStyle(
                                                fontSize: 12,
                                                color: garageState.isExpiryValid
                                                    ? RenaultSportPalette
                                                        .siriusLiquidYellow
                                                    : RenaultSportPalette
                                                        .revLimiterRed,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 14),
                          TextFormField(
                            initialValue: garageState.cardNumber,
                            onChanged: garageNotifier.updateCardNumber,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Número de tarjeta',
                              prefixIcon:
                                  const Icon(Icons.credit_card_rounded),
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
                          const SizedBox(height: 10),
                          TextFormField(
                            initialValue: garageState.cardHolder,
                            onChanged: garageNotifier.updateCardHolder,
                            decoration: const InputDecoration(
                              labelText: 'Titular',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: garageState.cardExpiry,
                                  onChanged: garageNotifier.updateCardExpiry,
                                  decoration: const InputDecoration(
                                    labelText: 'MM/YY',
                                    prefixIcon:
                                        Icon(Icons.calendar_month_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: garageState.cardCvv,
                                  onChanged: garageNotifier.updateCardCvv,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'CVV',
                                    prefixIcon: Icon(Icons.security_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

                  final catalogSection = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'REFACCIONES OEM CLIO RS',
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 15,
                                    color: primary,
                                  ),
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(
                                  Icons.shopping_cart_rounded,
                                  size: 15,
                                ),
                                label: Text('${garageState.totalCartItems}'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...kClio172PartsCatalog.map((part) {
                            final qty =
                                garageState.cartQuantities[part.sku] ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(10),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          part.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          part.oemPartNumber,
                                          style: AppTheme.telemetryNumericStyle(
                                            fontSize: 10.5,
                                            color: RenaultSportPalette
                                                .siriusLiquidYellow,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${part.priceMxn.toStringAsFixed(0)}',
                                        style: AppTheme.telemetryNumericStyle(
                                          fontSize: 13.5,
                                          color: primary,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: qty > 0
                                                ? () => garageNotifier
                                                    .removePartFromCart(
                                                      part.sku,
                                                    )
                                                : null,
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 18,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Text(
                                            '$qty',
                                            style:
                                                AppTheme.telemetryNumericStyle(
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => garageNotifier
                                                .addPartToCart(part.sku),
                                            icon: Icon(
                                              Icons.add_circle_rounded,
                                              size: 18,
                                              color: primary,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(fontSize: 10.5),
                                  ),
                                  Text(
                                    '\$${garageState.cartSubtotalMxn.toStringAsFixed(2)} MXN',
                                    style: AppTheme.digitalDisplayStyle(
                                      fontSize: 19,
                                      color: RenaultSportPalette.oemShiftGreen,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: garageState.isProcessingPayment
                                    ? null
                                    : garageNotifier.checkoutSparePartsCart,
                                icon: const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 18,
                                ),
                                label: const Text('PAGAR PEDIDO'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: paymentCardSection),
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: catalogSection),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      paymentCardSection,
                      const SizedBox(height: 14),
                      catalogSection,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
