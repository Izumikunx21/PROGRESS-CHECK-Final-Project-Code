import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final VoidCallback onVerified;

  const OtpScreen({super.key, required this.phone, required this.onVerified});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // ── color tokens (matches register & login) ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  final _otpController = TextEditingController();
  String? _verificationId;
  bool _isLoading = true;
  bool _isSending = false;
  int _resendCooldown = 0; // seconds remaining before resend is allowed

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _resendCooldown = 30; // 30s cooldown after each send
    });

    // Start cooldown countdown
    _startCooldown();

    // Format PH number: "09XXXXXXXXX" → "+639XXXXXXXXX"
    final formatted = widget.phone.startsWith('0')
        ? '+63${widget.phone.substring(1)}'
        : widget.phone;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formatted,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        await FirebaseAuth.instance.signInWithCredential(cred);
        await FirebaseAuth.instance.signOut(); // ← ADD THIS TOO
        if (mounted) widget.onVerified();
      },
      verificationFailed: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: ${e.message}')),
        );
        setState(() => _isLoading = false);
      },
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  void _startCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown = (_resendCooldown - 1).clamp(0, 60));
      return _resendCooldown > 0;
    });
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;

    final code = _otpController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit code')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      await FirebaseAuth.instance.signOut(); // ← ADD THIS
      if (mounted) widget.onVerified();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'invalid-verification-code'
          ? 'Invalid OTP. Please check and try again.'
          : 'Verification failed: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    }

    if (mounted) setState(() => _isSending = false);
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _green),
                  SizedBox(height: 16),
                  Text(
                    'Sending OTP...',
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // ── ICON ──
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.sms_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Verify your phone',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit code to '),
                        TextSpan(
                          text: widget.phone,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── OTP INPUT ──
                  const Text(
                    'Verification code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '------',
                      hintStyle: TextStyle(
                        fontSize: 22,
                        letterSpacing: 8,
                        color: _textSecondary.withOpacity(0.4),
                        fontWeight: FontWeight.w400,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _border,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: _border,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _green, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── VERIFY BUTTON ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _green.withOpacity(0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Verify Phone',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── RESEND with cooldown ──
                  Center(
                    child: _resendCooldown > 0
                        ? Text(
                            'Resend code in ${_resendCooldown}s',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _textSecondary,
                            ),
                          )
                        : GestureDetector(
                            onTap: _sendOtp,
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _green,
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
