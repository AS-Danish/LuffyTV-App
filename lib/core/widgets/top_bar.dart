import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/theme/app_theme.dart';

class TopBar extends StatelessWidget {
  final String appName;
  final VoidCallback? onProfileTap;
  const TopBar({super.key, this.appName = 'LUFFY TV', this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentStart.withValues(alpha: .18),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/LuffyTVLogo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 11),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      appName,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    Text(
                      'Your anime, beautifully organized',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _TopBarButton(
          icon: Icons.notifications_none_rounded,
          label: 'Notifications',
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _TopBarButton(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _TopBarButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size(42, 42),
        backgroundColor: AppColors.surfaceRaised,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: Icon(icon, size: 20, color: AppColors.textSecondary),
    );
  }
}
