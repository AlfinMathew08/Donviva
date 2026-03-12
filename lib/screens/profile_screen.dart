import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import 'welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await FirebaseService.instance.fetchUserProfile();
    if (mounted) {
      setState(() {
        _userData = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }

    final user = _userData ?? {};
    final name = user['name'] as String? ?? FirebaseService.instance.currentUser?.displayName ?? 'Donor';
    final email = user['email'] as String? ?? FirebaseService.instance.currentUser?.email ?? '';
    final phone = user['phone'] as String? ?? '';
    final age = user['age'] as String? ?? '';
    final gender = user['gender'] as String? ?? '';
    final bloodGroup = user['bloodGroup'] as String? ?? '';
    final location = user['location'] as String? ?? '';
    final donations = (user['donationCount'] as int?) ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 32),
            child: Column(
              children: [
                // Avatar with initial
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: GoogleFonts.poppins(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Name
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),

                // Email or phone
                if (email.isNotEmpty || phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email.isNotEmpty ? email : phone,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Quick badge row: blood group + location
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (bloodGroup.isNotEmpty)
                      _heroBadge(
                        icon: Icons.bloodtype_rounded,
                        label: bloodGroup,
                      ),
                    if (bloodGroup.isNotEmpty && location.isNotEmpty)
                      const SizedBox(width: 10),
                    if (location.isNotEmpty)
                      _heroBadge(
                        icon: Icons.location_on_rounded,
                        label: location,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Personal Info card ──────────────────────────────
                if (age.isNotEmpty ||
                    gender.isNotEmpty ||
                    bloodGroup.isNotEmpty ||
                    location.isNotEmpty) ...[
                  _sectionTitle('Personal Details'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (age.isNotEmpty)
                          _infoRow(
                            icon: Icons.cake_rounded,
                            iconColor: const Color(0xFFFF6B6B),
                            label: 'Age',
                            value: '$age years',
                          ),
                        if (gender.isNotEmpty)
                          _infoRow(
                            icon: Icons.wc_rounded,
                            iconColor: const Color(0xFF6C63FF),
                            label: 'Gender',
                            value: gender,
                          ),
                        if (bloodGroup.isNotEmpty)
                          _infoRow(
                            icon: Icons.bloodtype_rounded,
                            iconColor: AppColors.primaryRed,
                            label: 'Blood Group',
                            value: bloodGroup,
                            valueBold: true,
                            valueColor: AppColors.primaryRed,
                          ),
                        if (phone.isNotEmpty)
                          _infoRow(
                            icon: Icons.phone_android_rounded,
                            iconColor: AppColors.successGreen,
                            label: 'Phone',
                            value: phone,
                            isLast: location.isEmpty,
                          ),
                        if (location.isNotEmpty)
                          _infoRow(
                            icon: Icons.location_on_rounded,
                            iconColor: AppColors.warningOrange,
                            label: 'Location',
                            value: location,
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Stats card ──────────────────────────────────────
                _sectionTitle('My Stats'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          icon: Icons.volunteer_activism_rounded,
                          iconColor: AppColors.primaryRed,
                          value: '$donations',
                          label: 'Donations',
                        ),
                      ),
                      Container(
                          width: 1, height: 48, color: AppColors.lightRed),
                      Expanded(
                        child: _statTile(
                          icon: Icons.favorite_rounded,
                          iconColor: const Color(0xFFFF6B6B),
                          value: '${donations * 3}',
                          label: 'Lives Saved',
                        ),
                      ),
                      Container(
                          width: 1, height: 48, color: AppColors.lightRed),
                      Expanded(
                        child: StreamBuilder(
                          stream: FirebaseService.instance.myBloodRequestsStream(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return _statTile(
                              icon: Icons.bloodtype_rounded,
                              iconColor: AppColors.warningOrange,
                              value: '$count',
                              label: 'Requests',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Settings ────────────────────────────────────────
                _sectionTitle('Settings'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _settingsTile(
                        icon: Icons.edit_rounded,
                        iconBg: const Color(0xFF6C63FF),
                        title: 'Edit Profile',
                        onTap: () async {
                          if (_userData == null) return;
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(initialData: _userData!),
                            ),
                          );
                          if (result == true) {
                            _loadProfile();
                          }
                        },
                      ),
                      _divider(),
                      _settingsTile(
                        icon: Icons.lock_outline_rounded,
                        iconBg: AppColors.warningOrange,
                        title: 'Change Password',
                        onTap: () async {
                          final user = FirebaseService.instance.currentUser;
                          if (user?.email != null) {
                            try {
                              await FirebaseService.instance
                                  .sendPasswordReset(user!.email!);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Password reset link sent to ${user.email}',
                                      style: GoogleFonts.poppins(fontSize: 13)),
                                  backgroundColor: AppColors.successGreen,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error: ${e.toString()}',
                                      style: GoogleFonts.poppins(fontSize: 13)),
                                  backgroundColor: AppColors.criticalRed,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      _divider(),
                      _settingsTile(
                        icon: Icons.notifications_none_rounded,
                        iconBg: AppColors.successGreen,
                        title: 'Notifications',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      _settingsTile(
                        icon: Icons.help_outline_rounded,
                        iconBg: const Color(0xFF11998E),
                        title: 'Help & Support',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Help & Support coming soon!', style: GoogleFonts.poppins(fontSize: 13)),
                              backgroundColor: AppColors.primaryRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      _settingsTile(
                        icon: Icons.logout_rounded,
                        iconBg: AppColors.criticalRed,
                        title: 'Logout',
                        titleColor: AppColors.criticalRed,
                        onTap: () => _confirmLogout(context),
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                // App Logo and version info at the bottom
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Donviva v1.0.0',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero badge chip ─────────────────────────────────────────────────
  static Widget _heroBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool valueBold = false,
    Color? valueColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight:
                      valueBold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor ?? AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.surfaceGrey,
          ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isLast ? Radius.zero : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconBg, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? AppColors.textDark,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: titleColor ?? AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.surfaceGrey,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.primaryRed, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.criticalRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await FirebaseService.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
