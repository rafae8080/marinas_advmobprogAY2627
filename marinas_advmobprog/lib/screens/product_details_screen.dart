// Enhancement 2: New file. Details page shown when a product card on the
// product screen is tapped. Layout follows the reference mockup: a rounded
// rectangle image panel at the top, then the title and description underneath.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// models
import '../models/product.dart';

// providers
import '../providers/cart_provider.dart';

// widgets
import '../widgets/custom_text.dart';

import '../constants.dart';

class ProductDetailsScreen extends StatelessWidget {
  // Enhancement 2: the tapped product is handed straight to this page, so no
  // second API call is needed to show the details.
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhancement 2: image panel. Stack lets the back button sit on top
            // of the image.
            Stack(
              children: [
                // Enhancement 2: semi-rounded rectangle holding the product
                // image, matching the mockup's top panel.
                ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: Container(
                    height: 380.h,
                    width: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Image.network(
                      product.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image, size: 48.sp),
                    ),
                  ),
                ),
                // Enhancement 2: floating back button over the image.
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  child: Material(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, size: 18.sp),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            // Enhancement 2: title, price and description block below the image.
            CustomText(
              text: product.title,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                CustomText(
                  text: '\$${product.price.toStringAsFixed(2)}',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(width: 12.w),
                Icon(Icons.star, size: 16.sp),
                SizedBox(width: 4.w),
                CustomText(text: '${product.rating}', fontSize: 13.sp),
              ],
            ),
            SizedBox(height: 16.h),
            CustomText(text: product.description, fontSize: 14.sp),
            SizedBox(height: 24.h),
            // Enhancement 4: adding used to POST straight to /carts/add, which
            // DummyJSON never persists, so the cart tab never changed. The
            // product now goes into the shared CartProvider, and the POST
            // happens once, on "Confirm Order".
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () {
                  // read, not watch: this is an event handler, so it must not
                  // subscribe to the provider.
                  context.read<CartProvider>().add(product);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${product.title} to cart')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentAmber,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: CustomText(
                  text: 'Add to Cart',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
