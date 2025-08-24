import 'package:flutter/material.dart';

class PageTransitionSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final bool reverse;
  final Widget Function(Widget, Animation<double>) transitionBuilder;

  const PageTransitionSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.reverse = false,
    required this.transitionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return transitionBuilder(child, animation);
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: child,
    );
  }
}