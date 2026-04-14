import 'package:flutter/material.dart';
import "../data/constrains_&_utils.dart";

class CountryDropdownCompact extends StatefulWidget {
  const CountryDropdownCompact({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 65,
    this.height = 48,
  });

  final Country value;
  final ValueChanged<Country> onChanged;
  final double width;
  final double height;

  @override
  State<CountryDropdownCompact> createState() => _CountryDropdownCompactState();
}

class _CountryDropdownCompactState extends State<CountryDropdownCompact> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Country>(
          value: widget.value,
          isExpanded: true,
          isDense: true,

          icon: const SizedBox.shrink(),

          dropdownColor: Colors.white,

          selectedItemBuilder: (context) {
            return countries.map((c) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.flag, style: const TextStyle(fontSize: 18)),
                    Text(
                      c.dialCode,
                      style: KTextStyles.fontSmallestStyle.copyWith(
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },

          items: countries.map((c) {
            return DropdownMenuItem<Country>(
              value: c,
              child: Row(
                children: [
                  Text(c.flag, style: KTextStyles.fontMediumBigStyle.copyWith(height: 1)),
                  const SizedBox(width: 10),
                  Text(
                    c.dialCode,
                    style: KTextStyles.fontMediumStyle.copyWith(height: 1),
                  ),
                ],
              ),
            );
          }).toList(),

          onChanged: (c) {
            if (c == null) return;
            widget.onChanged(c);
          },
        ),
      ),
    );
  }
}
