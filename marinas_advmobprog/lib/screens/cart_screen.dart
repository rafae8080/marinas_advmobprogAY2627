// Enhancement 1: screen rendering the /carts endpoint. Each line item is
// tappable and opens the existing details screen.
// Enhancement 3: renders one user's cart via /carts/user/{id}, and confirming
// the order posts the current items to /carts/add.
// Enhancement 4: the cart no longer downloads a fixed server-side cart, which
// showed products unrelated to the shop grid. It now reads CartProvider, so it
// lists exactly the products added from the shop. /carts/add is still used, but
// only when the order is confirmed.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// models
import '../models/cart.dart';

// providers
import '../providers/cart_provider.dart';

// services
import '../services/cart_service.dart';

// widgets
import '../widgets/custom_text.dart';

import '../constants.dart';
import 'product_details_screen.dart';

const double _deliveryFee = 8.00;

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

// Enhancement 4: the quantity map, the Future and the keep-alive mixin are all
// gone. Cart state lives in CartProvider, above the PageView, so switching tabs
// can no longer discard it. The only state left here is the submit flag.
class _CartScreenState extends State<CartScreen> {
  bool _isSubmitting = false;

  Future<void> _confirmOrder(CartProvider cart) async {
    setState(() => _isSubmitting = true);
    try {
      final created = await CartService().addToCart(
        userId: kCartUserId,
        products: cart.toOrderPayload(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order confirmed — cart #${created.id}, '
            '${created.totalQuantity} items, '
            '\$${created.discountedTotal.toStringAsFixed(2)}',
          ),
        ),
      );
      cart.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: this screen must rebuild whenever the cart changes, including when
    // a product is added from the details screen opened off another tab.
    final cart = context.watch<CartProvider>();
    final items = cart.items;

    return Container(
      color: kScreenGrey,
      child: SafeArea(
        top: false,
        child: items.isEmpty
            ? Center(
                child: CustomText(text: 'Your cart is empty.', fontSize: 14.sp),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final product = items[index];
                        return _CartItemCard(
                          product: product,
                          quantity: product.quantity,
                          onIncrement: () => cart.changeQuantity(product.id, 1),
                          onDecrement: () =>
                              cart.changeQuantity(product.id, -1),
                        );
                      },
                    ),
                  ),
                  _CartSummary(
                    subtotal: cart.subtotal,
                    isSubmitting: _isSubmitting,
                    onConfirm: _isSubmitting ? null : () => _confirmOrder(cart),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartProduct product;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItemCard({
    required this.product,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.only(bottom: 10.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      // Enhancement 1: tapping a line item opens the details screen.
      // Enhancement 4: the full Product is already held by CartProvider, so the
      // details screen opens straight away — no GET /products/{id} round-trip
      // and no spinner in between.
      child: InkWell(
        onTap: () {
          final full = context.read<CartProvider>().productFor(product.id);
          if (full == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(product: full),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(10.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 64.w,
                height: 64.w,
                child: Image.network(
                  product.thumbnail,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image, size: 24.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: product.title,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: kAccentAmber,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${product.discountPercentage.round()}% off • '
                      '\$${product.discountedLineTotal(quantity).toStringAsFixed(2)} total',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                children: [
                  _QuantityButton(
                    icon: Icons.add,
                    background: kAccentAmber,
                    foreground: Colors.white,
                    onTap: onIncrement,
                  ),
                  SizedBox(height: 6.h),
                  CustomText(
                    text: '$quantity',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: 6.h),
                  _QuantityButton(
                    icon: Icons.remove,
                    background: const Color(0xFFE9E9EF),
                    foreground: Colors.black54,
                    onTap: onDecrement,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: onTap,
        child: SizedBox(
          width: 28.w,
          height: 28.w,
          child: Icon(icon, size: 16.sp, color: foreground),
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double subtotal;
  final bool isSubmitting;
  final VoidCallback? onConfirm;

  const _CartSummary({
    required this.subtotal,
    required this.isSubmitting,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal:', value: subtotal),
          SizedBox(height: 4.h),
          _SummaryRow(label: 'Delivery Fee:', value: _deliveryFee),
          SizedBox(height: 4.h),
          _SummaryRow(
            label: 'Total:',
            value: subtotal + _deliveryFee,
            bold: true,
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            // Enhancement 3: posts the current items to /carts/add.
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentAmber,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : CustomText(
                      text: 'Confirm Order',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            color: Colors.grey.shade600,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            color: kAccentAmber,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
