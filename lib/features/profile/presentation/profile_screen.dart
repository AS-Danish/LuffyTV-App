import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
import 'package:luffytv/core/widgets/bouncing_button.dart';
import 'downloads_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120), // Leave room for nav bar
            children: [
              const SizedBox(height: 40),
              // Single Profile Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accentStart, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentStart.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                            image: const DecorationImage(
                              image: NetworkImage('https://i.pravatar.cc/150?img=11'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: BouncingButton(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 18),
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Monkey D. Luffy',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Premium Member',
                      style: TextStyle(color: AppColors.accentStart, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Settings Group
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildMenuTile(
                            context: context,
                            icon: Icons.person_outline_rounded,
                            title: 'Account Settings',
                            onTap: () {},
                          ),
                          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1, indent: 64),
                          _buildMenuTile(
                            context: context,
                            icon: Icons.download_rounded,
                            title: 'Downloads',
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DownloadsScreen()));
                            },
                          ),
                          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1, indent: 64),
                          _buildMenuTile(
                            context: context,
                            icon: Icons.history_rounded,
                            title: 'Watch History',
                            onTap: () {},
                          ),
                          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1, indent: 64),
                          _buildMenuTile(
                            context: context,
                            icon: Icons.settings_outlined,
                            title: 'App Settings',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Logout Group
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      ),
                      child: _buildMenuTile(
                        context: context,
                        icon: Icons.logout_rounded,
                        title: 'Log Out',
                        iconColor: Colors.redAccent,
                        textColor: Colors.redAccent,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // Ensures the whole row is clickable
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.white).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textColor ?? Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
