import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isAgreed = false;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // GOOGLE İLE GİRİŞ
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      await _saveUserToFirestore(userCredential.user!);
      if (mounted) _navigateToHome();
    } catch (e) {
      if (mounted) _showError("Google girişi başarısız: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------
  //APPLE İLE GİRİŞ
  // ----------------------------------------------------------------
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final OAuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      if (userCredential.user != null &&
          (userCredential.user!.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        if (appleCredential.givenName != null) {
          await userCredential.user!.updateDisplayName(
            "${appleCredential.givenName} ${appleCredential.familyName ?? ''}",
          );
        }
      }
      await _saveUserToFirestore(userCredential.user!);
      if (mounted) _navigateToHome();
    } catch (e) {
      if (mounted) _showError("Apple girişi başarısız: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------
  //MİSAFİR GİRİŞİ
  // ----------------------------------------------------------------
  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInAnonymously();
      await _saveUserToFirestore(userCredential.user!, isGuest: true);
      if (mounted) _navigateToHome();
    } catch (e) {
      if (mounted) _showError("Misafir girişi yapılamadı: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // VERİTABANI & YÖNLENDİRME
  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AnaEkran()),
      (route) => false,
    );
  }

  Future<void> _saveUserToFirestore(User user, {bool isGuest = false}) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email ?? "",
          'displayName': isGuest
              ? "Misafir Kullanıcı"
              : (user.displayName ?? "Gezgin"),
          'photoURL': user.photoURL ?? "",
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'method': isGuest ? 'guest' : 'social',
          'isGuest': isGuest,
          'premiumStatus': false,
        });
      } else {
        await userDoc.update({'lastLogin': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint("Firestore kayıt hatası: $e");
    }
  }

  // E-POSTA İŞLEMLERİ
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_isAgreed) {
      _showError("Kayıt olmak için kullanım koşullarını kabul etmelisiniz.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        UserCredential cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        await _saveUserToFirestore(cred.user!);
        try {
          await cred.user!.sendEmailVerification();
        } catch (_) {}
      }
      if (mounted) _navigateToHome();
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message = "Bir hata oluştu.";
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
        message = "E-posta veya şifre hatalı.";
        break;
      case 'wrong-password':
        message = "Şifre hatalı.";
        break;
      case 'email-already-in-use':
        message = "Bu e-posta zaten kullanımda.";
        break;
      case 'weak-password':
        message = "Şifre en az 6 karakter olmalı.";
        break;
      default:
        message = "Giriş başarısız: ${e.message}";
    }
    _showError(message);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  // UI TASARIM
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF000428), Color(0xFF004e92)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // ÜST BÖLÜM:
                          FadeInDown(
                            duration: const Duration(milliseconds: 1000),
                            child: Column(
                              children: [
                                if (!isKeyboardOpen)
                                  SizedBox(
                                    height: size.height * 0.25,
                                    child: Image.asset(
                                      'assets/images/auth_illustration.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, o, s) => Image.asset(
                                        'assets/images/ic_foreground.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                const Text(
                                  "TUGA",
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 3.0,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  "Seyahat Asistanın",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // TABLAR (Giriş / Kayıt)
                          FadeIn(
                            delay: const Duration(milliseconds: 500),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTab("Giriş Yap", true),
                                const SizedBox(width: 30),
                                _buildTab("Kayıt Ol", false),
                              ],
                            ),
                          ),

                          const SizedBox(height: 15),

                          //FORM KARTI
                          Expanded(
                            child: FadeInUp(
                              duration: const Duration(milliseconds: 800),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(30),
                                ),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 30,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(30),
                                      ),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      children: [
                                        Form(
                                          key: _formKey,
                                          child: Column(
                                            children: [
                                              _buildTextField(
                                                _emailController,
                                                "E-posta",
                                                Icons.email_outlined,
                                                false,
                                              ),
                                              const SizedBox(height: 15),
                                              _buildTextField(
                                                _passwordController,
                                                "Şifre",
                                                Icons.lock_outline,
                                                true,
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 10),

                                        if (!_isLogin)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child: Checkbox(
                                                    value: _isAgreed,
                                                    activeColor: const Color(
                                                      0xFFff7e5f,
                                                    ),
                                                    side: const BorderSide(
                                                      color: Colors.white70,
                                                    ),
                                                    onChanged: (val) =>
                                                        setState(
                                                          () => _isAgreed =
                                                              val ?? false,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () => setState(
                                                      () => _isAgreed =
                                                          !_isAgreed,
                                                    ),
                                                    child: const Text(
                                                      "Kullanım Koşulları'nı kabul ediyorum.",
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        SizedBox(
                                          height: 50,
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFff7e5f,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              elevation: 5,
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Text(
                                                    _isLogin
                                                        ? "Giriş Yap"
                                                        : "Kayıt Ol",
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),

                                        if (_isLogin)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () {
                                                /* Şifre sıfırlama */
                                              },
                                              child: const Text(
                                                "Şifremi Unuttum?",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 15),

                                        // Sosyal Giriş
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildSocialButton(
                                              assetPath:
                                                  "assets/icons/google.png",
                                              fallbackIcon: Icons.g_mobiledata,
                                              onTap: _signInWithGoogle,
                                            ),
                                            if (Platform.isIOS) ...[
                                              const SizedBox(width: 20),
                                              _buildSocialButton(
                                                assetPath:
                                                    "assets/icons/apple.png",
                                                fallbackIcon: Icons.apple,
                                                onTap: _signInWithApple,
                                              ),
                                            ],
                                          ],
                                        ),

                                        const Spacer(),
                                        TextButton(
                                          onPressed: _signInAnonymously,
                                          child: const Text(
                                            "Üye olmadan devam et",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // WIDGET METHODLARI

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isPass,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: isPass && !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      keyboardType: isPass
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      textInputAction: isPass ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPass
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white),
        ),
        filled: true,
        fillColor: Colors.black12,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return "Gerekli alan";
        if (!isPass && !val.contains('@')) return "Geçersiz e-posta";
        if (isPass && val.length < 6) return "En az 6 karakter";
        return null;
      },
    );
  }

  Widget _buildTab(String text, bool active) {
    return GestureDetector(
      onTap: () {
        if (_isLogin != active)
          setState(() {
            _isLogin = active;
            _formKey.currentState?.reset();
          });
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: (_isLogin == active) ? 1.0 : 0.5,
        child: Column(
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_isLogin == active)
              Container(
                margin: const EdgeInsets.only(top: 5),
                height: 3,
                width: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFff7e5f),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String assetPath,
    required IconData fallbackIcon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),

        child: Image.asset(
          assetPath,
          errorBuilder: (context, error, stackTrace) =>
              Icon(fallbackIcon, size: 28, color: Colors.black),
        ),
      ),
    );
  }
}
