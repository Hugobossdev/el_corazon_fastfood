import 'package:flutter/material.dart';
import 'app_spacing.dart';

class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final bool safeArea;
  final EdgeInsetsGeometry padding;

  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.drawer,
    this.safeArea = true,
    this.padding = AppSpacing.pagePadding,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: body,
    );

    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      body: safeArea ? SafeArea(child: content) : content,
    );
  }
}


