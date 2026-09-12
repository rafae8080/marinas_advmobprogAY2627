import 'package:flutter/foundation.dart';

// models
import '../models/cart.dart';
import '../models/product.dart';

class CartProvider with ChangeNotifier {
  // The full Product is kept, not just a summary, so tapping a cart row can open
  // the details screen without re-fetching the product by id.
  final Map<int, Product> _products = {};
  final Map<int, int> _quantities = {};

  bool get isEmpty => _products.isEmpty;

  int get totalQuantity =>
      _quantities.values.fold(0, (sum, quantity) => sum + quantity);

  // CartProduct is immutable, so each line is rebuilt from the product and its
  // current quantity rather than being edited in place.
  List<CartProduct> get items => _products.values
      .map(
        (product) =>
            CartProduct.fromProduct(product, _quantities[product.id] ?? 1),
      )
      .toList(growable: false);

  Product? productFor(int id) => _products[id];

  double get subtotal {
    var subtotal = 0.0;
    for (final item in items) {
      subtotal += item.discountedLineTotal(item.quantity);
    }
    return subtotal;
  }

  void add(Product product, {int quantity = 1}) {
    _products[product.id] = product;
    final current = _quantities[product.id] ?? 0;
    _quantities[product.id] = (current + quantity).clamp(1, 99);
    notifyListeners();
  }

  void changeQuantity(int productId, int delta) {
    final current = _quantities[productId];
    if (current == null) return;

    final next = current + delta;
    if (next <= 0) {
      remove(productId);
      return;
    }

    _quantities[productId] = next.clamp(1, 99);
    notifyListeners();
  }

  void remove(int productId) {
    _products.remove(productId);
    _quantities.remove(productId);
    notifyListeners();
  }

  void clear() {
    _products.clear();
    _quantities.clear();
    notifyListeners();
  }

  // Shape POST /carts/add expects: one {id, quantity} pair per line.
  Map<int, int> toOrderPayload() => Map<int, int>.from(_quantities);
}
