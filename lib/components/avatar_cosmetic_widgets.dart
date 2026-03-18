// lib/components/avatar_cosmetic_widgets.dart
//
// Shared avatar + frame rendering widgets used by both profile_header.dart
// and kids_home_page.dart.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chorezilla/models/member.dart';
import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/cosmetics.dart';

// ---------------------------------------------------------------------------
// AvatarWithFrame — composite: CircleAvatar + optional frame overlay
// ---------------------------------------------------------------------------

class AvatarWithFrame extends StatelessWidget {
  const AvatarWithFrame({
    super.key,
    required this.member,
    required this.radius,
  });

  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final avatarKey = (member.avatarKey ?? '').trim();
    final frameId = member.equippedAvatarFrameId;

    final circle = CircleAvatar(
      radius: radius,
      backgroundColor: member.role == FamilyRole.child
          ? cs.primaryContainer
          : cs.secondaryContainer,
      child: buildAvatarContent(avatarKey, radius * 0.95, _initials(member.displayName)),
    );

    if (frameId == null || frameId == 'frame_default') return circle;

    return Stack(
      alignment: Alignment.center,
      children: [
        circle,
        FrameOverlay(frameId: frameId, radius: radius),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final a = parts.first.characters.first.toUpperCase();
    final b = parts.last.characters.first.toUpperCase();
    return '$a$b';
  }
}

// ---------------------------------------------------------------------------
// buildAvatarContent — shared helper for rendering emoji or image avatar keys
// ---------------------------------------------------------------------------

/// Returns a widget for [avatarKey]:
/// - If it starts with 'avatar_', looks up the asset in CosmeticCatalog and
///   renders an Image.asset (clipped to circle via the parent CircleAvatar).
/// - Otherwise renders the key as an emoji Text.
/// [fallback] is shown when [avatarKey] is empty (e.g. initials).
Widget buildAvatarContent(String avatarKey, double size, String fallback) {
  if (avatarKey.startsWith('avatar_')) {
    final item = CosmeticCatalog.byId(avatarKey);
    if (item.assetKey.isNotEmpty) {
      return Image.asset(
        item.assetKey,
        width: size * 2,
        height: size * 2,
        fit: BoxFit.cover,
      );
    }
  }
  final display = avatarKey.isNotEmpty ? avatarKey : fallback;
  return Text(
    display,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
  );
}

// ---------------------------------------------------------------------------
// FrameOverlay — dispatches to the appropriate frame widget by frameId
// ---------------------------------------------------------------------------

class FrameOverlay extends StatelessWidget {
  const FrameOverlay({super.key, required this.frameId, required this.radius});

  final String frameId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    switch (frameId) {
      case 'frame_green_basic':
        return DoubleBorderFrame(
          radius: radius,
          outerColor: const Color(0xFF2ECC71),
          innerColor: const Color(0xFF27AE60),
        );
      case 'frame_stars':
        return StarFrame(radius: radius, color: Colors.amber);
      case 'frame_rainbow':
        return GradientBorderFrame(
          radius: radius,
          colors: const [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
          ],
        );
      case 'frame_gold':
        return DoubleBorderFrame(
          radius: radius,
          outerColor: const Color(0xFFFFD700),
          innerColor: const Color(0xFFFFA000),
        );
      case 'frame_fire':
        return StarFrame(
          radius: radius,
          color: Colors.deepOrange,
          icon: Icons.local_fire_department,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// StarFrame — ring of evenly-spaced icons (used for stars and fire)
// ---------------------------------------------------------------------------

class StarFrame extends StatelessWidget {
  const StarFrame({
    super.key,
    required this.radius,
    required this.color,
    this.icon = Icons.star,
  });

  final double radius;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const int count = 8;
    // Ring border sits just outside the avatar circle
    final double ringRadius = radius + 3;
    // Icons are placed just beyond the avatar edge, not scaled by a multiplier
    final double iconRadius = radius + 2;
    return SizedBox(
      width: ringRadius * 2,
      height: ringRadius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: ringRadius * 2,
            height: ringRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            ),
          ),
          ...List.generate(count, (i) {
            final angle = (i * 2 * math.pi) / count - math.pi / 2;
            final dx = iconRadius * math.cos(angle);
            final dy = iconRadius * math.sin(angle);
            return Transform.translate(
              offset: Offset(dx, dy),
              child: Icon(icon, size: 10, color: color),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GradientBorderFrame — sweep-gradient ring (rainbow)
// ---------------------------------------------------------------------------

class GradientBorderFrame extends StatelessWidget {
  const GradientBorderFrame({
    super.key,
    required this.radius,
    required this.colors,
  });

  final double radius;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final double size = (radius + 4) * 2;
    return CustomPaint(
      size: Size(size, size),
      painter: GradientRingPainter(colors: colors, strokeWidth: 3),
    );
  }
}

class GradientRingPainter extends CustomPainter {
  const GradientRingPainter({
    required this.colors,
    required this.strokeWidth,
  });

  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - strokeWidth / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(GradientRingPainter old) => false;
}

// ---------------------------------------------------------------------------
// DoubleBorderFrame — concentric double ring (gold)
// ---------------------------------------------------------------------------

class DoubleBorderFrame extends StatelessWidget {
  const DoubleBorderFrame({
    super.key,
    required this.radius,
    required this.outerColor,
    required this.innerColor,
  });

  final double radius;
  final Color outerColor;
  final Color innerColor;

  @override
  Widget build(BuildContext context) {
    final double outer = (radius + 5) * 2;
    final double inner = (radius + 1) * 2;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: outerColor, width: 2.5),
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: innerColor, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
