import 'package:flutter/material.dart';
import "../data/constrains_&_utils.dart";
import "../data/notifiers.dart";
import 'country_dropdown.dart';

class InputField extends StatefulWidget {
  const InputField({
    super.key,
    this.type = 0,
    required this.controller,
    required this.placeholderText,
    this.isRequired = false,
    this.isOnLoginPage = false,

    /// ✅ Для type == 3 (repeat_password): контролер поля password
    this.matchController,
  });

  /// 0=email, 1=phone, 2=password, 3=repeat_password
  final int type;
  final TextEditingController controller;
  final TextEditingController? matchController;

  final String placeholderText;
  final bool isRequired;
  final bool isOnLoginPage;

  @override
  InputFieldState createState() => InputFieldState();
}

// Public so parent widgets can use GlobalKey<InputFieldState>
class InputFieldState extends State<InputField> {
  static const int tEmail = 0;
  static const int tPhone = 1;
  static const int tPassword = 2;
  static const int tRepeatPassword = 3;
  bool get _isPasswordField =>
      widget.type == tPassword || widget.type == tRepeatPassword;

  final emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  bool _obscure = true;
  String _errorText = "";
  bool? _isValid;

  /// When true, focus-loss will NOT clear the error message.
  /// Set by [validateNow] so submit-triggered errors stay visible.
  /// Reset to false when the user re-focuses the field.
  bool _forceShow = false;

  Country selected = countries.first;

  @override
  void initState() {
    super.initState();
    selected = countryNotifier.value ?? countries.first;

    final shouldAttachListener =
        !(widget.type == tPassword && widget.isOnLoginPage);

    if (shouldAttachListener) {
      widget.controller.addListener(validate);
      if (widget.type == tRepeatPassword) {
        widget.matchController?.addListener(validate);
      }
    }
  }

  @override
  void dispose() {
    final shouldDetachListener =
        !(widget.type == tPassword && widget.isOnLoginPage);

    if (shouldDetachListener) {
      widget.controller.removeListener(validate);
      if (widget.type == tRepeatPassword) {
        widget.matchController?.removeListener(validate);
      }
    }
    super.dispose();
  }

  bool _isPasswordStrong(String password) {
    if (password.trim().isEmpty) return false;
    final regex = RegExp(
      r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
    );
    return regex.hasMatch(password);
  }

  void _setValidation({required bool? ok, required String message}) {
    if (_isValid == ok && _errorText == message) return;
    setState(() {
      _isValid = ok;
      _errorText = message;
    });
  }

  void validate() {
    final value = widget.controller.text.trim();

    switch (widget.type) {
      case tEmail:
        if (value.isEmpty) {
          _setValidation(ok: null, message: "");
        } else if (emailRegex.hasMatch(value)) {
          _setValidation(ok: true, message: "Valid email");
        } else {
          _setValidation(ok: false, message: "Invalid email");
        }
        return;

      case tPhone:
        if (value.isEmpty) {
          _setValidation(ok: null, message: "");
        } else if (value.length == 9) {
          _setValidation(ok: true, message: "Valid number");
        } else {
          _setValidation(ok: false, message: "Invalid number");
        }
        return;

      case tPassword:
        if (value.isEmpty) {
          _setValidation(ok: false, message: "Password cannot be empty!");
        } else if (_isPasswordStrong(value)) {
          _setValidation(ok: true, message: "Valid password");
        } else {
          _setValidation(
            ok: false,
            message:
                "Password must contain at least 8 chars, 1 uppercase, 1 lowercase, 1 number, and 1 special character.",
          );
        }
        return;

      case tRepeatPassword:
        final matchCtrl = widget.matchController;
        final original = (matchCtrl?.text ?? "").trim();

        if (matchCtrl == null) {
          _setValidation(
            ok: false,
            message: "Internal error: matchController is not provided",
          );
          return;
        }
        if (value.isEmpty) {
          _setValidation(ok: false, message: "Please repeat password");
          return;
        }
        if (original.isEmpty) {
          _setValidation(ok: false, message: "Enter password first");
          return;
        }
        if (value != original) {
          _setValidation(ok: false, message: "Passwords do not match");
          return;
        }
        _setValidation(ok: true, message: "Passwords match");
        return;

      default:
        _setValidation(ok: null, message: "");
        return;
    }
  }

  /// Triggers validation immediately and forces the error message to stay
  /// visible even after the field loses focus. Returns [true] if the field
  /// is valid. Call via [GlobalKey<InputFieldState>] on form submit.
  bool validateNow() {
    _forceShow = true;
    validate();

    // Handle the case where an empty required field hasn't triggered the
    // listener yet — show a "required" error explicitly.
    if (_isValid == null && widget.isRequired) {
      final value = widget.controller.text.trim();
      if (value.isEmpty) {
        setState(() {
          _isValid = false;
          _errorText = "${widget.placeholderText} is required";
        });
      }
    }

    return _isValid == true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.type == tPhone)
              CountryDropdownCompact(
                value: selected,
                onChanged: (c) {
                  setState(() => selected = c);
                  countryNotifier.value = c;
                },
              ),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Focus(
                    onFocusChange: (hasFocus) {
                      if (hasFocus) {
                        // User came back to edit — restore normal clear-on-blur
                        setState(() => _forceShow = false);
                      } else if (!_forceShow) {
                        // Normal blur: hide error so unfocused fields look clean
                        setState(() {
                          _errorText = "";
                          _isValid = null;
                        });
                      }
                      // _forceShow == true && !hasFocus → keep error visible
                    },
                    child: TextField(
                      controller: widget.controller,
                      obscureText: _isPasswordField ? _obscure : false,
                      textAlignVertical: TextAlignVertical.center,
                      cursorColor: Colors.black,
                      decoration: InputDecoration(
                        suffixIcon: _isPasswordField
                            ? IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: KColors.mainColor,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              )
                            : null,
                        hintText: widget.placeholderText,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(
                            // Show red border on unfocused invalid fields
                            // only when submit was attempted (_forceShow)
                            color: _forceShow && _isValid == false
                                ? Colors.redAccent
                                : KColors.thirdColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: _isValid == false
                              ? const BorderSide(color: Colors.redAccent)
                              : _isValid == true
                              ? const BorderSide(color: Colors.green)
                              : BorderSide(color: KColors.thirdColor),
                        ),
                        hintStyle: KTextStyles.fontMediumStyle.copyWith(
                          color: KColors.darkPlaceholderColor,
                          fontWeight: FontWeight.w300,
                          height: 1,
                        ),
                        labelStyle: KTextStyles.fontMediumStyle.copyWith(
                          color: Colors.black,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: KTextStyles.fontMediumStyle.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  widget.isRequired
                      ? Positioned(
                          top: 2,
                          right: 10,
                          child: Text(
                            "*",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _errorText.isNotEmpty
              ? Text(
                  _errorText,
                  key: ValueKey(_errorText),
                  style: KTextStyles.fontSmallStyle.copyWith(
                    color: _isValid == true
                        ? const Color.fromARGB(255, 96, 226, 101)
                        : _isValid == false
                        ? const Color.fromARGB(255, 255, 100, 100)
                        : KColors.placeholderColor,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }
}