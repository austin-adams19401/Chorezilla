import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    // Colors from Google’s outline spec
    const borderColor = Color(0xFFDADCE0); // light gray border
    const textColor = Colors.black87;

    final child = SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon / spinner on the left
          if (isLoading)
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Image.asset(
              'assets/icons/google_logo.png',
              width: 24,
              height: 24,
              filterQuality: FilterQuality.high,
            ),
          const SizedBox(width: 12),
          // Label — Flexible prevents overflow on narrow screens
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: .2,
              ),
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: StadiumBorder(
            side: const BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: isLoading ? null : onPressed,
            child: child,
          ),
        ),
      ),
    );
  }
}