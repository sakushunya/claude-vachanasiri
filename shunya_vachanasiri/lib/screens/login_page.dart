// /lib/screens/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> otpFocusNodes =
      List.generate(6, (index) => FocusNode());

  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;
  String _errorMessage = '';

  String _selectedCountryCode = '+91';
  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'name': 'USA', 'flag': '🇺🇸'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'},
  ];

  String get enteredOtp => otpControllers.map((c) => c.text).join();

  // Add this helper method for safe state updates
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < otpFocusNodes.length; i++) {
      otpFocusNodes[i].addListener(() {
        if (!otpFocusNodes[i].hasFocus && i < otpFocusNodes.length - 1) {
          FocusScope.of(context).requestFocus(otpFocusNodes[i + 1]);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _navigateToSharanasPageAsGuest() {
    FocusScope.of(context).unfocus();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SharanasPage()),
    );
  }

  // Send OTP using Firebase
  Future<void> _sendOtp() async {
    if (_phoneController.text.length != 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit phone number');
      return;
    }

    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _verificationId = null; // Reset verification ID
    });

    try {
      final fullPhoneNumber = _selectedCountryCode + _phoneController.text;
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          await _signInWithCredential(credential); // Removed appState parameter
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  e.message ?? 'Verification failed. Please try again.';
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _otpSent = true;
              _verificationId = verificationId;
            });
            // Focus first OTP field
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                FocusScope.of(context).requestFocus(otpFocusNodes[0]);
              }
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to send OTP: ${e.toString()}';
        });
      }
    }
  }

  // Verify OTP with Firebase
  Future<void> _verifyOtp() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (enteredOtp.length != 6) {
      setState(() => _errorMessage = 'Enter a valid 6-digit OTP');
      return;
    }

    if (_verificationId == null) {
      setState(() {
        _errorMessage = 'Verification ID missing. Please request a new OTP.';
        _otpSent = false; // Reset OTP state
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: enteredOtp,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid OTP. Please try again.';
        });
      }
    }
  }

  // Sign in with Firebase credential
  Future<void> _signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Get phone number
        final phoneNumber = userCredential.user?.phoneNumber ??
            '${_selectedCountryCode}${_phoneController.text}';

        // Call login in AppState
        await appState.login(phoneNumber, userCredential.user!.uid);

        // Navigate to main screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SharanasPage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Login failed: ${e.toString()}';
        });
      }
    }
  }

  Widget _buildOtpInput(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 45,
              child: TextField(
                controller: otpControllers[index],
                focusNode: otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.length == 1 && index < 5) {
                    FocusScope.of(context)
                        .requestFocus(otpFocusNodes[index + 1]);
                  }
                },
                onTap: () {
                  if (otpControllers[index].text.isNotEmpty) {
                    otpControllers[index].selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: otpControllers[index].text.length,
                    );
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            // Resend OTP
            _sendOtp();
            // Clear OTP fields
            for (var controller in otpControllers) {
              controller.clear();
            }
          },
          child: const Text(
            'Resend OTP',
            style: TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return WillPopScope(
      onWillPop: () async {
        if (_otpSent) {
          setState(() {
            _otpSent = false;
            _errorMessage = '';
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Vachanasiri',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          Center(
                            child: Image.asset(
                              'assets/ShunyaBasavanna.png',
                              height: 150,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Center(
                            child: Column(
                              children: [
                                Text(
                                  'Compliation of 12th century vachanas',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                Text(
                                  'by Shunya Organisation',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                          const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),
                          const Text(
                            'Login to save your favourite vachanas.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),

                          // Error message
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Phone input field
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.only(left: 12, right: 8),
                                  child: DropdownButton<String>(
                                    value: _selectedCountryCode,
                                    dropdownColor: Colors.grey[900],
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.arrow_drop_down,
                                        color: Colors.white),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16),
                                    items: _countryCodes.map((country) {
                                      return DropdownMenuItem<String>(
                                        value: country['code'],
                                        child: Row(
                                          children: [
                                            Text(country['flag']!),
                                            const SizedBox(width: 8),
                                            Text(country['code']!),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCountryCode = value!;
                                      });
                                    },
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  width: 1,
                                  color: Colors.grey[700],
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter Mobile Number',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      counterText: '',
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    onSubmitted: (value) {
                                      if (_phoneController.text.length == 10) {
                                        _sendOtp();
                                      }
                                    },
                                    enabled: false,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Get OTP Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              // onPressed: _isLoading ? null : _sendOtp,
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isLoading
                                    ? Colors.grey[700]
                                    : Colors.blue[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      'Get OTP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          // OTP Field
                          if (_otpSent) ...[
                            const SizedBox(height: 20),
                            _buildOtpInput(context),
                            const SizedBox(height: 20),

                            // Verify OTP Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isLoading
                                      ? Colors.grey[700]
                                      : Colors.blue[800],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        'Verify OTP',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],

                          const Spacer(),

                          // Always show the guest login option
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              const Expanded(
                                  child: Divider(color: Colors.grey)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Expanded(
                                  child: Divider(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _navigateToSharanasPageAsGuest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Continue as a Guest',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
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
}
