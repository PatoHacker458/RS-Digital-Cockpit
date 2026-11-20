import 'package:flutter/material.dart';

/// Wrapper limpio (las alertas HUD ahora se entregan exclusivamente como
/// notificaciones nativas del sistema Android sin duplicar un banner interno en la app).
class HudNotificationWrapper extends StatelessWidget {
  final Widget child;

  const HudNotificationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
