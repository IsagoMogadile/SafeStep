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
