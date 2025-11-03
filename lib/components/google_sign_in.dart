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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left icon
          Positioned(
            left: 60,
            child: isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Image.asset(
                    'assets/icons/google_logo.png',
                    width: 36,
                    height: 36,
                    filterQuality: FilterQuality.high,
                  ),
          ),
          // Centered label
          Text(
            text,
            style: const TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: .2,
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
