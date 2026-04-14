import 'package:flutter/material.dart';
import '../data/constrains_&_utils.dart';

class SortTab extends StatelessWidget {
  const SortTab({
    super.key,
    required this.title,
    required this.notifier,
    required this.index,
  });
  final String title;
  final ValueNotifier notifier;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KColors.thirdColorHover,
      borderRadius: BorderRadius.circular(1000),
      child: InkWell(
        onTap: () {
          notifier.value = index;
        },
        borderRadius: BorderRadius.circular(1000),
        splashColor: KColors.thirdColorHover,
        child: Padding(
          padding: const EdgeInsetsGeometry.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            title,
            style: KTextStyles.fontSmallStyle.copyWith(
              color: Colors.black,
              height: 1,
              fontWeight: .bold,
            ),
          ),
        ),
      ),
    );
  }
}
