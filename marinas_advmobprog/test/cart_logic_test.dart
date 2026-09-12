import 'package:flutter_test/flutter_test.dart';
import 'package:marinas_advmobprog/models/cart.dart';

void main() {
  test('discounted line total uses the product discount percentage', () {
    final product = CartProduct(
      id: 1,
      title: 'Test Product',
      price: 100,
      quantity: 1,
      total: 100,
      discountPercentage: 10,
      discountedTotal: 90,
      thumbnail: 'https://example.com/test.png',
    );

    expect(product.discountedLineTotal(1), 90.0);
    expect(product.discountedLineTotal(2), 180.0);
  });

  test('299.99 at 3 quantity with 7% discount totals 836.97', () {
    final product = CartProduct(
      id: 2,
      title: 'Example Price',
      price: 299.99,
      quantity: 3,
      total: 899.97,
      discountPercentage: 7,
      discountedTotal: 836.97,
      thumbnail: 'https://example.com/example.png',
    );

    expect(product.discountedLineTotal(3), closeTo(836.9721, 0.0001));
    expect(product.discountedLineTotal(3).toStringAsFixed(2), '836.97');
  });
}
