import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/app_logo.dart';
import '../../services/firebase_service.dart';
import '../../services/ride_service.dart';
import '../../services/user_session.dart';
import '../customer/customer_home.dart';
import '../driver/driver_home.dart';
import 'driver_register_screen.dart';

// ─────────────────────────────────────────────────────────────
//  LoginScreen — Firebase Phone OTP + Firestore profile load
// ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Login tab state ────────────────────────────────────────
  final _loginPhoneCtrl = TextEditingController();
  bool   _otpSent        = false;
  bool   _isLoginLoading = false;
  String _loginRole      = 'customer';

  // ── Register tab state ─────────────────────────────────────
  final _regNameCtrl  = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  bool   _isRegLoading = false;
  String _regRole      = 'customer';
  bool   _regOtpSent   = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginPhoneCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regEmailCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────
  String _e164(String raw) {
    // strips leading 0, prepends +92
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) return '+$digits';
    if (digits.startsWith('0'))  return '+92${digits.substring(1)}';
    return '+92$digits';
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _setLoading(bool v) {
    if (mounted) setState(() => _isLoginLoading = v);
  }

  void _setRegLoading(bool v) {
    if (mounted) setState(() => _isRegLoading = v);
  }

  // ════════════════════════════════════════════════════════════
  //  LOGIN FLOW
  // ════════════════════════════════════════════════════════════

  Future<void> _sendLoginOTP() async {
    final phone = _loginPhoneCtrl.text.trim();
    if (phone.length < 7) {
      _snack('Please enter a valid mobile number', isError: true);
      return;
    }
    if (!FirebaseService.isReady) {
      _snack(
        'Firebase not set up. Use Continue with Email / Google for demo.',
        isError: true,
      );
      return;
    }
    _setLoading(true);

    await FirebaseService.instance.sendOTP(
      phoneNumber: _e164(phone),
      onCodeSent: (_) {
        _setLoading(false);
        if (mounted) setState(() => _otpSent = true);
        _snack('OTP sent to ${_e164(phone)}');
      },
      onError: (err) {
        _setLoading(false);
        _snack('Failed: $err', isError: true);
      },
      onAutoVerified: (credential) {
        _verifyLoginCredential(credential);
      },
    );
  }

  Future<void> _verifyLoginOTP(String code) async {
    if (code.length < 4) return;
    _setLoading(true);
    try {
      final cred = await FirebaseService.instance.verifyOTP(code);
      await _handleLoginCredential(cred);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _snack(e.message ?? 'Invalid OTP', isError: true);
    } catch (e) {
      _setLoading(false);
      _snack('Error: $e', isError: true);
    }
  }

  Future<void> _verifyLoginCredential(PhoneAuthCredential credential) async {
    _setLoading(true);
    try {
      final cred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await _handleLoginCredential(cred);
    } catch (e) {
      _setLoading(false);
      _snack('Auto-verify failed: $e', isError: true);
    }
  }

  Future<void> _handleLoginCredential(UserCredential cred) async {
    final uid   = cred.user!.uid;
    final phone = _loginPhoneCtrl.text.trim();

    // Check if user already has a Firestore doc
    final existing = await FirebaseService.instance.fetchUser(uid);

    if (existing != null) {
      // Returning user — load their session
      await FirebaseService.instance.loadSessionFromFirestore();
      _setLoading(false);
      final role = existing['role'] as String? ?? '';
      if (!mounted) return;
      if (role == 'driver') {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DriverHome()));
      } else {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CustomerHome()));
      }
    } else {
      // New user — create profile based on selected role
      _setLoading(false);
      if (!mounted) return;
      if (_loginRole == 'customer') {
        final name = _deriveNameFromPhone(phone);
        await FirebaseService.instance.saveCustomer(
          uid: uid, name: name, phone: _e164(phone));
        UserSession.instance.setCustomer(
            name: name, phone: _e164(phone), firebaseUid: uid);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CustomerHome()));
      } else {
        // Driver — needs document upload first
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => DriverRegisterScreen(
              phone: _e164(phone), firebaseUid: uid),
        ));
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  //  REGISTER FLOW
  // ════════════════════════════════════════════════════════════

  Future<void> _sendRegisterOTP() async {
    final name  = _regNameCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();

    if (name.isEmpty) {
      _snack('Please enter your full name', isError: true);
      return;
    }
    if (phone.length < 7) {
      _snack('Please enter a valid mobile number', isError: true);
      return;
    }
    if (!FirebaseService.isReady) {
      _snack(
        'Firebase not set up. Use Continue with Email / Google for demo.',
        isError: true,
      );
      return;
    }
    _setRegLoading(true);

    await FirebaseService.instance.sendOTP(
      phoneNumber: _e164(phone),
      onCodeSent: (_) {
        _setRegLoading(false);
        if (mounted) setState(() => _regOtpSent = true);
        _snack('OTP sent to ${_e164(phone)}');
      },
      onError: (err) {
        _setRegLoading(false);
        _snack('Failed: $err', isError: true);
      },
      onAutoVerified: (credential) => _completeRegistration(credential),
    );
  }

  Future<void> _verifyRegisterOTP(String code) async {
    if (code.length < 4) return;
    _setRegLoading(true);
    try {
      final cred = await FirebaseService.instance.verifyOTP(code);
      await _completeRegistration(cred);
    } on FirebaseAuthException catch (e) {
      _setRegLoading(false);
      _snack(e.message ?? 'Invalid OTP', isError: true);
    }
  }

  Future<void> _completeRegistration(dynamic cred) async {
    UserCredential userCred;
    if (cred is PhoneAuthCredential) {
      userCred = await FirebaseAuth.instance.signInWithCredential(cred);
    } else {
      userCred = cred as UserCredential;
    }

    final uid   = userCred.user!.uid;
    final name  = _regNameCtrl.text.trim();
    final phone = _e164(_regPhoneCtrl.text.trim());
    final email = _regEmailCtrl.text.trim();

    _setRegLoading(false);
    if (!mounted) return;

    if (_regRole == 'customer') {
      await FirebaseService.instance.saveCustomer(
          uid: uid, name: name, phone: phone, email: email);
      UserSession.instance.setCustomer(
          name: name, phone: phone, email: email, firebaseUid: uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CustomerHome()));
    } else {
      // Driver → document upload
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DriverRegisterScreen(
            phone: phone, firebaseUid: uid, prefillName: name),
      ));
    }
  }

  String _deriveNameFromPhone(String phone) {
    const names = [
      'Ayesha Siddiqui', 'Fatima Noor', 'Hira Khan',
      'Zainab Ali', 'Sara Ahmed', 'Mehwish Hayat',
    ];
    if (phone.isEmpty) return names[0];
    final d = int.tryParse(phone[phone.length - 1]) ?? 0;
    return names[d % names.length];
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0A18),
              AppTheme.bgDark,
              AppTheme.bgDark,
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 28),

                // Brand header
                Column(
                  children: [
                    const AppLogo(size: 96),
                    const SizedBox(height: 18),
                    RichText(
                      text: const TextSpan(children: [
                        TextSpan(
                          text: 'Drive for ',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Women',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ]),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 6),
                    const Text(
                      'Safe Rides, by Women for Women',
                      style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),

                const SizedBox(height: 32),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: AppGradients.tripleGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorPadding: const EdgeInsets.all(4),
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textHint,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                    tabs: const [
                      Tab(text: 'Login'),
                      Tab(text: 'Register'),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 28),

                SizedBox(
                  height: 560,
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLoginTab(), _buildRegisterTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Login tab ──────────────────────────────────────────────
  Widget _buildLoginTab() {
    final defaultPin = PinTheme(
      width: 60, height: 60,
      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role chips
        Row(children: [
          Expanded(child: _RoleChip(
            label: '👩 Customer', isSelected: _loginRole == 'customer',
            onTap: () => setState(() { _loginRole = 'customer'; _otpSent = false; }),
          )),
          const SizedBox(width: 12),
          Expanded(child: _RoleChip(
            label: '🚗 Driver', isSelected: _loginRole == 'driver',
            onTap: () => setState(() { _loginRole = 'driver'; _otpSent = false; }),
          )),
        ]).animate().fadeIn(delay: 500.ms),

        const SizedBox(height: 20),

        // Phone field
        const Text('Mobile Number',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text('+92',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _loginPhoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppTheme.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Enter mobile number',
              prefixIcon: Icon(Icons.phone_android_rounded,
                  color: AppTheme.textHint, size: 20),
            ),
          )),
        ]).animate().fadeIn(delay: 600.ms),

        const SizedBox(height: 16),

        if (_otpSent) ...[
          const Text('Enter OTP',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Center(
            child: Pinput(
              length: 6,
              defaultPinTheme: defaultPin,
              focusedPinTheme: defaultPin.copyWith(
                decoration: defaultPin.decoration!.copyWith(
                    border: Border.all(color: AppTheme.primary, width: 2)),
              ),
              onCompleted: _verifyLoginOTP,
            ),
          ).animate().fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 8),
          Center(child: TextButton(
            onPressed: _sendLoginOTP,
            child: const Text('Resend OTP',
                style: TextStyle(color: AppTheme.primary)),
          )),
          if (_isLoginLoading)
            const Padding(padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2)),
            ),
        ] else ...[
          GradientButton(
            label: _isLoginLoading ? 'Sending OTP...' : 'Send OTP',
            isLoading: _isLoginLoading,
            onPressed: _sendLoginOTP,
          ).animate().fadeIn(delay: 700.ms),
        ],

        const SizedBox(height: 20),

        // Divider
        Row(children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or continue with',
                style: TextStyle(color: AppTheme.textHint, fontSize: 12))),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        ]),
        const SizedBox(height: 14),

        _SocialButton(
          icon: Icons.mail_rounded,
          label: 'Continue with Email',
          onPressed: _showEmailAuthDialog,
        ).animate().fadeIn(delay: 800.ms),
        const SizedBox(height: 10),
        _SocialButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
          onPressed: _signInWithGoogle,
        ).animate().fadeIn(delay: 900.ms),
      ],
    );
  }

  Future<void> _signInWithGoogle() async {
    if (!FirebaseService.isReady) {
      _snack('Firebase not connected', isError: true);
      return;
    }
    _setLoading(true);
    try {
      final cred = await RideService.instance
          .signInWithGoogle(role: _loginRole);
      if (cred == null) {
        _setLoading(false);
        return;
      }
      if (!mounted) return;
      final home = UserSession.instance.role == 'driver'
          ? const DriverHome()
          : const CustomerHome();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => home));
    } catch (e) {
      _snack('Google sign-in failed: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _showEmailAuthDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var isRegister = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: Text(isRegister ? 'Create account' : 'Email login',
              style: const TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRegister)
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Full name',
                      hintStyle: TextStyle(color: AppTheme.textHint),
                    ),
                  ),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: AppTheme.textHint),
                  ),
                ),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Password (min 6)',
                    hintStyle: TextStyle(color: AppTheme.textHint),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setLocal(() => isRegister = !isRegister),
                  child: Text(
                    isRegister
                        ? 'Have an account? Sign in'
                        : 'New here? Register',
                    style: const TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textHint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isRegister ? 'Register' : 'Sign in'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (!FirebaseService.isReady) {
      _snack('Firebase not connected', isError: true);
      return;
    }
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final name = nameCtrl.text.trim().isEmpty
        ? email.split('@').first
        : nameCtrl.text.trim();
    if (email.isEmpty || pass.length < 6) {
      _snack('Enter valid email and password (6+ chars)', isError: true);
      return;
    }
    _setLoading(true);
    try {
      await RideService.instance.signInWithEmailPassword(
        email: email,
        password: pass,
        isRegister: isRegister,
        name: name,
        role: _loginRole,
      );
      if (!mounted) return;
      final home = UserSession.instance.role == 'driver'
          ? const DriverHome()
          : const CustomerHome();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => home));
    } catch (e) {
      _snack('Email auth failed: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  // ── Register tab ───────────────────────────────────────────
  Widget _buildRegisterTab() {
    final defaultPin = PinTheme(
      width: 55, height: 55,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary),
      decoration: BoxDecoration(
        color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        TextField(
          controller: _regNameCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          textCapitalization: TextCapitalization.words,
          enabled: !_regOtpSent,
          decoration: const InputDecoration(
            hintText: 'Full Name',
            prefixIcon: Icon(Icons.person_rounded, color: AppTheme.textHint),
          ),
        ),
        const SizedBox(height: 14),

        // Phone
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Text('+92',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _regPhoneCtrl,
            keyboardType: TextInputType.phone,
            enabled: !_regOtpSent,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Mobile Number'),
          )),
        ]),
        const SizedBox(height: 14),

        // Email
        TextField(
          controller: _regEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          enabled: !_regOtpSent,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Email (optional)',
            prefixIcon: Icon(Icons.email_rounded, color: AppTheme.textHint),
          ),
        ),
        const SizedBox(height: 16),

        // Role selector
        const Text('Register as',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _RoleChip(
            label: '👩 Customer', isSelected: _regRole == 'customer',
            onTap: () { if (!_regOtpSent) setState(() => _regRole = 'customer'); },
          )),
          const SizedBox(width: 12),
          Expanded(child: _RoleChip(
            label: '🚗 Driver', isSelected: _regRole == 'driver',
            onTap: () { if (!_regOtpSent) setState(() => _regRole = 'driver'); },
          )),
        ]),

        if (_regRole == 'driver') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Driver registration requires CNIC, driving licence & bike photo in the next step.',
                style: TextStyle(color: AppTheme.primary, fontSize: 11,
                    fontWeight: FontWeight.w500),
              )),
            ]),
          ),
        ],

        const SizedBox(height: 16),

        // OTP entry (shown after SMS sent)
        if (_regOtpSent) ...[
          const Text('Enter OTP sent to your number',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Center(
            child: Pinput(
              length: 6,
              defaultPinTheme: defaultPin,
              focusedPinTheme: defaultPin.copyWith(
                decoration: defaultPin.decoration!.copyWith(
                    border: Border.all(color: AppTheme.primary, width: 2)),
              ),
              onCompleted: _verifyRegisterOTP,
            ),
          ).animate().fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 8),
          Center(child: TextButton(
            onPressed: () => setState(() => _regOtpSent = false),
            child: const Text('Change Number',
                style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
          )),
          if (_isRegLoading)
            const Padding(padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2)),
            ),
        ] else ...[
          GradientButton(
            label: _isRegLoading ? 'Sending OTP...' : 'Send OTP & Register',
            isLoading: _isRegLoading,
            onPressed: _sendRegisterOTP,
          ),
        ],
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(child: Text(label,
            style: TextStyle(
              color: isSelected ? AppTheme.primary : AppTheme.textHint,
              fontWeight: FontWeight.w600, fontSize: 13,
            ))),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _SocialButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const LoginScreen();
}
