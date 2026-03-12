/// Singleton that holds the currently logged-in user's data.
/// Data is populated from SignupScreen or LoginScreen.
class UserStore {
  UserStore._();
  static final UserStore instance = UserStore._();

  String name = 'Donor';
  String email = '';
  String phone = '';
  String bloodGroup = '';
  String age = '';
  String gender = '';
  String location = '';
  bool isAdmin = false;

  /// Call this after signup
  void setFromSignup({
    required String name,
    required String phone,
    required String age,
    required String gender,
    required String bloodGroup,
    required String location,
  }) {
    this.name = name.isNotEmpty ? name : 'Donor';
    this.phone = phone;
    this.age = age;
    this.gender = gender;
    this.bloodGroup = bloodGroup;
    this.location = location;
    email = '';
  }

  /// Call this after login (email/phone only)
  void setFromLogin({required String emailOrPhone}) {
    final input = emailOrPhone.trim();
    if (input.contains('@')) {
      email = input;
      // derive a friendly name from email prefix if no name yet
      if (name == 'Donor') {
        final prefix = input.split('@').first;
        name = prefix[0].toUpperCase() + prefix.substring(1);
      }
    } else {
      phone = input;
    }
  }

  /// Clears all user data (logout)
  void clear() {
    name = 'Donor';
    email = '';
    phone = '';
    bloodGroup = '';
    age = '';
    gender = '';
    location = '';
    isAdmin = false;
  }
}
