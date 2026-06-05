import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../driver/driver_main_screen.dart';
import '../customer/main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── color tokens (matches dashboard) ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool passwordVisible = false;
  bool emailError = false;
  bool passwordError = false;

  // ── NEW: shown when user tries to log in but email isn't verified yet ──
  bool showVerifyBanner = false;
  bool isResending = false;

  void loginUser() async {
    // ── Basic field validation ──
    setState(() {
      emailError = emailController.text.trim().isEmpty;
      passwordError = passwordController.text.trim().isEmpty;
      showVerifyBanner = false; // reset banner on each attempt
    });

    if (emailError || passwordError) return;

    setState(() => isLoading = true);

    try {
      final user = await _authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        String? role = await _authService.getUserRole(user.uid);

        if (role == "driver") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverMainScreen()),
          );
        } else if (role == "customer") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Invalid user role")));
        }
      }
    } catch (e) {
      if (!mounted) return;

      // ── NEW: catch the EMAIL_NOT_VERIFIED error from auth_service ──
      if (e.toString().contains('EMAIL_NOT_VERIFIED')) {
        setState(() => showVerifyBanner = true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ── NEW: resend verification email from the banner ──
  Future<void> _resendVerificationEmail() async {
    setState(() => isResending = true);

    try {
      await _authService.resendEmailVerification(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email resent! Check your inbox.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (mounted) setState(() => isResending = false);
  }

  Future<void> googleLogin() async {
    setState(() => isLoading = true);

    try {
      final user = await _authService.signInWithGoogle();

      if (!mounted) return;
      if (user == null) throw Exception("Google sign-in failed");

      String? role = await _authService.getUserRole(user.uid);

      if (role == null) {
        role = "customer";
        await _authService.createUserWithRole(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Google User',
          role: role,
        );
      }

      if (!mounted) return;

      if (role == "driver") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverMainScreen()),
        );
      } else if (role == "customer") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Google user role")),
        );
      }
    } catch (e) {
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── LOGO / BRAND ──
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
                'Welcome back',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to SmartTruck System',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 36),

              // ── NEW: Email not verified banner ──
              if (showVerifyBanner) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.mark_email_unread_outlined,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Email not verified',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please check your inbox and click the verification '
                        'link before signing in.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: isResending ? null : _resendVerificationEmail,
                        child: Row(
                          children: [
                            if (isResending)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Color(0xFFD97706),
                                ),
                              )
                            else
                              const Icon(
                                Icons.refresh_rounded,
                                size: 14,
                                color: Color(0xFFD97706),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              isResending
                                  ? 'Sending...'
                                  : 'Resend verification email',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── EMAIL FIELD ──
              _fieldLabel('Email address'),
              const SizedBox(height: 8),
              _inputField(
                controller: emailController,
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                error: emailError ? 'Email is required' : null,
              ),

              const SizedBox(height: 18),

              // ── PASSWORD FIELD ──
              _fieldLabel('Password'),
              const SizedBox(height: 8),
              _inputField(
                controller: passwordController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: !passwordVisible,
                error: passwordError ? 'Password is required' : null,
                suffix: GestureDetector(
                  onTap: () =>
                      setState(() => passwordVisible = !passwordVisible),
                  child: Icon(
                    passwordVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── LOGIN BUTTON ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : loginUser,
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
                          'Sign In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // ── DIVIDER ──
              Row(
                children: [
                  const Expanded(child: Divider(color: _border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: _border)),
                ],
              ),

              const SizedBox(height: 14),

              // ── GOOGLE BUTTON ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: isLoading ? null : googleLogin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: _border, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA4335),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── REGISTER LINK ──
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text(
                        'Create account',
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

              const SizedBox(height: 32),
            ],
          ),
        ),
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
