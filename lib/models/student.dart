/// A student / enrolled person in the attendance system.
class Student {
  const Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.department,
    required this.className,
    required this.role,
    this.email,
    this.phone,
    this.attendancePercent = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.enrolledFaces = 5,
  });

  final String id;
  final String name;
  final String rollNumber;
  final String department;
  final String className;
  final String role; // "Student" or "Employee"
  final String? email;
  final String? phone;
  final int attendancePercent;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int enrolledFaces;
}
