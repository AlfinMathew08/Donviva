import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../services/user_store.dart';
import '../services/firebase_service.dart';
import 'profile_screen.dart';
import 'donate_blood_screen.dart';
import 'request_blood_screen.dart';
import 'my_requests_screen.dart';
import 'emergency_banner_manager.dart';
import 'post_campaign_screen.dart';
import 'chatbot_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _currentCampaign = 0;
  late AnimationController _pulseController;


  final List<Map<String, String>> campaigns = [
    {
      "title": "Mega Blood Drive",
      "location": "Bangalore City Hall",
      "date": "25 Oct 2025",
    },
    {
      "title": "Community Donor Day",
      "location": "Delhi Red Cross",
      "date": "30 Oct 2025",
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadUser();
  }

  void _loadUser() async {
    await FirebaseService.instance.fetchUserProfile();
    if (mounted) setState(() {}); // Trigger rebuild to update UI if needed
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: _currentIndex == 0 ? _buildFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: SafeArea(
        child: _currentIndex == 0 ? _homeContent() : const ProfileScreen(),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFAB() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.1;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Pulsing ring
            Transform.scale(
              scale: scale,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.criticalRed.withValues(alpha: 0.22),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: GestureDetector(
        onTap: _showEmergencyDialog,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 28),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SOS',
                        style: GoogleFonts.poppins(
                          fontSize: 6,
                          fontWeight: FontWeight.w800,
                          color: AppColors.criticalRed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              // Center FAB label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    'Emergency',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.criticalRed,
                    ),
                  ),
                ],
              ),
              _navItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryRed.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: selected ? AppColors.primaryRed : AppColors.textGrey,
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.primaryRed : AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGradientHeader(),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emergency Banner
                const EmergencyBannerManager(),
                const SizedBox(height: 24),

                // Info boxes
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showNextDonationDialog,
                        child: _infoCard(
                          title: "Next Donation",
                          subtitle: "Oct 20, 2025",
                          icon: Icons.favorite_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFD94F4F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showUpcomingAppointmentDialog,
                        child: _infoCard(
                          title: "Appointment",
                          subtitle: "Oct 25 • City Hospital",
                          icon: Icons.calendar_today_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9F43), Color(0xFFFF6B3D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _featureCard(
                        title: "Donate\nBlood",
                        icon: Icons.volunteer_activism_rounded,
                        gradientColors: const [Color(0xFFFF6B6B), Color(0xFFD94F4F)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DonateBloodScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _featureCard(
                        title: "Request\nBlood",
                        icon: Icons.bloodtype_rounded,
                        gradientColors: const [Color(0xFFFF9F43), Color(0xFFE67E22)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RequestBloodScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _featureCard(
                        title: "My\nActivity",
                        icon: Icons.auto_graph_rounded,
                        gradientColors: const [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyRequestsScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _featureCard(
                        title: "AI\nMatch",
                        icon: Icons.psychology_alt_rounded,
                        gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatbotScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Campaigns
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Campaigns & Drives',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final newCampaign = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PostCampaignScreen(),
                          ),
                        );
                        if (newCampaign != null) {
                          setState(() {
                            campaigns.insert(
                              0,
                              newCampaign as Map<String, String>,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              color: AppColors.primaryRed,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Post',
                              style: GoogleFonts.poppins(
                                color: AppColors.primaryRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildCampaignSection(),
                const SizedBox(height: 28),

                // Stats
                _buildStatsCard(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          // App Logo
          Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day, ${UserStore.instance.name}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You make the difference.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignSection() {
    if (campaigns.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.surfaceGrey,
        ),
        alignment: Alignment.center,
        child: Text(
          'No active campaigns yet.\nBe the first to organize one!',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textGrey,
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            itemCount: campaigns.length,
            controller: PageController(viewportFraction: 0.92),
            onPageChanged: (index) =>
                setState(() => _currentCampaign = index),
            itemBuilder: (_, index) {
              final c = campaigns[index];
              return GestureDetector(
                onTap: () => _showCampaignDetails(c),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: AppColors.heroGradient,
                    image: const DecorationImage(
                      image: AssetImage('assets/banner.png'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Color(0x99000000),
                        BlendMode.darken,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        c['title']!,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c['location']!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c['date']!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(campaigns.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentCampaign == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentCampaign == index
                    ? AppColors.primaryRed
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFFF5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.lightRed,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statTile(label: 'Lives Saved', value: '12', icon: Icons.favorite_rounded),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.lightRed,
          ),
          Expanded(
            child: _statTile(label: 'Total Donations', value: '25', icon: Icons.volunteer_activism_rounded),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryRed, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryRed,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────
  void _showEmergencyDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    String? selectedBloodGroup;
    final hospitalController = TextEditingController();
    final locationController = TextEditingController();
    final contactController = TextEditingController();

    double? latitude;
    double? longitude;
    bool isFetchingLocation = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emergency_share_rounded, color: AppColors.primaryRed, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Emergency Request',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('Patient Name', nameController, Icons.person_rounded),
              _dialogField('Age', ageController, Icons.cake_rounded, keyboardType: TextInputType.number),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<String>(
                  value: selectedBloodGroup,
                  items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedBloodGroup = val),
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
                  decoration: InputDecoration(
                    labelText: 'Blood Type',
                    prefixIcon: const Icon(Icons.bloodtype_rounded, color: AppColors.primaryRed, size: 18),
                    filled: true,
                    fillColor: AppColors.surfaceGrey,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4)),
                  ),
                ),
              ),
              _dialogField('Hospital', hospitalController, Icons.local_hospital_rounded),
              _dialogField('Location / City', locationController, Icons.location_on_rounded),
              _dialogField(
                'Contact Number', 
                contactController, 
                Icons.phone_rounded, 
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: isFetchingLocation
                    ? null
                    : () async {
                        setState(() => isFetchingLocation = true);
                        try {
                          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled) throw Exception('Location disabled');
                          LocationPermission permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.denied) {
                              throw Exception('Permissions denied');
                            }
                          }
                          if (permission == LocationPermission.deniedForever) {
                            throw Exception('Permissions permanently denied');
                          }
                          Position position = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high);
                          setState(() {
                            latitude = position.latitude;
                            longitude = position.longitude;
                            isFetchingLocation = false;
                          });
                        } catch (e) {
                          setState(() => isFetchingLocation = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString(), style: GoogleFonts.poppins())),
                            );
                          }
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: latitude != null ? AppColors.successGreen.withValues(alpha: 0.1) : AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: latitude != null ? AppColors.successGreen : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        latitude != null ? Icons.check_circle_rounded : Icons.my_location_rounded,
                        color: latitude != null ? AppColors.successGreen : AppColors.primaryRed,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isFetchingLocation
                            ? 'Fetching Location...'
                            : (latitude != null ? 'Location Acquired' : 'Get Current Location'),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: latitude != null ? AppColors.successGreen : AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textGrey),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final name = nameController.text.trim();
              final age = int.tryParse(ageController.text.trim()) ?? 0;
              final hospital = hospitalController.text.trim();
              final location = locationController.text.trim();
              final contact = contactController.text.trim();
              if (name.isEmpty || selectedBloodGroup == null) return;
              Navigator.pop(context);
              await FirebaseService.instance.addEmergencyBanner(
                name: name,
                age: age,
                bloodType: selectedBloodGroup!,
                hospital: hospital,
                location: location,
                contact: contact,
                latitude: latitude,
                longitude: longitude,
              );
              
              // Notify all users about the emergency
              NotificationService.instance.notifyAllUsers(
                title: "🚨 URGENT: $selectedBloodGroup Blood Needed!",
                body: "$name urgently needs $selectedBloodGroup at $hospital. Tap to help.",
                data: {
                  'type': 'emergency',
                  'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
          );
        },
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: maxLength != null
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          counterText: maxLength != null ? '' : null,
          prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 18),
          filled: true,
          fillColor: AppColors.surfaceGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4),
          ),
        ),
      ),
    );
  }

  void _showCampaignDetails(Map<String, String> campaign) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          campaign['title']!,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow(Icons.location_on_rounded, campaign['location']!),
            const SizedBox(height: 8),
            _detailRow(Icons.calendar_today_rounded, campaign['date']!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryRed, size: 18),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 14)),
      ],
    );
  }

  void _showNextDonationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Next Donation Eligibility',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You are eligible to donate blood on 20 Oct 2025.',
          style: GoogleFonts.poppins(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: GoogleFonts.poppins(color: AppColors.primaryRed)),
          ),
        ],
      ),
    );
  }

  void _showUpcomingAppointmentDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Upcoming Appointment',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You have an appointment on 25 Oct 2025 at City Hospital.',
          style: GoogleFonts.poppins(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: GoogleFonts.poppins(color: AppColors.primaryRed)),
          ),
        ],
      ),
    );
  }
}