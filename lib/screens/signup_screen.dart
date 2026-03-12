import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedGender;
  String? selectedBloodGroup;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final List<String> genders = ["Male", "Female", "Other"];
  final List<String> bloodGroups = [
    "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-",
  ];

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    locationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate() ||
        selectedGender == null ||
        selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.criticalRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseService.instance.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        age: ageController.text.trim(),
        gender: selectedGender!,
        bloodGroup: selectedBloodGroup!,
        location: locationController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      String message = 'Sign up failed. Please try again.';
      final err = e.toString();
      if (err.contains('email-already-in-use')) {
        message = 'This email is already registered. Try logging in.';
      } else if (err.contains('weak-password')) {
        message = 'Password must be at least 6 characters.';
      } else if (err.contains('invalid-email')) {
        message = 'Please enter a valid email address.';
      } else if (err.contains('network-request-failed')) {
        message = 'No internet connection. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.criticalRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Gradient header ────────────────────────────────────────
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Account 🩸',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Join the Donviva community',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Form card ──────────────────────────────────────
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildField(
                              controller: nameController,
                              label: 'Full Name',
                              icon: Icons.person_rounded,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            _buildField(
                              controller: emailController,
                              label: 'Email Address',
                              icon: Icons.email_rounded,
                              inputType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (!v.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                            _buildField(
                              controller: ageController,
                              label: 'Age',
                              icon: Icons.cake_rounded,
                              inputType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            _buildField(
                              controller: phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_android_rounded,
                              inputType: TextInputType.phone,
                              maxLength: 10,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length != 10) return 'Must be 10 digits';
                                return null;
                              },
                            ),
                            _buildDropdown(
                              label: 'Gender',
                              icon: Icons.wc_rounded,
                              items: genders,
                              value: selectedGender,
                              onChanged: (val) =>
                                  setState(() => selectedGender = val),
                            ),
                            _buildDropdown(
                              label: 'Blood Group',
                              icon: Icons.bloodtype_rounded,
                              items: bloodGroups,
                              value: selectedBloodGroup,
                              onChanged: (val) =>
                                  setState(() => selectedBloodGroup = val),
                            ),
                            _buildField(
                              controller: locationController,
                              label: 'City / Location',
                              icon: Icons.location_on_rounded,
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            _buildField(
                              controller: passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length < 6) return 'Min 6 characters';
                                return null;
                              },
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textGrey,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () =>
                                      _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryRed,
                                    ),
                                  )
                                : CustomButton(
                                    text: 'Create Account',
                                    onPressed: _signUp,
                                  ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  ),
                                  child: Text(
                                    'Login',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryRed,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        obscureText: obscure,
        maxLength: maxLength,
        inputFormatters: maxLength != null && inputType == TextInputType.phone
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
          suffixIcon: suffix,
          counterText: maxLength != null ? '' : null,
          filled: true,
          fillColor: AppColors.surfaceGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryRed,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.criticalRed, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.criticalRed, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
          filled: true,
          fillColor: AppColors.surfaceGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryRed,
              width: 1.5,
            ),
          ),
        ),
        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
        dropdownColor: Colors.white,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        validator: (val) => val == null ? 'Required' : null,
      ),
    );
  }
}