import 'package:flutter/material.dart';

class MorphTransition extends StatefulWidget {
  final Widget child;
  final bool isOpen;
  final Duration duration;
  final Curve curve;

  const MorphTransition({
    super.key,
    required this.child,
    required this.isOpen,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeInOutCubic,
  });

  @override
  State<MorphTransition> createState() => _MorphTransitionState();
}

class _MorphTransitionState extends State<MorphTransition> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<BorderRadius> _borderRadiusAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    
    _borderRadiusAnimation = Tween<BorderRadius>(
      begin: BorderRadius.circular(200),
      end: BorderRadius.circular(0),
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    if (widget.isOpen) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MorphTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: ClipRRect(
              borderRadius: _borderRadiusAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}