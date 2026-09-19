/// Fields collected by the post-signup student details wizard
/// (scope.md §5 "Registration" row).
class StudentDetails {
  const StudentDetails({
    required this.fullName,
    required this.phone,
    required this.primaryCampusId,
    required this.dob,
    required this.gender,
    required this.facultyYear,
    required this.residenceType,
    required this.address,
  });

  final String fullName;
  final String phone;
  final String primaryCampusId;
  final DateTime dob;
  final String gender;
  final String facultyYear;
  final String residenceType;
  final String address;
}

/// Gender options, including the explicit "prefer not to say" the scope
/// calls out.
const genderOptions = <String>[
  'Female',
  'Male',
  'Non-binary',
  'Prefer not to say',
];

/// `residence_type` values per scope.md §5.
const residenceTypeOptions = <String>[
  'NMU residence',
  'Off-campus Summerstrand',
  'Commuting',
];

const yearOfStudyOptions = <String>[
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
  'Postgraduate',
  'Other',
];

const relationshipOptions = <String>[
  'Parent',
  'Sibling',
  'Roommate',
  'Friend',
  'Partner',
  'Guardian',
  'Other',
];

/// blood_type options for the medical info card.
const bloodTypeOptions = <String>[
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
  'Unknown',
];

/// Structured view over the `students.medical_info` text column
/// (scope.md §5 "Medical info card"). The schema only has one column, so
/// this composes its fields into one formatted block on save and parses
/// that same format back out on load — shared by the student's view and
/// edit screens so there's a single place that knows the format.
class MedicalInfo {
  const MedicalInfo({
    this.bloodType,
    this.allergies = '',
    this.conditions = '',
    this.notes = '',
  });

  final String? bloodType;
  final String allergies;
  final String conditions;
  final String notes;

  factory MedicalInfo.parse(String? raw) {
    String? bloodType;
    var allergies = '';
    var conditions = '';
    var notes = '';
    if (raw != null && raw.isNotEmpty) {
      for (final line in raw.split('\n')) {
        if (line.startsWith('Blood type: ')) {
          final value = line.substring('Blood type: '.length).trim();
          if (bloodTypeOptions.contains(value)) bloodType = value;
        } else if (line.startsWith('Allergies: ')) {
          allergies = line.substring('Allergies: '.length);
        } else if (line.startsWith('Conditions: ')) {
          conditions = line.substring('Conditions: '.length);
        } else if (line.startsWith('Notes: ')) {
          notes = line.substring('Notes: '.length);
        }
      }
    }
    return MedicalInfo(
      bloodType: bloodType,
      allergies: allergies,
      conditions: conditions,
      notes: notes,
    );
  }

  String toRaw() {
    final lines = <String>[
      if (bloodType != null) 'Blood type: $bloodType',
      if (allergies.trim().isNotEmpty) 'Allergies: ${allergies.trim()}',
      if (conditions.trim().isNotEmpty) 'Conditions: ${conditions.trim()}',
      if (notes.trim().isNotEmpty) 'Notes: ${notes.trim()}',
    ];
    return lines.join('\n');
  }
}
