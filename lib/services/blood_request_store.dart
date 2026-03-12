/// A simple in-memory singleton store that holds all blood requests
/// submitted during the current app session.
class BloodRequestStore {
  BloodRequestStore._();
  static final BloodRequestStore instance = BloodRequestStore._();

  final List<BloodRequest> requests = [];

  void add(BloodRequest request) {
    requests.insert(0, request); // newest first
  }
}

class BloodRequest {
  final String patientName;
  final String hospital;
  final String contact;
  final String bloodGroup;
  final String urgency;
  final DateTime submittedAt;
  String status; // 'Pending' | 'Active' | 'Fulfilled'

  BloodRequest({
    required this.patientName,
    required this.hospital,
    required this.contact,
    required this.bloodGroup,
    required this.urgency,
    required this.submittedAt,
    this.status = 'Pending',
  });
}
