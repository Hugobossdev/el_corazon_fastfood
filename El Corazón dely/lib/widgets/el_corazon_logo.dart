import 'package:flutter/material.dart';

class ElCorazonLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;
  final bool animated;

  const ElCorazonLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.color,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? Theme.of(context).colorScheme.primary;

    final Widget logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo image
        Image.asset(
          'assets/logo/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size * 0.7,
              decoration: BoxDecoration(
                color: logoColor,
                borderRadius: BorderRadius.circular(size * 0.2),
              ),
              child: Center(
                child: Icon(
                  Icons.delivery_dining,
                  size: size * 0.4,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        if (showText) ...[
          SizedBox(height: size * 0.15),
          // Texte du logo
          Text(
            'EL CORAZON DELY',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: logoColor,
              letterSpacing: 2,
              fontFamily: 'Montserrat',
            ),
          ),
          SizedBox(height: size * 0.05),
          Text(
            'L\'AMOUR, NOTRE INGRÉDIENT SECRET',
            style: TextStyle(
              fontSize: size * 0.1,
              color: logoColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (animated) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: logo,
            ),
          );
        },
      );
    }

    return logo;
  }
}
