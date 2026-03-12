import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

class RequestBloodScreen extends StatefulWidget {
  const RequestBloodScreen({super.key});

  @override
  State<RequestBloodScreen> createState() => _RequestBloodScreenState();
}

class _RequestBloodScreenState extends State<RequestBloodScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController patientNameController = TextEditingController();
  final TextEditingController hospitalController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  String? selectedBloodGroup;
  String? selectedUrgency;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;

  final List<String> bloodGroups = [
    "A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"
  ];
  final List<Map<String, dynamic>> urgencies = [
    {
      'label': 'Critical (Immediate)',
      'color': AppColors.criticalRed,
      'icon': Icons.warning_rounded,
    },
    {
      'label': 'High (Within 24 hours)',
      'color': AppColors.warningOrange,
      'icon': Icons.priority_high_rounded,
    },
    {
      'label': 'Moderate',
      'color': AppColors.successGreen,
      'icon': Icons.check_circle_outline_rounded,
    },
  ];

  @override
  void dispose() {
    patientNameController.dispose();
    hospitalController.dispose();
    contactController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location acquired!', style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: AppColors.criticalRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submitBloodRequest() async {
    if (!_formKey.currentState!.validate() ||
        selectedBloodGroup == null ||
        selectedUrgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill out all required fields.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.criticalRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseService.instance.postBloodRequest(
        patientName: patientNameController.text.trim(),
        hospital: hospitalController.text.trim(),
        contact: contactController.text.trim(),
        bloodGroup: selectedBloodGroup!,
        urgency: selectedUrgency!,
        latitude: _latitude,
        longitude: _longitude,
      );

      // Notify all users about the new request
      NotificationService.instance.notifyAllUsers(
        title: "New Blood Request: $selectedBloodGroup",
        body: "$selectedBloodGroup needed at ${hospitalController.text}. Open app for details.",
        data: {
          'type': 'request',
          'urgency': selectedUrgency,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Blood request posted! Donors will be notified.',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to post request. Please try again.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.criticalRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.bloodtype_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Blood',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Connect with donors near you',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Patient Name *'),
                    _buildTextField(
                      hint: 'Enter patient full name',
                      controller: patientNameController,
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 18),

                    _sectionLabel('Hospital / Clinic *'),
                    _buildTextField(
                      hint: 'Hospital or clinic name',
                      controller: hospitalController,
                      icon: Icons.local_hospital_rounded,
                    ),
                    const SizedBox(height: 18),

                    _sectionLabel('Contact Number *'),
                    _buildTextField(
                      hint: 'Contact person phone number',
                      controller: contactController,
                      icon: Icons.phone_rounded,
                      inputType: TextInputType.phone,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 18),

                    _sectionLabel('Location (Recommended)'),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _latitude != null
                                  ? 'Location Acquired'
                                  : 'No location provided',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: _latitude != null ? AppColors.successGreen : AppColors.textLight,
                                fontWeight: _latitude != null ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _isFetchingLocation ? null : _getCurrentLocation,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: _isFetchingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _sectionLabel('Required Blood Group *'),
                    _buildDropdown(
                      hint: 'Select blood group',
                      icon: Icons.bloodtype_rounded,
                      items: bloodGroups,
                      value: selectedBloodGroup,
                      onChanged: (val) => setState(() => selectedBloodGroup = val),
                      validator: (val) => val == null ? 'Please select blood group' : null,
                    ),
                    const SizedBox(height: 18),

                    // Urgency level with color chips
                    _sectionLabel('Urgency Level *'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: urgencies.map((u) {
                        final isSelected = selectedUrgency == u['label'];
                        final Color chipColor = u['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(() => selectedUrgency = u['label'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? chipColor
                                  : chipColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: chipColor,
                                width: isSelected ? 0 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  u['icon'] as IconData,
                                  color: isSelected ? Colors.white : chipColor,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  u['label'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? Colors.white : chipColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (selectedUrgency == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          'Please select urgency level',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryRed,
                            ),
                          )
                        : CustomButton(
                            text: 'Post Blood Request',
                            icon: Icons.send_rounded,
                            onPressed: _submitBloodRequest,
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMedium,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      maxLength: maxLength,
      inputFormatters: maxLength != null
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
        counterText: maxLength != null ? '' : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (maxLength != null && v.length != maxLength) return 'Must be $maxLength digits';
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String hint,
    required IconData icon,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}