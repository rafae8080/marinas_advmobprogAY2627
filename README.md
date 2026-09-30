# marinas-advmobprogAY2627

Flutter e-commerce app for Advanced Mobile Programming. The project lives in
[`marinas_advmobprog/`](marinas_advmobprog/).

---

## Lab Activity 5: discussion

### The DummyJSON workflow

**Sign in.** The sign-in screen is set to *DummyJSON*. It sends the username
and password to `UserService.loginUser()`, which posts them to
`https://dummyjson.com/auth/login`. The response contains an `accessToken`,
a `refreshToken` and part of the user record. The service then calls
`/auth/me` with the new token to get the fields the login response leaves out
(age and phone). Everything is saved to SharedPreferences with
`loginType = dummyJson`, and the splash screen opens the app.

**Staying signed in.** On every start, the splash screen calls
`refreshSession()`. For DummyJSON this posts the saved refresh token to
`/auth/refresh` and stores the new pair of tokens. If the server rejects the
refresh token, the session is cleared and the user goes back to the login
screen.

**Sign up.** DummyJSON has no real signup. `POST /users/add` answers with a new
user id, but nothing is stored, so the new user can never sign in. The same is
true for `PUT /users/{id}`, which the profile uses to rename a DummyJSON user:
the server replies with the change, and the app keeps it locally only. This is
why the profile only offers *Change password* and *Delete account* to Firebase
accounts.

### The Firebase workflow

**Sign up.** The signup screen collects the fields of a
[dummyjson.com/users](https://dummyjson.com/users) record: first name, last
name, age, contact number, username, email and password. The password must
have at least 8 characters, including an uppercase letter, a lowercase letter,
a number and a symbol. `UserService.registerUser()` then:

1. calls `createAccount()` (`createUserWithEmailAndPassword`), so the Firebase
   Auth SDK creates the account and signs the user in;
2. sets the username as the Firebase display name;
3. writes the other fields to Cloud Firestore under `users/{uid}`, because
   Firebase Auth only stores the email, password and display name;
4. saves the session to SharedPreferences with `loginType = firebase`.

**Sign in.** With the toggle on *Firebase*, the email and password go to
`signIn()` (`signInWithEmailAndPassword`). The profile document is read back
from Firestore and cached locally, like the DummyJSON profile.

**Staying signed in.** The Firebase SDK keeps its own session on the device.
On start, `refreshSession()` calls `getIdToken(true)` to force a fresh ID
token. If the account was deleted or disabled in the console, the refresh
fails and the user is sent back to the login screen.

**Account actions.** The profile screen calls `updateUsername()`,
`resetPasswordFromCurrentPassword()` and `deleteAccount()`. The last two
re-authenticate with the current password first, because Firebase requires a
recent login for sensitive changes. Logout is on both the profile and the
settings screen. It signs out of Firebase, clears SharedPreferences, empties
the cart, and removes every route so the back button cannot return to the
app.

### The main idea behind `UserService`

`UserService` is the only class that knows how authentication works. Screens
call methods like `loginUser`, `signIn`, `registerUser`, `getUser`,
`refreshSession` and `logout`. They never build an HTTP request or call
`FirebaseAuth` directly. Both backends end in the same place: a `User` model
saved to SharedPreferences, tagged with a `LoginType`. So the splash screen,
the profile and the cart work the same way whichever backend signed you in.
Only the profile checks `LoginType`, to decide which fields and actions to
show. Adding a third provider (for example Google sign-in) would mean adding
methods to `UserService`, not rewriting screens.

### Benefits of Firebase for this app

- **Real accounts.** Users can register, and their accounts persist.
  DummyJSON only simulates writes.
- **Secure credential handling.** Passwords are hashed and checked by Google's
  servers. The app never stores a password; it only keeps a short-lived ID
  token.
- **Automatic token refresh.** The SDK renews the one-hour ID token by itself,
  instead of the app having to track expiry and call `/auth/refresh`.
- **Security rules.** `firestore.rules` lets a signed-in user read and write
  only their own `users/{uid}` document, with a fixed set of fields. The rules
  are enforced on the server, so a modified app cannot read other people's
  profiles.
- **Account management built in.** Changing the password, deleting the
  account and re-authentication are single SDK calls. The Firebase console
  also lists, disables and deletes users without any extra backend work.
