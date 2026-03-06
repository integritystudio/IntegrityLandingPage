import 'package:flutter/material.dart';

/// Reusable hover-enabled text link with Semantics support.
///
/// Used in footer links and navigation links. Handles hover state,
/// cursor, Semantics annotations, and tap callbacks.
class HoverTextLink extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final Color defaultColor;
  final Color hoverColor;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const HoverTextLink({
    super.key,
    required this.text,
    this.onTap,
    required this.defaultColor,
    required this.hoverColor,
    this.style,
    this.padding,
  });

  @override
  State<HoverTextLink> createState() => _HoverTextLinkState();
}

class _HoverTextLinkState extends State<HoverTextLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget child = Text(
      widget.text,
      style: (widget.style ?? const TextStyle()).copyWith(
        color: _isHovered ? widget.hoverColor : widget.defaultColor,
      ),
    );

    if (widget.padding != null) {
      child = Padding(padding: widget.padding!, child: child);
    }

    return Semantics(
      button: true,
      label: widget.text,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: child,
        ),
      ),
    );
  }
}
