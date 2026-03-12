import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.instance.emergencyBannersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading notifications', style: GoogleFonts.poppins(color: AppColors.textGrey)),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 48, color: AppColors.surfaceGrey),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet.',
                    style: GoogleFonts.poppins(fontSize: 16, color: AppColors.textGrey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Someone';
              final bloodType = data['bloodType'] ?? 'Blood';
              final location = data['location'] ?? 'your area';
              final hospital = data['hospital'] ?? '';
              final contact = data['contact'] ?? '';
              
              DateTime? createdAt;
              if (data['createdAt'] is Timestamp) {
                createdAt = (data['createdAt'] as Timestamp).toDate();
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.criticalRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emergency_share_rounded, color: AppColors.criticalRed, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Emergency Request',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (createdAt != null)
                                Text(
                                  DateFormat('MMM d, h:mm a').format(createdAt),
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textLight),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$name needs $bloodType blood urgently at $location ${hospital.isNotEmpty ? "($hospital)" : ""}.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceGrey,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  bloodType,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.criticalRed,
                                  ),
                                ),
                              ),
                              if (contact.isNotEmpty) ...[
                                const Spacer(),
                                Icon(Icons.phone_rounded, size: 14, color: AppColors.textLight),
                                const SizedBox(width: 4),
                                Text(
                                  contact,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
