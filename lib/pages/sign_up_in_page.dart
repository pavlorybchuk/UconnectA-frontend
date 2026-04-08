import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/auth/auth_gate.dart';
import 'package:uconnecta/components/input_field.dart';
import 'package:uconnecta/data/notifiers.dart';
import 'package:uconnecta/pages/home_page_unregistered.dart';
import './../data/constrains.dart';

class SignUpInPage extends StatefulWidget {
  const SignUpInPage({super.key});

  @override
  State<SignUpInPage> createState() => _SignUpInPageState();
}

class _SignUpInPageState extends State<SignUpInPage> {
  bool isLoading = false;
  late final TextEditingController controller1;
  late final TextEditingController controller2;
  late final TextEditingController controller3;
  late final TextEditingController controller4;
  late final TextEditingController controller5;
  late final TextEditingController controller6;
  late final TextEditingController controller7;

  @override
  void initState() {
    super.initState();
    controller1 = TextEditingController();
    controller2 = TextEditingController();
    controller3 = TextEditingController();
    controller4 = TextEditingController();
    controller5 = TextEditingController();
    controller6 = TextEditingController();
    controller7 = TextEditingController();
  }

  @override
  void dispose() {
    controller1.dispose();
    controller2.dispose();
    controller3.dispose();
    controller4.dispose();
    controller5.dispose();
    controller6.dispose();
    controller7.dispose();

    super.dispose();
  }

  Future<bool> _showHowToAddressModal() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: KColors.mainColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "How shall people address you?",
                  style: KTextStyles.fontBiggerStyle.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: .center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller7,
                  cursorColor: Colors.black,
                  decoration: InputDecoration(
                    hintText: "Left empty for 'Anonymous'",
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: KColors.thirdColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: KColors.thirdColor),
                    ),
                    hintStyle: KTextStyles.fontMediumStyle.copyWith(
                      color: KColors.darkPlaceholderColor,
                      fontWeight: FontWeight.w300,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: KTextStyles.fontMediumStyle.copyWith(
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: KColors.thirdColorHover,
                    borderRadius: BorderRadius.circular(1000),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(1000),
                      splashColor: KColors.thirdColorHover,
                      onTap: () => Navigator.of(dialogContext).pop(true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 8,
                        ),
                        child: Text(
                          "Send",
                          style: KTextStyles.fontMediumStyle.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final registerWidget = Column(
      children: [
        InputField(
          key: const ValueKey('register_email'),
          controller: controller1,
          placeholderText: "Email",
          isRequired: true,
        ),
        SizedBox(height: 12),
        InputField(
          key: const ValueKey('register_phone'),
          controller: controller2,
          placeholderText: "Phone",
          type: 1,
          isRequired: true,
        ),
        SizedBox(height: 12),
        InputField(
          key: const ValueKey('register_password'),
          controller: controller3,
          placeholderText: "Password",
          type: 2,
          isRequired: true,
        ),
        SizedBox(height: 12),
        InputField(
          key: const ValueKey('register_rep_password'),
          type: 3,
          controller: controller4,
          matchController: controller3,
          placeholderText: "Repeat password",
          isRequired: true,
        ),
      ],
    );

    final loginWidget = Column(
      children: [
        InputField(
          key: const ValueKey('login_email'),
          controller: controller5,
          placeholderText: "Email",
        ),
        SizedBox(height: 12),
        InputField(
          key: const ValueKey('login_password'),
          controller: controller6,
          placeholderText: "Password",
          isOnLoginPage: true,
          type: 2,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePageUnregistered()),
              );
            }
          },
          icon: SvgPicture.asset(
            "assets/svgs/arrow_back.svg",
            width: 25,
            height: 14,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Center(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Sign up for best user experience",
                    softWrap: true,
                    textAlign: .center,
                    style: KTextStyles.fontBiggerStyle,
                  ),
                ),
                SizedBox(height: 22.0),

                ValueListenableBuilder<int>(
                  valueListenable: signUpInTabsNotifier,
                  builder: (context, signUpInTab, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: KColors.mainColor,
                        borderRadius: BorderRadiusGeometry.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => signUpInTabsNotifier.value = 0,
                              child: Container(
                                padding: .symmetric(
                                  horizontal: 54,
                                  vertical: 12,
                                ),
                                alignment: .center,
                                decoration: BoxDecoration(
                                  color: signUpInTab == 0
                                      ? KColors.mainColor
                                      : KColors.backgroundColor,
                                  borderRadius: signUpInTab == 1
                                      ? const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(20),
                                        )
                                      : const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                        ),
                                ),
                                child: Text(
                                  "Sign up",
                                  style: KTextStyles.fontSmallStyle.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => signUpInTabsNotifier.value = 1,
                              child: Container(
                                padding: .symmetric(
                                  horizontal: 54,
                                  vertical: 12,
                                ),
                                alignment: .center,
                                decoration: BoxDecoration(
                                  color: signUpInTab == 1
                                      ? KColors.mainColor
                                      : KColors.backgroundColor,
                                  borderRadius: signUpInTab == 0
                                      ? const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomLeft: Radius.circular(20),
                                        )
                                      : const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                        ),
                                ),
                                child: Text(
                                  "Sign in",
                                  style: KTextStyles.fontSmallStyle.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Container(
                  width: .infinity,
                  padding: EdgeInsetsGeometry.symmetric(
                    horizontal: 14.0,
                    vertical: 20.0,
                  ),
                  decoration: BoxDecoration(
                    color: KColors.mainColor,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(12.0),
                      bottomLeft: Radius.circular(12.0),
                    ),
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: signUpInTabsNotifier,
                    builder: (context, signUpInTab, child) {
                      return Center(
                        child: Column(
                          mainAxisSize: .min,
                          children: [
                            signUpInTab == 0 ? registerWidget : loginWidget,
                            SizedBox(height: 24),
                            Material(
                              color: KColors.thirdColorHover,
                              borderRadius: BorderRadius.circular(1000),
                              child: InkWell(
                                onTap: () async {
                                  if (isLoading) return;
                                  if (signUpInTab == 0) {
                                    final confirmed =
                                        await _showHowToAddressModal();
                                    if (!confirmed) return;
                                  }
                                  setState(() => isLoading = true);

                                  final auth = AppServices.auth;

                                  try {
                                    if (signUpInTab == 0) {
                                      final dial =
                                          countryNotifier.value.dialCode;
                                      final phoneRaw = controller2.text.trim();
                                      final phone = "$dial$phoneRaw";

                                      await auth.register(
                                        email: controller1.text,
                                        phone: phone,
                                        password: controller3.text,
                                        repeatPassword: controller4.text,
                                        howToAddress: controller7.text.trim(),
                                      );

                                      await auth.login(
                                        email: controller1.text,
                                        password: controller3.text,
                                      );
                                    } else {
                                      await auth.login(
                                        email: controller5.text,
                                        password: controller6.text,
                                      );
                                    }

                                    if (!mounted) return;

                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AuthGate(),
                                      ),
                                      (_) => false,
                                    );
                                  } catch (e) {
                                    debugPrint("Auth error: $e");
                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Authentication error. Please, retry.",
                                        ),
                                      ),
                                    );
                                  } finally {
                                    setState(() => isLoading = false);
                                  }
                                },
                                borderRadius: BorderRadius.circular(1000),
                                splashColor: KColors.thirdColorHover,
                                child: ValueListenableBuilder(
                                  valueListenable: signUpInTabsNotifier,
                                  builder: (context, signUpInTab, child) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 34,
                                        vertical: 8,
                                      ),
                                      child: isLoading
                                          ? Transform.scale(
                                              scale: 0.4,
                                              child: CircularProgressIndicator(
                                                color: Colors.black,
                                              ),
                                            )
                                          : Text(
                                              signUpInTab == 0
                                                  ? "Continue"
                                                  : "Send",
                                              style: KTextStyles.fontMediumStyle
                                                  .copyWith(
                                                    color: Colors.black,
                                                    fontWeight: .bold,
                                                  ),
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            if (signUpInTab == 1)
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => Container(
                                        child: Text(
                                          "This page is under construction.",
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                child: RichText(
                                  text: TextSpan(
                                    style: KTextStyles.fontSmallStyle.copyWith(
                                      height: 1,
                                    ),
                                    children: [
                                      const TextSpan(text: "Forgot password? "),
                                      TextSpan(
                                        text: "Click here",
                                        style: KTextStyles.fontSmallStyle
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24.0),
                RichText(
                  text: TextSpan(
                    style: KTextStyles.fontMediumStyle,
                    children: [
                      TextSpan(
                        text: "Before starting work, ",
                        style: KTextStyles.fontMediumStyle.copyWith(
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: "be sure to read",
                        style: KTextStyles.fontMediumStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: ":",
                        style: KTextStyles.fontMediumStyle.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: .symmetric(vertical: 8.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: KColors.secondaryColor,
                    borderRadius: .circular(12),
                  ),
                  constraints: BoxConstraints(maxWidth: 280),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip, size: 30, color: Colors.white),
                      Text(
                        "Privacy policy",
                        style: KTextStyles.fontSmallStyle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: KColors.secondaryColor,
                    borderRadius: .circular(12),
                  ),
                  constraints: BoxConstraints(maxWidth: 280),
                  padding: .symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.description, size: 30, color: Colors.white),
                      Text(
                        "Terms of use",
                        style: KTextStyles.fontSmallStyle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: KColors.secondaryColor,
                    borderRadius: .circular(12),
                  ),
                  constraints: BoxConstraints(maxWidth: 280),
                  padding: .symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 30, color: Colors.white),
                      Text(
                        "Instruction",
                        style: KTextStyles.fontSmallStyle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
