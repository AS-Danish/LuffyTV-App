import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class TopBar extends StatelessWidget {
  final String appName;
  const TopBar({super.key, this.appName = 'LuffyTV'});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(gradient: AppColors.accentGradient, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              appName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
            color: AppColors.surface,
          ),
          child: const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20),
        ),
      ],
    );
  }
}
