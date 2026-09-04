import 'package:flutter/material.dart';

import '../models/product.dart';
import 'product_card.dart';

class ResponsiveProductGrid extends StatelessWidget {
  const ResponsiveProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
    this.controller,
  });

  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final spacing = constraints.maxWidth < 420 ? 10.0 : 14.0;
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final extent = _extentFor(cellWidth);

        return GridView.builder(
          controller: controller,
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: extent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onTap: () => onProductTap(product),
            );
          },
        );
      },
    );
  }
}

int _columnsFor(double width) {
  if (width >= 980) {
    return 4;
  }
  if (width >= 660) {
    return 3;
  }
  return 2;
}

double _extentFor(double cellWidth) {
  if (cellWidth < 156) {
    return 312;
  }
  if (cellWidth < 190) {
    return 322;
  }
  if (cellWidth < 240) {
    return 332;
  }
  return 342;
}
