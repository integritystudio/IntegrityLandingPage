/// Custom X (formerly Twitter) logo icon widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// X logo icon widget that matches Flutter's Icon API.
///
/// Uses the official X logo SVG asset.
class XIcon extends StatelessWidget {
  const XIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  /// The size of the icon in logical pixels.
  final double size;

  /// The color to use when drawing the icon.
  ///
  /// Defaults to the current [IconTheme] color if not specified.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.black;

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/icons/x_logo.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    );
  }
}
