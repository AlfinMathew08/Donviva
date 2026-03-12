import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart';
import '../services/user_store.dart';
import '../theme/app_colors.dart';

// Keep the EmergencyBanner model for backward compatibility with home_screen dialogs
class EmergencyBanner {
  final String name;
  final int age;
  final String bloodType;
  final String hospital;
  final String location;
  final String contact;

  const EmergencyBanner({
    required this.name,
    required this.age,
    required this.bloodType,
    required this.hospital,
    required this.location,
    required this.contact,
  });
}

class EmergencyBannerManager extends StatelessWidget {
  // initialBanners kept for API compatibility but ignored — Firestore is the source
  final List<EmergencyBanner> initialBanners;
  const EmergencyBannerManager({
    super.key,
    this.initialBanners = const [],
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.instance.emergencyBannersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(
                image: AssetImage('assets/hand_donation.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              "❤️ Everyone is safe today!\nKeep donating to save more lives.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return _BannerCarousel(docs: docs);
      },
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> docs;
  const _BannerCarousel({required this.docs});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  int _currentIndex = 0;
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = widget.docs;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: docs.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              return GestureDetector(
                onTap: () => _showBannerDialog(context, data, docId),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: const DecorationImage(
                      image: AssetImage('assets/hand_donation.png'),
                      fit: BoxFit.cover,
                      colorFilter:
                          ColorFilter.mode(Colors.black54, BlendMode.darken),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.criticalRed,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'URGENT • ${data['bloodType'] ?? ''}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "${data['name'] ?? ''}, ${data['age'] ?? ''} urgently needs blood",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_hospital_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              data['hospital'] ?? '',
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
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(docs.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentIndex == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentIndex == index
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

  void _showBannerDialog(
      BuildContext context, Map<String, dynamic> data, String docId) {
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
              child: const Icon(Icons.emergency_share_rounded,
                  color: AppColors.primaryRed, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Urgent: ${data['name'] ?? ''}",
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(Icons.bloodtype_rounded, 'Blood Type', data['bloodType'] ?? ''),
            _row(Icons.person_rounded, 'Age', '${data['age'] ?? ''}'),
            _row(Icons.local_hospital_rounded, 'Hospital', data['hospital'] ?? ''),
            _row(Icons.location_on_rounded, 'Location', data['location'] ?? ''),
            _row(Icons.phone_rounded, 'Contact', data['contact'] ?? ''),
          ],
        ),
        actions: [
          if (data['latitude'] != null && data['longitude'] != null)
            TextButton(
              onPressed: () async {
                final lat = data['latitude'];
                final lng = data['longitude'];
                final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                try {
                  final launched = await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open map.', style: GoogleFonts.poppins())),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open map.', style: GoogleFonts.poppins())),
                    );
                  }
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_rounded, color: AppColors.successGreen, size: 16),
                  const SizedBox(width: 4),
                  Text('Map', style: GoogleFonts.poppins(color: AppColors.successGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (UserStore.instance.isAdmin)
            TextButton(
              onPressed: () async {
                await FirebaseService.instance.deleteEmergencyBanner(docId);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Delete',
                  style: GoogleFonts.poppins(color: AppColors.criticalRed)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryRed),
          const SizedBox(width: 10),
          Text('$label: ',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style:
                    GoogleFonts.poppins(fontSize: 13, color: AppColors.textGrey)),
          ),
        ],
      ),
    );
  }
}