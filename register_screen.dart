import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ── color tokens (matches dashboard & login) ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  final AuthService _authService = AuthService();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool passwordVisible = false;

  bool fullNameError = false;
  bool emailError = false;
  bool phoneError = false;
  bool addressError = false;
  bool passwordError = false;

  // ── STEP 1: Validate form, then go to OTP screen ──
  void registerUser() async {
    setState(() {
      fullNameError = fullNameController.text.trim().isEmpty;
      emailError = emailController.text.trim().isEmpty;
      phoneError = phoneController.text.trim().isEmpty;
      addressError = addressController.text.trim().isEmpty;
      passwordError = passwordController.text.trim().isEmpty;
    });

    if (fullNameError ||
        emailError ||
        phoneError ||
        addressError ||
        passwordError)
      return;

    // ── Extra: validate PH phone format (09XXXXXXXXX = 11 digits) ──
    final phone = phoneController.text.trim();
    if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
      setState(() => phoneError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid PH number (09XXXXXXXXX)')),
      );
      return;
    }

    // ── Extra: basic email format check ──
    final email = emailController.text.trim();
    if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.\w{2,}$').hasMatch(email)) {
      setState(() => emailError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }

    // ── Extra: minimum password length ──
    if (passwordController.text.trim().length < 6) {
      setState(() => passwordError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => isLoading = true);

    // ── Navigate to OTP screen; actual registration happens after OTP passes ──
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OtpScreen(phone: phone, onVerified: () => _doRegister()),
      ),
    );

    setState(() => isLoading = false);
  }

  // ── STEP 2: Called by OtpScreen after phone is confirmed ──
  Future<void> _doRegister() async {
    setState(() => isLoading = true);

    try {
      List<String> nameParts = fullNameController.text.trim().split(" ");
      String firstName = nameParts.first;
      String lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(" ")
          : "";

      final user = await _authService.register(
        firstName: firstName,
        lastName: lastName,
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text.trim(),
        address: addressController.text.trim(),
        role: "customer",
      );

      // ── Add this: sign out immediately after register ──
      // prevents auth state listener from navigating away mid-flow
      await _authService.logout();

      print('✅ _doRegister complete, user: ${user?.email}');

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Account created! Check your email to verify before logging in.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('❌ _doRegister error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: _textPrimary,
              size: 18,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),

            // ── BRAND MARK ──
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Create account',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Join SmartTruck to manage logistics',
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 32),

            // ── SECTION: Personal Info ──
            _sectionLabel('Personal Information'),
            const SizedBox(height: 12),

            _fieldLabel('Full Name'),
            const SizedBox(height: 8),
            _inputField(
              controller: fullNameController,
              hint: 'Juan dela Cruz',
              icon: Icons.person_outline_rounded,
              error: fullNameError ? 'Full name is required' : null,
            ),

            const SizedBox(height: 16),

            _fieldLabel('Email Address'),
            const SizedBox(height: 8),
            _inputField(
              controller: emailController,
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              error: emailError ? 'Enter a valid email address' : null,
            ),

            const SizedBox(height: 16),

            _fieldLabel('Phone Number'),
            const SizedBox(height: 8),
            _inputField(
              controller: phoneController,
              hint: '09XXXXXXXXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              error: phoneError
                  ? 'Enter a valid PH number (09XXXXXXXXX)'
                  : null,
            ),

            const SizedBox(height: 16),

            _fieldLabel('Address'),
            const SizedBox(height: 8),
            _inputField(
              controller: addressController,
              hint: 'City, Province',
              icon: Icons.location_on_outlined,
              error: addressError ? 'Address is required' : null,
            ),

            const SizedBox(height: 24),

            // ── SECTION: Security ──
            _sectionLabel('Security'),
            const SizedBox(height: 12),

            _fieldLabel('Password'),
            const SizedBox(height: 8),
            _inputField(
              controller: passwordController,
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscure: !passwordVisible,
              error: passwordError
                  ? 'Password must be at least 6 characters'
                  : null,
              suffix: GestureDetector(
                onTap: () => setState(() => passwordVisible = !passwordVisible),
                child: Icon(
                  passwordVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Verification notice ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You\'ll receive an SMS to verify your phone number, '
                      'then an email to activate your account.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1D4ED8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── CREATE ACCOUNT BUTTON ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _green.withOpacity(0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── LOGIN LINK ──
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(fontSize: 13, color: _textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    String? error,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 14,
        color: _textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 14), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(),
        errorText: error,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}
