// Enhancement 1: service for the new /carts endpoint, following the same
// shape as ProductService.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/cart.dart';

class CartService {
  // Enhancement 5: limit=0 asks DummyJSON for every cart rather than the
  // default first 30, which the shop grid needs to build its catalog.
  Future<List<Cart>> getAllCarts({int limit = 0}) async {
    final response = await http.get(Uri.parse('$host/carts?limit=$limit'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List cartsJson = data['carts'] ?? [];
      return cartsJson.map((json) => Cart.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load carts');
    }
  }

  // Enhancement 5: the shop grid is now stocked from the carts endpoint
  // instead of /products. Every cart is flattened into one product list and
  // deduplicated by id, keeping the order they were first seen in so cart #1's
  // items (Blue Frock and friends) lead the grid.
  Future<List<CartProduct>> getCartProducts() async {
    final carts = await getAllCarts();
    final unique = <int, CartProduct>{};
    for (final cart in carts) {
      for (final product in cart.products) {
        unique.putIfAbsent(product.id, () => product);
      }
    }
    return unique.values.toList(growable: false);
  }

  Future<Cart> getCartById(int id) async {
    final response = await http.get(Uri.parse('$host/carts/$id'));
    if (response.statusCode == 200) {
      return Cart.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load cart $id');
    }
  }

  // Enhancement 3: /carts/user/{id} returns every cart belonging to one user,
  // still wrapped in a "carts" envelope. The screen renders a single cart, so
  // the first one is returned.
  Future<Cart> getCartByUserId(int userId) async {
    final response = await http.get(Uri.parse('$host/carts/user/$userId'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List cartsJson = data['carts'] ?? [];
      if (cartsJson.isEmpty) {
        throw Exception('User $userId has no cart');
      }
      return Cart.fromJson(cartsJson.first);
    } else {
      throw Exception('Failed to load cart for user $userId');
    }
  }

  // Enhancement 3: POST /carts/add takes a user id and a list of
  // {id, quantity} pairs, and responds with the newly created cart.
  Future<Cart> addToCart({
    required int userId,
    required Map<int, int> products,
  }) async {
    final response = await http.post(
      Uri.parse('$host/carts/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'products': products.entries
            .map((entry) => {'id': entry.key, 'quantity': entry.value})
            .toList(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Cart.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add to cart');
    }
  }
}
