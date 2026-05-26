enum AttendanceStatus { present, absent, late }

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
    }
  }
}

/// One day's attendance record for a student.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.department,
    required this.status,
    required this.date,
    this.timeIn,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String department;
  final AttendanceStatus status;
  final DateTime date;
  final DateTime? timeIn;
}
