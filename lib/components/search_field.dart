// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:uconnecta/pages/driver_profile_page.dart';
import '../data/constrains.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:convert';

class SearchInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isOnMainPage;
  final FocusNode? focusNode;

  /// Called when a driver profile is successfully found (unregistered home page).
  /// Passes the found [DriverProfile]; called with null when the field is cleared
  /// or a new search is started.
  final void Function(DriverProfile? profile)? onProfileFound;

  const SearchInput({
    super.key,
    required this.controller,
    this.isOnMainPage = false,
    this.onProfileFound,
    this.focusNode,
  });

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final RegExp _carNumberRegex = RegExp(r'^[A-Z]{2}\d{4}[A-Z]{2}$');
  OverlayEntry? _tooltipEntry;
  String _errorText = "";
  bool? _isValid = false;
  bool _showSearchIcon = false;
  late final AnimationController _anim;
  bool _tooltipCLosed = false;
  bool loading = false;

  Future<Map<String, dynamic>> searchUser({
    String? carNumber,
    String? username,
  }) async {
    Uri? uri;

    if (carNumber != null && carNumber.isNotEmpty) {
      uri = Uri.parse(
        'https://uconnecta-backend.onrender.com/api/users/search/',
      ).replace(queryParameters: {'car_number': carNumber.toUpperCase()});
    } else if (username != null && username.isNotEmpty) {
      uri = Uri.parse(
        'https://uconnecta-backend.onrender.com/api/users/search/',
      ).replace(queryParameters: {'username': username});
    }

    if (uri == null) return {};

    debugPrint('REQUEST URI => $uri');

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Server responds too long. Try later.');
          },
        );

    if (response.statusCode == 404) {
      throw Exception('Driver not found');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Request failed: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 130),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTooltip();
    });

    widget.controller.addListener(_validate);
  }

  void _validate() {
    final raw = widget.controller.text;
    final value = raw.toUpperCase().trim();
    setState(() {
      _showSearchIcon = value.isEmpty ? false : true;
    });

    if (raw.startsWith("@")) {
      if (raw.length > 9 || raw.length < 9) {
        setState(() {
          _errorText = 'Invalid username';
          _isValid = false;
        });
      } else {
        setState(() {
          _errorText = "Valid username";
          _isValid = true;
        });
      }
      // Reset profile when typing
      widget.onProfileFound?.call(null);
      return;
    } else if (value.isEmpty) {
      setState(() {
        _errorText = "";
        _isValid = null;
      });
      widget.onProfileFound?.call(null);
      return;
    } else if (_carNumberRegex.hasMatch(value)) {
      setState(() {
        _errorText = 'Valid car number';
        _isValid = true;
      });
      // Auto-search when exactly 8 chars and looks like a car number
      if (widget.onProfileFound != null && value.length == 8) {
        _autoSearch(value);
      }
    } else {
      setState(() {
        _errorText = 'Invalid car number';
        _isValid = false;
      });
      widget.onProfileFound?.call(null);
    }
  }

  /// Fires automatically when the car-number reaches 8 valid characters.
  /// Only used when [widget.onProfileFound] is set (unregistered home page).
  Future<void> _autoSearch(String carNumber) async {
    if (loading) return;
    setState(() => loading = true);
    widget.onProfileFound?.call(null); // reset while loading

    try {
      final data = await searchUser(carNumber: carNumber);
      final profile = DriverProfile.fromJson(data);
      widget.onProfileFound?.call(profile);
      setState(() {
        _errorText = 'Valid car number';
        _isValid = true;
      });
    } catch (error) {
      widget.onProfileFound?.call(null);
      setState(() {
        _errorText = error.toString().replaceFirst('Exception: ', '');
        _isValid = false;
      });
      if (widget.isOnMainPage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showTooltip() {
    _tooltipEntry?.remove();

    _tooltipEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, 15),
            showWhenUnlinked: false,
            child: FadeTransition(
              opacity: _anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(
                  CurvedAnimation(parent: _anim, curve: Curves.easeOut),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: KColors.thirdColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(12),
                      ),
                      boxShadow: [KColors.mainBoxShadow],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Type @ to search by username',
                          style: KTextStyles.fontSmallStyle,
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            if (_tooltipCLosed) return;
                            _tooltipCLosed = true;
                            _hideTooltip();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: KColors.mainColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_tooltipEntry!);
    _anim.forward(from: 0);

    Future.delayed(const Duration(seconds: 10), () {
      _hideTooltip();
    });
  }

  Future<void> _hideTooltip() async {
    if (_tooltipEntry == null) return;
    if (!mounted) return;

    await _anim.reverse();
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  @override
  void dispose() {
    _tooltipEntry?.remove();
    _anim.dispose();
    widget.controller.removeListener(_validate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IconButton searchIcon = IconButton(
      icon: SvgPicture.asset(
        'assets/svgs/search_icon.svg',
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(
          _isValid == true ? KColors.thirdColorHover : KColors.placeholderColor,
          BlendMode.srcIn,
        ),
      ),
      constraints: const BoxConstraints(),
      onPressed: () async {
        String q = widget.controller.text.trim();
        _validate();
        if (_isValid != true) return;
        bool searchUsername = false;
        if (q.startsWith("@")) {
          searchUsername = true;
          q = q.substring(1);
        }
        try {
          setState(() {
            loading = true;
          });
          Map<String, dynamic> data = !searchUsername
              ? await searchUser(carNumber: q)
              : await searchUser(username: q);

          final profile = DriverProfile.fromJson(data);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverProfilePage(profile: profile),
            ),
          );
          setState(() {
            widget.controller.value = TextEditingValue.empty;
            loading = false;
            _errorText = "";
            _isValid = null;
            _showSearchIcon = false;
          });
        } catch (error) {
          setState(() {
            _errorText = error.toString().replaceFirst('Exception: ', '');
            loading = false;
            _isValid = false;
            _showSearchIcon = true;
          });
          if (widget.isOnMainPage) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.toString().replaceFirst('Exception: ', '')),
              ),
            );
          }
        }
      },
    );
    Widget prefix_icon = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: Center(
              child: CircularProgressIndicator(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                strokeWidth: 1.5,
                color: KColors.thirdColorHover,
              ),
            ),
          )
        : searchIcon;
    if (!_showSearchIcon && widget.isOnMainPage && !loading) {
      prefix_icon = IconButton(
        icon: SvgPicture.asset(
          'assets/svgs/cam_icon.svg',
          width: 19,
          height: 18,
          colorFilter: ColorFilter.mode(
            KColors.thirdColorHover,
            BlendMode.srcIn,
          ),
        ),
        onPressed: () {},
      );
    }

    final Column content = Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: widget.isOnMainPage ? 35.0 : null,
          child: TextField(
            focusNode: widget.focusNode,
            controller: widget.controller,
            maxLength: widget.controller.text.startsWith("@") ? 9 : 8,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => null,
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Search: XX----XX',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: _isValid == false
                    ? const BorderSide(color: Colors.redAccent, width: 1.5)
                    : _isValid == true
                    ? const BorderSide(color: Colors.green, width: 1.5)
                    : BorderSide.none,
                borderRadius: BorderRadius.circular(999),
              ),
              hintStyle: !widget.isOnMainPage
                  ? KTextStyles.fontMediumBigStyle.copyWith(
                      color: KColors.thirdColor,
                    )
                  : KTextStyles.fontSmallStyle.copyWith(
                      color: KColors.thirdColor,
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 9,
              ),
              filled: true,
              fillColor: KColors.mainColor,
              prefixIcon: prefix_icon,
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: KColors.thirdColor,
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onProfileFound?.call(null);
                        setState(() {});
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            style: !widget.isOnMainPage
                ? KTextStyles.fontMediumBigStyle.copyWith(
                    color: KColors.thirdColorHover,
                  )
                : KTextStyles.fontSmallStyle.copyWith(
                    color: KColors.thirdColorHover,
                  ),
            onTap: () {
              if (_tooltipCLosed) return;
              _showTooltip();
            },
          ),
        ),
        _errorText.isNotEmpty && !widget.isOnMainPage
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _errorText,
                  key: ValueKey(_errorText),
                  textAlign: TextAlign.center,
                  style: !widget.isOnMainPage
                      ? KTextStyles.fontSmallStyle.copyWith(
                          color: _isValid == true
                              ? KColors.goodColor
                              : _isValid == false
                              ? KColors.badColor
                              : KColors.placeholderColor,
                        )
                      : KTextStyles.fontSmallestStyle.copyWith(
                          color: _isValid == true
                              ? KColors.goodColor
                              : _isValid == false
                              ? KColors.badColor
                              : KColors.placeholderColor,
                        ),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );

    return !widget.isOnMainPage
        ? CompositedTransformTarget(link: _link, child: content)
        : content;
  }
}
