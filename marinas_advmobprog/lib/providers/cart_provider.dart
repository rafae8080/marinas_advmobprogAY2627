import 'package:flutter/foundation.dart';

// models
import '../models/cart.dart';
import '../models/product.dart';

// services
import '../services/cart_service.dart';

class CartProvider with ChangeNotifier {
  // The full Product is kept, not just a summary, so tapping a cart row can open
  // the details screen without re-fetching the product by id.
  final Map<int, Product> _products = {};
  final Map<int, int> _quantities = {};

  // Act4 Enhancement 3: lines seeded from /carts/user/{id}. The carts endpoint
  // sends summaries, not full products, so these are kept apart from
  // _products — a row backed by one of these has to fetch the product before it
  // can open the details screen.
  final Map<int, CartProduct> _serverLines = {};

  int? _userId;
  bool _isLoading = false;
  String? _error;

  int? get userId => _userId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isEmpty => _quantities.isEmpty;

  int get totalQuantity =>
      _quantities.values.fold(0, (sum, quantity) => sum + quantity);

  // CartProduct is immutable, so each line is rebuilt from the product and its
  // current quantity rather than being edited in place.
  // Act4 Enhancement 3: a line comes from the full product when one is held,
  // and from the server summary otherwise.
  List<CartProduct> get items => _quantities.entries
      .map((entry) {
        final product = _products[entry.key];
        if (product != null) {
          return CartProduct.fromProduct(product, entry.value);
        }
        return _serverLines[entry.key]?.withQuantity(entry.value);
      })
      .whereType<CartProduct>()
      .toList(growable: false);

  Product? productFor(int id) => _products[id];

  double get subtotal {
    var subtotal = 0.0;
    for (final item in items) {
      subtotal += item.discountedLineTotal(item.quantity);
    }
    return subtotal;
  }

  // Act4 Enhancement 3: called once the signed-in user is known, from the
  // splash screen on auto-login and from the sign-in screen after a successful
  // login. A user with no cart on the server is not an error — it just means
  // the cart starts empty.
  Future<void> loadForUser(int userId) async {
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cart = await CartService().getCartByUserId(userId);
      _products.clear();
      _quantities.clear();
      _serverLines.clear();
      for (final line in cart.products) {
        _serverLines[line.id] = line;
        _quantities[line.id] = line.quantity;
      }
    } catch (error) {
      _error = '$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    _serverLines.remove(productId);
    _quantities.remove(productId);
    notifyListeners();
  }

  void clear() {
    _products.clear();
    _serverLines.clear();
    _quantities.clear();
    notifyListeners();
  }

  // Act4 Enhancement 3: logout has to drop the user id too, so the next
  // person to sign in does not inherit the previous one's cart.
  void reset() {
    _userId = null;
    _error = null;
    clear();
  }

  // Shape POST /carts/add expects: one {id, quantity} pair per line.
  Map<int, int> toOrderPayload() => Map<int, int>.from(_quantities);
}
