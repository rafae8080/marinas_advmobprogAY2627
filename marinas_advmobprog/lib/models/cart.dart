// Enhancement 1: model for the new /carts endpoint.

import 'product.dart';

class Cart {
  final int id;
  final List<CartProduct> products;
  final double total;
  final double discountedTotal;
  final int userId;
  final int totalProducts;
  final int totalQuantity;

  Cart({
    required this.id,
    required this.products,
    required this.total,
    required this.discountedTotal,
    required this.userId,
    required this.totalProducts,
    required this.totalQuantity,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'],
      products: (json['products'] as List? ?? [])
          .map((i) => CartProduct.fromJson(i))
          .toList(),
      total: (json['total'] as num).toDouble(),
      discountedTotal: (json['discountedTotal'] as num).toDouble(),
      userId: json['userId'],
      totalProducts: json['totalProducts'],
      totalQuantity: json['totalQuantity'],
    );
  }
}

// Enhancement 1: a cart line item is a trimmed-down product (no description,
// rating or images), which is why tapping one has to fetch the full product by
// id before the details screen can be shown.
class CartProduct {
  final int id;
  final String title;
  final double price;
  final int quantity;
  final double total;
  final double discountPercentage;
  final double discountedTotal;
  final String thumbnail;

  CartProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    required this.total,
    required this.discountPercentage,
    required this.discountedTotal,
    required this.thumbnail,
  });

  double discountedUnitPrice() {
    return price * (1 - (discountPercentage / 100));
  }

  double discountedLineTotal(int lineQuantity) {
    return discountedUnitPrice() * lineQuantity;
  }

  // Enhancement 4: bridge from a catalog Product to a cart line item, so the
  // cart can display the exact products added from the shop. Everything the
  // cart row draws is carried over; the fields the cart endpoint would have
  // sent are derived from the product price and discount.
  factory CartProduct.fromProduct(Product product, int quantity) {
    final discounted =
        product.price * quantity * (1 - (product.discountPercentage / 100));
    return CartProduct(
      id: product.id,
      title: product.title,
      price: product.price,
      quantity: quantity,
      total: product.price * quantity,
      discountPercentage: product.discountPercentage,
      discountedTotal: discounted,
      thumbnail: product.thumbnail,
    );
  }

  factory CartProduct.fromJson(Map<String, dynamic> json) {
    return CartProduct(
      id: json['id'],
      title: json['title'],
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'],
      total: (json['total'] as num).toDouble(),
      discountPercentage: (json['discountPercentage'] as num).toDouble(),
      // /carts returns 'discountedTotal' per item but /carts/add returns
      // 'discountedPrice', so both spellings are accepted.
      discountedTotal:
          ((json['discountedTotal'] ?? json['discountedPrice'] ?? 0) as num)
              .toDouble(),
      thumbnail: json['thumbnail'] ?? '',
    );
  }
}
