import 'package:flutter/material.dart';
import 'package:luffytv/core/theme/app_colors.dart';
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
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: AppColors.accentGradient,
                            image: const DecorationImage(
                              image: NetworkImage('https://i.pravatar.cc/150?img=11'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 100,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
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
                    Text(
                      'Premium Member',
                      style: TextStyle(color: AppColors.accentStart, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Menu Options
              _buildMenuTile(
                icon: Icons.person_outline_rounded,
                title: 'Account Settings',
                onTap: () {},
              ),
              _buildMenuTile(
                icon: Icons.download_rounded,
                title: 'Downloads',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DownloadsScreen()));
                },
              ),
              _buildMenuTile(
                icon: Icons.history_rounded,
                title: 'Watch History',
                onTap: () {},
              ),
              _buildMenuTile(
                icon: Icons.settings_outlined,
                title: 'App Settings',
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildMenuTile(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                iconColor: Colors.redAccent,
                textColor: Colors.redAccent,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.white).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(color: textColor ?? Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}
