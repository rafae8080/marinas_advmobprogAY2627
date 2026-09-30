# What Changed — A Beginner's Walkthrough

This file explains, in plain language, what was added to the app and how each
piece works. It is split by lab activity, newest last:

- **[Part 1 — Activity 3](#part-1--activity-3-the-cart-the-shop-grid-and-the-chat-button)** — the cart, the shop grid and the floating chat button.
- **[Part 2 — Activity 4](#part-2--activity-4-authentication-the-profile-and-the-users-cart)** — signing in, staying signed in, and the profile.

---

# Part 1 — Activity 3: the cart, the shop grid and the chat button

This part covers **where the items on screen come from** and **how the floating
chat button disappears**.

---

## 1. The short version

| File | What happened |
|---|---|
| `lib/models/cart.dart` | **New.** Describes what a cart and a cart item *are*. |
| `lib/services/cart_service.dart` | **New.** Talks to the cart API. Added `getCartProducts()`, which stocks the shop grid. |
| `lib/screens/product_screen.dart` | The shop grid is now filled from `/carts`, not `/products`. |
| `lib/screens/product_details_loader.dart` | **New.** Fetches a full product by id before showing the details page. |
| `lib/screens/cart_screen.dart` | **New.** The screen you see in the mockup. Now reads the cart from `CartProvider` instead of downloading one. |
| `lib/providers/cart_provider.dart` | **New.** Holds the cart you build by tapping "Add to Cart". |
| `lib/screens/home_screen.dart` | Bottom bar is now Shop / Cart / Profile. Chat became a floating button. |
| `lib/services/product_service.dart` | Added `getProductById()`. |
| `lib/screens/product_details_screen.dart` | Added an "Add to Cart" button, which now puts the product in `CartProvider`. |
| `lib/constants.dart` | Added the app's colors and the cart's user id. |
| `lib/providers/theme_provider.dart` | Navy app bar, amber buttons, white nav bar. |
| `lib/main.dart` | Fixed a bug where the app could start up showing nothing. Registers `CartProvider` alongside `ThemeProvider`. |

Two files were deliberately **not** created — the Chat page and the Profile page are small private widgets at the bottom of `home_screen.dart` instead.

---

## 2. Where the items come from

### The shop grid: `/carts`, not `/products`

The Shop tab used to list `https://dummyjson.com/products` — the 30-item
catalog. It now lists the products that actually appear in the **carts**
endpoint, so Blue Frock, Generic Motorcycle, iPhone 6 and the rest are what you
see on the home screen.

`CartService.getCartProducts()` does the work:

```dart
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
```

Three things are going on:

1. **`getAllCarts()` now asks for everything.** `GET /carts` returns only the
   first 30 carts by default, so the method gained a `limit` parameter that
   defaults to `0` — DummyJSON's way of saying "no limit". That is 208 carts.
2. **Every cart is flattened into one list.** Carts are a list of lists; the
   shop needs a single list of products.
3. **`putIfAbsent` deduplicates.** The same product shows up in many different
   carts. Keeping only the first sighting turns 208 carts into **189 unique
   products** — and because cart #1 is first in the response, its items lead the
   grid.

#### One consequence: the tiles are `CartProduct`s

A cart line item is a trimmed-down product. It has a title, price, discount and
thumbnail — everything a grid tile draws — but **no description, rating or image
gallery**, because the carts endpoint never sends those.

That is fine for the grid, and it is why two smaller things changed:

- The search bar used to match on title, brand *or* category. Cart items have no
  brand or category, so it matches on **title** alone now.
- Tapping a tile can no longer hand a product straight to the details page.

#### Tapping a tile: `ProductDetailsLoader`

`lib/screens/product_details_loader.dart` is a small widget that does one job —
fetch, wait, then show:

```
tap tile  ->  ProductDetailsLoader(productId: 162)
          ->  ProductService().getProductById(162)   ->  GET /products/162
          ->  spinner while waiting
          ->  ProductDetailsScreen(product: ...)
```

`ProductDetailsScreen` itself did not change. It still takes a full `Product`,
still shows the description and rating, and its "Add to Cart" button still puts
a complete product into `CartProvider` — which is why the Cart tab below works
exactly as it did.

---

### The cart: it used to come from the wrong place

The cart screen originally downloaded a ready-made cart from

```
https://dummyjson.com/carts/user/1
```

That worked, but it made for a strange app: the Shop tab listed the catalog,
while the Cart tab listed a completely different set of things the server had
decided you owned. Adding a product did nothing visible, because "Add to Cart"
sent a `POST /carts/add` that DummyJSON only *pretends* to save.

So the cart now holds **the products you actually added**, and it starts empty.

### The new source of truth: `CartProvider`

`lib/providers/cart_provider.dart` is a `ChangeNotifier` — the same pattern
`ThemeProvider` already uses. It keeps two small lookup tables:

```dart
final Map<int, Product> _products = {};   // product id -> the whole product
final Map<int, int> _quantities = {};     // product id -> how many
```

Storing the *whole* `Product`, not just a summary, is what lets a cart row open
the details page instantly — the app already has everything that page needs.

It is registered once, above `MaterialApp`, in `lib/main.dart`:

```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
  ],
  ...
);
```

Being above `MaterialApp` matters: the Shop tab, the Cart tab and any pushed
route all see the **same one instance**.

### The round trip, in three steps

```
ProductScreen  --tap-->  ProductDetailsScreen
                              |
                              | context.read<CartProvider>().add(product)
                              v
                        CartProvider   <-- one shared object
                              |
                              | context.watch<CartProvider>()
                              v
                         CartScreen (rebuilds itself)
```

#### Step 1 — Adding

In `product_details_screen.dart`:

```dart
onPressed: () {
  context.read<CartProvider>().add(product);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Added ${product.title} to cart')),
  );
},
```

`read`, not `watch`. Inside a button handler you want to *use* the provider, not
subscribe to it — a button does not need to rebuild when the cart changes.

Inside `add()`, an id that is already in the cart just gets its quantity bumped,
which is why tapping "Add to Cart" twice gives you one row showing `2` rather
than two identical rows.

#### Step 2 — Notifying

Every method that changes the cart ends the same way:

```dart
void add(Product product, {int quantity = 1}) {
  _products[product.id] = product;
  final current = _quantities[product.id] ?? 0;
  _quantities[product.id] = (current + quantity).clamp(1, 99);
  notifyListeners();          // <- the broadcast
}
```

`notifyListeners()` is the announcement: *"I changed — anyone watching should
redraw."*

#### Step 3 — Displaying

In `cart_screen.dart`:

```dart
final cart = context.watch<CartProvider>();
final items = cart.items;
```

`watch` both reads the cart **and** subscribes. When `notifyListeners()` fires —
even from a details page opened off a different tab — this screen rebuilds.

Notice what is gone compared to before: no `FutureBuilder`, no `initState`, no
`_cartFuture`. There is nothing to download, so there is no loading state and no
error state to handle here.

### Turning a Product into a cart row

The cart row widget (`_CartItemCard`) was written to draw a `CartProduct`, and it
still does. The bridge is one new factory in `lib/models/cart.dart`:

```dart
factory CartProduct.fromProduct(Product product, int quantity) { ... }
```

`CartProduct` is **immutable** — every field is `final` — so a quantity change
cannot edit a row in place. Instead `CartProvider.items` rebuilds the list from
the products and the current quantities each time it is read:

```dart
List<CartProduct> get items => _products.values
    .map((product) => CartProduct.fromProduct(product, _quantities[product.id] ?? 1))
    .toList(growable: false);
```

This is why the row widget itself needed no changes at all.

### Where each thing on screen comes from

| What you see | Where it comes from |
|---|---|
| Product picture | `product.thumbnail`, carried over from the catalog product |
| Title | `product.title` |
| The amber price | `product.price` |
| "12% off" | `product.discountPercentage.round()` |
| "... total" | `CartProduct.discountedLineTotal(quantity)` |
| The quantity number | `CartProvider._quantities[id]` |
| Subtotal | `CartProvider.subtotal` — added up in the app, never downloaded |

### The `+` and `-` buttons

They call one method:

```dart
void changeQuantity(int productId, int delta) {
  final current = _quantities[productId];
  if (current == null) return;

  final next = current + delta;
  if (next <= 0) {
    remove(productId);        // dropping to zero removes the row entirely
    return;
  }

  _quantities[productId] = next.clamp(1, 99);
  notifyListeners();
}
```

`.clamp(1, 99)` keeps the number in a sane range, and hitting `-` on a quantity
of 1 removes the item instead of leaving a useless zero row.

### Tapping an item opens the details page

This used to need a network call. A cart item downloaded from `/carts` carried
only a *summary* — title, price, thumbnail — with no description or rating, so
the app had to fetch `GET /products/{id}` and show a spinner before it could open
`ProductDetailsScreen`.

Now the provider is already holding the full product, so the tap is instant:

```dart
final full = context.read<CartProvider>().productFor(product.id);
if (full == null) return;
Navigator.push(context, MaterialPageRoute(
  builder: (context) => ProductDetailsScreen(product: full),
));
```

The little `_ProductDetailsLoader` helper widget that did the fetching is gone.

### Sending data the other way (Confirm Order)

Everything above happens on the phone. `POST /carts/add` is the one place data
still goes *out*, and it now runs only when you tap **Confirm Order**:

```dart
final created = await CartService().addToCart(
  userId: kCartUserId,
  products: cart.toOrderPayload(),   // {productId: quantity, ...}
);
...
cart.clear();
```

`toOrderPayload()` hands over the `{id: quantity}` map, `CartService` turns it
into JSON, and the server replies with a freshly created cart. The SnackBar shows
its id and total, and the local cart is emptied — the order has been placed.

> **Heads up:** DummyJSON is a practice API. It *simulates* the order and returns
> a realistic cart, but nothing is stored on the server. That is exactly why the
> cart itself is kept in the app now.

---

## 3. How the floating chat button disappears

### What changed

The bottom bar used to be **Shop / Chat / Profile**. It's now **Shop / Cart / Profile**, and Chat moved out into a `FloatingActionButton` — the round button hovering above the bottom bar.

### The one variable that controls everything

`HomeScreen` remembers which tab you're on in a single number:

```dart
int selectedIndex = 0;
```

- `0` = Shop
- `1` = Cart
- `2` = Profile

To make the code readable, the cart's number gets a name:

```dart
static const int _cartIndex = 1;
```

Tapping a tab updates that number and redraws the screen:

```dart
onTap: (int value) {
  setState(() {
    selectedIndex = value;
    pageController.jumpToPage(value);
  });
},
```

### The actual disappearing act

```dart
floatingActionButton: selectedIndex == _cartIndex
    ? null
    : FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const _ChatPage()),
        ),
        child: Icon(Icons.chat, size: 24.sp),
      ),
```

Read it as a sentence: *"If the selected tab is the cart, the floating action button is `null`; otherwise it's a chat button."*

`? :` is Dart's **ternary operator** — a compact `if/else` that produces a value:

```dart
condition ? valueIfTrue : valueIfFalse
```

`null` means *"there is nothing here."* `Scaffold` is built to accept `null` for its `floatingActionButton` — that's the normal way to say "this screen has no floating button." So no button is drawn at all.

### Why this works automatically

This is the part that's genuinely different from other programming you may have done. You never write "hide the button" anywhere. Instead:

1. You tap the Cart tab.
2. `setState` runs, setting `selectedIndex = 1`.
3. `setState` tells Flutter the screen is out of date.
4. Flutter calls `build()` again from the top.
5. `build()` re-reads the line above. `1 == 1` is now true, so it returns `null`.
6. Flutter compares the new description to the old one, notices the button is gone, and removes it.

This is called **declarative UI**: you describe what the screen *should look like* for the current state, and Flutter works out the changes. You never give step-by-step instructions like "hide this, then show that."

The app bar title works the same way, in the same `build()`:

```dart
title: selectedIndex == 0
    ? Image.asset('assets/images/exchange_logo.png', scale: 11.3)
    : CustomText(text: selectedIndex == _cartIndex ? 'Cart' : 'Profile'),
```

Logo on Shop, the word "Cart" on Cart, "Profile" on Profile — one variable driving three different parts of the screen.

---

## 4. The bug that made the app show nothing

Worth understanding, because it's a classic.

The bottom bar had **three** tabs, but the `PageView` holding the actual pages had only **one** page in it:

```dart
// before
children: [ProductScreen()],
```

So tapping Chat or Profile ran `pageController.jumpToPage(1)` — asking to scroll to a page that didn't exist. `PageView` didn't crash and didn't complain. It just showed empty space. A blank screen with no error message is much harder to debug than a crash.

The fix is simply having as many pages as tabs:

```dart
// after
children: const [ProductScreen(), CartScreen(), _ProfilePage()],
```

There was a second, more subtle version of the same problem in `main.dart`:

```dart
// before
SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) async {
  await dotenv.load(fileName: 'assets/.env');
  runApp(const MarinasAdvMobProg());
});
```

`runApp()` is the line that actually starts the app. Here it was hidden *inside* `.then(...)`, meaning it only runs if locking the orientation succeeds first. On platforms that don't support orientation locking (Windows, some browsers), that step fails silently — and `runApp()` never runs. The app starts, draws nothing, and prints no error.

```dart
// after
await dotenv.load(fileName: 'assets/.env');
runApp(const MarinasAdvMobProg());
SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
```

Now the app always starts, and the orientation lock is just a nice-to-have afterwards.

**The lesson:** never put `runApp()` inside a callback that might not fire.

---

## 5. One more detail: the cart no longer needs keeping alive

The cart screen used to carry this:

```dart
class _CartScreenState extends State<CartScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
```

`PageView` throws away pages you are not looking at, so without the mixin the
cart would re-download itself and forget your quantity edits every time you left
the tab.

That is no longer a problem, and the mixin has been removed. The cart data lives
in `CartProvider`, which sits **above** the `PageView` in the widget tree —
nothing `PageView` discards can take it along. Flutter is free to throw the page
away and rebuild it; it will read the same cart back out of the provider.

This is a general lesson about state: *where* state lives decides what can
destroy it.

---

## 6. Things to try

- Look at the Shop tab. **Blue Frock** should be one of the first tiles, followed
  by Generic Motorcycle, iPhone 6 and Baseball Ball — cart #1's items.
- Type `frock` in the search bar. Searching by brand or category no longer works,
  because cart items do not carry those fields.
- Open the **Cart** tab before adding anything. It should say "Your cart is empty."
- Add a product from the Shop, then switch to Cart. The item you picked — same
  picture, title and price — is the one listed there.
- Add the *same* product again. You get one row at quantity 2, not two rows.
- Tap `-` until the quantity hits zero. The row disappears; empty the cart and the
  "Your cart is empty." message comes back.
- Switch tabs back and forth. Your cart survives, with no re-download and no spinner.
- Tap a cart item. The details page opens immediately, because the full product was
  already in memory.
- Tap **Confirm Order** and read the cart id in the SnackBar, then watch the cart
  empty itself.
- Turn off your wifi and tap **Confirm Order**. You get the error message from
  `cart_service.dart` in a SnackBar — the cart itself keeps working offline,
  because it never needed the network.


## 7. Known leftovers

> Three of these were dealt with in Activity 4 — see
> [its leftovers section](#7-known-leftovers-after-activity-4) for what is still open.

- `test/widget_test.dart` is still the default Flutter counter test. It refers to a class called `StateManagementApp` that doesn't exist in this project, so `flutter analyze` reports one error from it. It's unrelated to any of the work above.
- The navy app bar is set in `theme_provider.dart`, so it applies to **every** screen, not just the cart.
- Dark mode still uses plain `ThemeData.dark()` and doesn't have the navy/amber styling.
- `CartService.getCartById()` and `getCartByUserId()` are no longer called by any screen. They are left in place as the GET-endpoint work from the earlier enhancements. Everything else in the two services is in use: `getAllCarts()` and `getCartProducts()` stock the shop, `getProductById()` backs the details loader, and `addToCart()` posts the order.
- `ProductService.getAllProducts()` — the original `/products` call — is unused now that the shop reads `/carts`.
- The shop grid downloads all 208 carts in one request to build its 189-product list. Fine for a lab app; a real one would page the grid.

---

# Part 2 — Activity 4: authentication, the profile and the user's cart

Activity 3 left the app with a shop, a cart and an empty Profile tab. Activity 4
adds the missing piece: **the app now knows who you are.** You sign in once, and
it remembers you the next time you open it.

Three enhancements were asked for, and each one is a screen:

| # | Enhancement | Screen |
|---|---|---|
| 1 | UI for the splash screen, implementing persistent authentication | `splash_screen.dart` |
| 2 | UI for the sign-in screen, using `user_service` and the login logic | `signin_screen.dart` |
| 3 | A `user.dart` model rendered on the profile, and the cart fetched by `userId` | `user.dart` + `profile_screen.dart` |

---

## 1. The short version

| File | What happened |
|---|---|
| `lib/models/user.dart` | **New.** Describes what a signed-in user *is*. |
| `lib/services/user_service.dart` | **New.** Logs in, saves the user to the phone, reads it back, logs out. |
| `lib/screens/splash_screen.dart` | **New.** The first screen. Decides whether you still need to sign in. |
| `lib/screens/signin_screen.dart` | **New.** The login form. |
| `lib/screens/profile_screen.dart` | **New.** The real Profile tab, replacing the placeholder. |
| `lib/providers/cart_provider.dart` | Gained `loadForUser()`, so the cart belongs to whoever signed in. |
| `lib/models/cart.dart` | Added `CartProduct.withQuantity()`. |
| `lib/screens/cart_screen.dart` | Posts the order under the **real** user id. Empty state now tells loading / failed / empty apart. |
| `lib/screens/home_screen.dart` | The `_ProfilePage` placeholder is gone; the tab shows `ProfileScreen`. |
| `lib/widgets/custom_text.dart` | Gained an optional `color`. |
| `lib/main.dart` | Starts at `/splash`. Added the `/splash` and `/signin` routes. |
| `pubspec.yaml` | Added `shared_preferences`. |
| `test/widget_test.dart` | **Deleted.** It was the default counter test and had never compiled. |

Comments for this activity are labelled `// Act4 Enhancement N:` so they cannot
be confused with Activity 3's `// Enhancement 1-5:`.

---

## 2. Enhancement 1 — the splash screen, and what "persistent" means

### The problem it solves

Before this activity the app opened straight onto the Shop tab. It had no idea
who you were, and there was nothing to remember.

**Persistent authentication** means: you log in once, and the app still knows you
after you close it completely and open it again. The word *persistent* is doing
the work — the login has to survive the app being killed.

### Where the login is kept

On the phone itself, in **SharedPreferences** — a tiny key-value store that lives
in the app's own storage and survives restarts. `UserService.saveUserData()`
writes each field into it:

```dart
await prefs.setInt('id', user.id);
await prefs.setString('username', user.username);
await prefs.setString('accessToken', user.accessToken);
// ... and the rest
```

Reading it back is the mirror image, in `getUserData()`.

### The one question the splash screen asks

```dart
Future<bool> isLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken') ?? prefs.getString('token');
  return token != null && token.isNotEmpty;
}
```

*"Is there a token saved from last time?"* That is the whole test. If yes, you
were signed in before and still are.

### What the splash screen does with the answer

```
SplashScreen
   |
   | await _userService.isLoggedIn()
   |
   +-- true  --> load the saved user --> fetch their cart --> /home
   |
   +-- false --> /signin
```

In code, `_checkAuthentication()`:

```dart
final loggedIn = await _userService.isLoggedIn();
if (!mounted) return;

if (loggedIn) {
  final userData = await _userService.getUserData();
  // ...
  Navigator.pushReplacementNamed(context, '/home', arguments: userData);
} else {
  Navigator.pushReplacementNamed(context, '/signin');
}
```

Two details worth noticing:

- **`pushReplacementNamed`, not `pushNamed`.** *Replace* throws the splash screen
  away instead of stacking the next screen on top of it. Without this, pressing
  back from the home screen would return you to a splash screen that immediately
  re-navigates — a loop.
- **`if (!mounted) return;` after every `await`.** `mounted` means "this widget is
  still on screen." An `await` can finish after the user has already left, and
  using `context` on a dead widget crashes. Every `await` in this project is
  followed by that guard.

### The UI

- A navy gradient background with the logo on a white rounded card.
- A fade-and-rise entrance, driven by an `AnimationController` (`vsync: this`,
  which is what `SingleTickerProviderStateMixin` provides).
- An amber spinner.
- **A live status line**, which is the part that makes the invisible work
  visible:

```
"Starting up..."  ->  "Checking your session..."  ->  "Welcome back, Emily!"
                                                \->  "Please sign in to continue"
```

That line is just a `String` field redrawn by `setState`, wrapped in an
`AnimatedSwitcher` so it cross-fades instead of snapping.

---

## 3. Enhancement 2 — the sign-in screen

### The journey of a username and password

```
you type              SigninScreen
                          |
                          | UserService().loginUser(username, password)
                          v
                     POST https://dummyjson.com/auth/login
                          |
                          | 200 + {accessToken, id, username, email, ...}
                          v
                     saveUserData()  --> SharedPreferences
                          |
                          v
                     /home
```

The screen never touches `http`, and never sees a URL — exactly the same layering
rule the product screens follow.

### The form

`Form` + a `GlobalKey<FormState>` is Flutter's standard validation pair:

```dart
if (_formKey.currentState!.validate()) { ... }
```

`validate()` runs every field's `validator` and returns `true` only if all of them
returned `null`. Failing validators draw their message under the field
automatically.

### Three things that are easy to get wrong

**1. Where the spinner starts.** The obvious order is wrong:

```dart
// wrong
setState(() => _isLoading = true);
if (_formKey.currentState!.validate()) { ... }
```

If validation fails, nothing else runs — and `_isLoading` is never set back to
`false`. The button spins forever. So the flag is set *inside* the passing
branch:

```dart
// right
if (_formKey.currentState!.validate()) {
  setState(() => _isLoading = true);
  ...
}
```

**2. Whitespace.** A phone keyboard's autocorrect loves to add a trailing space,
and DummyJSON rejects `"emilys "` with a `400 Invalid credentials` — the same
error as a wrong password, which makes it maddening to debug. Hence:

```dart
_usernameController.text.trim(),
_passwordController.text.trim(),
```

plus `autocorrect: false` and `textCapitalization: TextCapitalization.none` on
the username field.

**3. Showing the failure.** The service throws the raw response body, which is
JSON:

```
Exception: {"message":"Invalid credentials"}
```

That is fine for a log, not for a person. `_readableError()` pulls the `message`
out and the screen shows it in a red banner *inside the card*, which stays put —
a SnackBar disappears after a few seconds, often before you have read it.

### There is no sign-up button, on purpose

DummyJSON has no registration endpoint. Only its 208 canned accounts
authenticate, and every password is the username with `pass` on the end:

| Username | Password |
|---|---|
| `emilys` | `emilyspass` |
| `michaelw` | `michaelwpass` |
| `sophiab` | `sophiabpass` |

That is why the card ends with a small grey hint giving the demo account — it
saves the next person a very confusing five minutes.

### The UI

A navy gradient header carrying the logo and "Welcome back", with the white form
card pulled up over it by `Transform.translate`. Fields are filled and
borderless until focused, each with a leading icon; the password field has a
show/hide eye. Pressing enter in the password field submits.

---

## 4. Enhancement 3a — the `User` model and the profile screen

### The model

`lib/models/user.dart` is the same shape as `Product` and `Cart`: every field
`final`, one `fromJson` factory. What makes it slightly different is that it is
built from **two different sources**:

1. the `/auth/login` response, straight off the network;
2. the map `UserService.getUserData()` rebuilds out of SharedPreferences.

Both use the same key names, so one factory covers both — the only requirement is
that every field has a default:

```dart
factory User.fromJson(Map<String, dynamic> json) {
  return User(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    // ...
  );
}
```

The `?? ''` is not decoration. Without it, a field missing from storage would be
`null`, and the profile would have to null-check everything it draws.

### Why the profile does not hit the network

```dart
Future<User> getUser() async {
  final userData = await getUserData();   // reads SharedPreferences
  return User.fromJson(userData);
}
```

Everything the profile shows was already saved at login. So the Profile tab
renders with **no HTTP request at all**, works with the wifi off, and appears
instantly.

The screen consumes it with a `FutureBuilder<User>` — the same four-state pattern
(`waiting` / `hasError` / empty / success) the shop grid uses. The `Future` is
created once in `initState`, not in `build`, so it is not re-read from disk on
every rebuild.

### The UI

A navy gradient header with an amber-ringed `CircleAvatar` (falling back to a
person icon when `image` is empty), the full name, the `@username`, then a white
card of icon-labelled rows — User ID, first name, last name, email, gender — and
a red outlined **Log out** button.

### Logging out

```dart
context.read<CartProvider>().reset();   // drop the cart first
await _userService.logout();            // then clear SharedPreferences
Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
```

Three deliberate choices:

- It asks for confirmation first, in an `AlertDialog`.
- The **cart is reset before the token is cleared**, so the next person to sign in
  cannot briefly see the previous user's items.
- `pushNamedAndRemoveUntil` with `(route) => false` wipes the whole navigation
  stack. After logging out there is no back button to sneak into the app with.

`logout()` itself is one line — `prefs.clear()` — and because `isLoggedIn()` only
looks for a token, clearing storage is what makes the next launch land on the
sign-in screen.

---

## 5. Enhancement 3b — the cart now belongs to the signed-in user

### What changed

Activity 3 hard-coded the cart's owner:

```dart
const int kCartUserId = 1;   // constants.dart
```

Everyone's order was posted as user 1. Now the cart is **fetched** for whoever
signed in, and posted back under that same id.

### The seeding step

`CartProvider` gained one method:

```dart
Future<void> loadForUser(int userId) async {
  _userId = userId;
  _isLoading = true;
  notifyListeners();
  try {
    final cart = await CartService().getCartByUserId(userId);   // GET /carts/user/{id}
    // ... fill the cart from cart.products
  } catch (error) {
    _error = '$error';
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

It is called from **both** doors into the app, because there are two ways to
arrive signed in:

| Where | When |
|---|---|
| `signin_screen.dart` | right after a successful login, using `response['id']` |
| `splash_screen.dart` | on auto-login, using the saved `userData['id']` |

`CartService.getCartByUserId()` already existed — it was written in Activity 3 and
then left unused when the cart became local. Activity 4 is what finally calls it.

### The snag: a cart line is not a product

`/carts/user/{id}` sends **summaries** — title, price, discount, thumbnail — with
no description, rating or image gallery. But `CartProvider` was built to hold
whole `Product` objects, because that is what lets a cart row open the details
page instantly.

Rather than force one to become the other, the provider now keeps both:

```dart
final Map<int, Product> _products = {};        // added from the shop
final Map<int, CartProduct> _serverLines = {}; // seeded from /carts/user/{id}
final Map<int, int> _quantities = {};          // quantity, for either kind
```

and `items` builds each row from whichever one it has:

```dart
List<CartProduct> get items => _quantities.entries
    .map((entry) {
      final product = _products[entry.key];
      if (product != null) return CartProduct.fromProduct(product, entry.value);
      return _serverLines[entry.key]?.withQuantity(entry.value);
    })
    .whereType<CartProduct>()
    .toList(growable: false);
```

`CartProduct.withQuantity()` is new, and it exists for the same reason
`fromProduct` did: `CartProduct` is immutable, so pressing `+` cannot edit a row —
it has to build a new one.

Tapping a row follows the same fork. A product added from the shop opens
instantly; a server-seeded line has to fetch itself first, so it falls back to
`ProductDetailsLoader` — the widget from Activity 3 that fetches a product by id
and shows a spinner while it waits:

```dart
final full = context.read<CartProvider>().productFor(product.id);
Navigator.push(context, MaterialPageRoute(
  builder: (context) => full != null
      ? ProductDetailsScreen(product: full)
      : ProductDetailsLoader(productId: product.id),
));
```

### Confirming the order

```dart
userId: cart.userId ?? kCartUserId,
```

The real id when someone is signed in; the old constant only as a fallback.

### An empty cart has three different meanings

Previously any empty cart printed "Your cart is empty." Now that the cart is
downloaded, that same blank screen could mean three very different things, so
`_EmptyCart` tells them apart:

| State | What you see |
|---|---|
| `cart.isLoading` | a spinner |
| `cart.error != null` | "Could not load your saved cart", the reason, and **Try again** |
| neither | "Your cart is empty." |

This is the honest version of a lesson from Activity 3: a screen that shows
nothing, for a reason it will not tell you, is the hardest kind of bug to chase.

---

## 6. Things to try

- **Launch the app.** You land on the splash, then the sign-in screen.
- Tap **Sign in** with both fields blank. Two validation messages appear, and the
  button does *not* start spinning.
- Sign in as `emilys` / `emilyspass`. Watch the button spin, then the Shop tab.
- Open the **Cart** tab. It is not empty — those four items came from
  `GET /carts/user/1`, not from anything you added.
- Open the **Profile** tab. Emily's avatar, name, email and user id, all read back
  out of the phone's storage.
- **Turn off your wifi and reopen the Profile tab.** It still works. Nothing there
  needs the network.
- **Kill the app completely and reopen it.** The splash says *"Welcome back,
  Emily!"* and goes straight to the Shop — no sign-in screen. **This is the
  enhancement.**
- Add something from the Shop. It joins the cart alongside the downloaded items.
- Tap a *downloaded* cart row, then a row you added. The first shows a brief
  spinner, the second opens instantly — the two paths through `productFor()`.
- Tap **Log out**, confirm, then relaunch. You are back at the sign-in screen, and
  the cart is empty.
- Sign in as `michaelw` / `michaelwpass`. A different cart, because a different
  `userId` was fetched.
- Try `emilys` with a trailing space. `Invalid credentials` — the reason the
  fields are trimmed.

---

## 7. Known leftovers after Activity 4

- The token is stored in plain SharedPreferences. Fine for a lab; a real app would
  use `flutter_secure_storage`, which is backed by the Keychain and Keystore.
- `expiresInMins: 60` is sent at login, but nothing checks the expiry or uses the
  `refreshToken`. After an hour the saved token is stale and the app does not
  notice, because `isLoggedIn()` only asks whether a token *exists*.
- `kCartUserId` is still in `constants.dart` as the fallback for a cart built
  before anyone signed in.
- `android/app/src/main/AndroidManifest.xml` has no `INTERNET` permission — it is
  only in the `debug/` and `profile/` manifests. Debug runs are fine, but a
  **release** build would fail every network call. Same for
  `macos/Runner/*.entitlements`, which lacks `com.apple.security.network.client`.
- The project now has **no tests at all**, since `widget_test.dart` was deleted
  rather than rewritten.
- `CartService.getCartById()` and `ProductService.getAllProducts()` are still
  unused. `getCartByUserId()` is no longer on that list — Enhancement 3 calls it.

### Resolved from Activity 3's leftovers

- `test/widget_test.dart` no longer breaks `flutter analyze` — it was deleted.
- `CartService.getCartByUserId()` is in use again.
- The Profile tab is a real screen instead of a placeholder widget.

---

# Part 3 — Activity 5: Firebase authentication

Activity 4 signed you in through DummyJSON only. Activity 5 adds **Firebase
Authentication** next to it, a real signup screen, and account management on
the profile. Comments for this activity are labelled `// Act5 Enhancement N:`.

| # | Enhancement | Where |
|---|---|---|
| 1 | `UserService` Firebase functions + logout that clears the session | `user_service.dart`, `utils/auth_helpers.dart` |
| 2 | DummyJSON vs Firebase: login toggle, token refresh, security rules, signup UI | `signin_screen.dart`, `signup_screen.dart`, `firestore.rules` |
| 3 | Profile by `LoginType`, update username / change password / delete account, logout in settings | `profile_screen.dart`, `settings_screen.dart` |

## 1. The short version

| File | What happened |
|---|---|
| `lib/firebase_options.dart`, `android/app/google-services.json`, `firebase.json` | **Generated** by `flutterfire configure` for project `marinas-advmblprog` (Android, web, Windows). |
| `android/settings.gradle.kts`, `android/app/build.gradle.kts` | `flutterfire` added the Google Services Gradle plugin. |
| `pubspec.yaml` | Added `firebase_core`, `firebase_auth`, `cloud_firestore`. |
| `lib/main.dart` | Calls `Firebase.initializeApp()` before `runApp`. Added the `/signup` route. |
| `lib/models/user.dart` | New `LoginType` enum. `User` gained `uid`, `age`, `phone`, `loginType`, and `toProfileJson()` for Firestore. |
| `lib/services/user_service.dart` | Added the handout's Firebase methods (`signIn`, `createAccount`, `signOut`, `updateUsername`, `deleteAccount`, `resetPasswordFromCurrentPassword`), plus `registerUser()` and `refreshSession()`. `logout()` now signs out of Firebase too. |
| `lib/utils/auth_helpers.dart` | **New.** Friendly error messages for Firebase and DummyJSON, the password validator, and the shared logout flow. |
| `lib/screens/signin_screen.dart` | DummyJSON / Firebase toggle (username vs email) and a "Sign up" link. |
| `lib/screens/signup_screen.dart` | **New.** First name, last name, age, contact no., username, email, password + confirm. |
| `lib/screens/splash_screen.dart` | Refreshes the token on start; a session that can't be refreshed goes back to sign-in. |
| `lib/screens/profile_screen.dart` | Login-type badge, rows picked by `LoginType`, and an Account card with the three actions. |
| `lib/screens/settings_screen.dart` | New "Account → Log out" tile. |
| `firestore.rules` | **New.** Each user can only read and write `users/{their uid}`. |

## 2. Things to try

1. Sign in with **DummyJSON** (`emilys` / `emilyspass`). The profile shows a
   "DummyJSON account" badge, with age and phone read from `/auth/me`. *Change
   password* and *Delete account* are greyed out.
2. Tap **Sign up** and create an account. You land in the app signed in, and
   the profile shows a "Firebase account" badge and your UID.
3. Log out from **Settings**, then sign in again with the **Firebase** toggle.
4. Change the password, log out, and sign in with the new one.
5. Delete the account. The user disappears from Firebase console →
   Authentication → Users, and so does the Firestore document.

## 3. Known leftovers after Activity 5

- Firebase is configured for **Android, web and Windows**, but not iOS/macOS.
  If `Firebase.initializeApp` fails, `main.dart` logs it and still starts the
  app, so DummyJSON sign-in keeps working.
- A Firebase user has no DummyJSON cart, so their cart starts empty.
- If Firestore is unreachable (no database yet, or offline), signup still
  succeeds, but the extra fields are only kept on the device.

### Resolved from Activity 4's leftovers

- The `refreshToken` is now used: the splash screen renews the session on
  every start.
