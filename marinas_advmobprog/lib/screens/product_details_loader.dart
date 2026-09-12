import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// models
import '../models/product.dart';

// services
import '../services/product_service.dart';

// widgets
import '../widgets/custom_text.dart';

import 'product_details_screen.dart';

class ProductDetailsLoader extends StatefulWidget {
  final int productId;

  const ProductDetailsLoader({super.key, required this.productId});

  @override
  State<ProductDetailsLoader> createState() => _ProductDetailsLoaderState();
}

class _ProductDetailsLoaderState extends State<ProductDetailsLoader> {
  late final Future<Product> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = ProductService().getProductById(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Product>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: CustomText(
                text: 'Error: ${snapshot.error}',
                fontSize: 14.sp,
              ),
            ),
          );
        }

        return ProductDetailsScreen(product: snapshot.data!);
      },
    );
  }
}
