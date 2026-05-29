enum AttendanceStatus { present, absent, late, working }

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.working:
        return 'Working';
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

  factory AttendanceRecord.fromApiJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim().isNotEmpty
        ? '$firstName $lastName'.trim()
        : 'Unknown';

    final deptObj = user['department'] as Map<String, dynamic>?;
    final deptName = deptObj != null
        ? (deptObj['name']?.toString() ?? 'General')
        : 'General';

    final apiStatus = json['status']?.toString() ?? 'A';
    final isLate = json['is_late'] as bool? ?? false;

    AttendanceStatus status = AttendanceStatus.absent;
    if (apiStatus == 'P') {
      status = isLate ? AttendanceStatus.late : AttendanceStatus.present;
    } else if (apiStatus == 'W') {
      status = AttendanceStatus.working;
    }

    final dateStr = json['date_in_iso_format']?.toString() ?? '';
    DateTime parsedDate = DateTime.now();
    if (dateStr.isNotEmpty) {
      try {
        String formattedStr = dateStr;
        if (!formattedStr.contains('Z') &&
            !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(formattedStr)) {
          formattedStr += 'Z';
        }
        parsedDate = DateTime.parse(formattedStr).toLocal();
      } catch (_) {}
    }

    final inTimeStr = json['in_time']?.toString() ?? '';
    DateTime? parsedInTime;
    if (inTimeStr.isNotEmpty) {
      try {
        String formattedStr = inTimeStr;
        if (!formattedStr.contains('Z') &&
            !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(formattedStr)) {
          formattedStr += 'Z';
        }
        parsedInTime = DateTime.parse(formattedStr).toLocal();
      } catch (_) {}
    }

    final userId = user['id']?.toString() ?? json['user_id']?.toString() ?? '';
    // Use short id segment or user_availability as part of dummy employee id if needed
    final rollNo = userId.length >= 8
        ? 'EMP-${userId.substring(0, 4).toUpperCase()}'
        : 'EMP-001';

    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId: userId,
      studentName: fullName,
      rollNumber: rollNo,
      department: deptName,
      status: status,
      date: parsedDate,
      timeIn: parsedInTime,
    );
  }
}
