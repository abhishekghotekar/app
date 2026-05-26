import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../data/mock_data.dart';
import '../../models/student.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/user_avatar.dart';
import '../attendance/student_detail_screen.dart';
import 'add_user_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'All';

  static const _filters = ['All', 'Students', 'Employees', 'CSE', 'ECE', 'Mech'];

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_query != _search.text) {
        setState(() => _query = _search.text);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Student> get _filtered {
    return MockData.students.where((s) {
      final q = _query.toLowerCase();
      final matchesQuery = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.rollNumber.toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        'All' => true,
        'Students' => s.role == 'Student',
        'Employees' => s.role == 'Employee',
        _ => s.department == _filter,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  void _addUser() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddUserScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      hint: 'Search by name or ID',
                      prefixIcon: LucideIcons.search,
                      controller: _search,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  SecondaryButton(
                    label: 'Add',
                    icon: LucideIcons.plus,
                    fullWidth: false,
                    onPressed: _addUser,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _chip(_filters[i]),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.users,
                  title: 'No users found',
                  subtitle: 'Try a different search or filter.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _userCard(users[i]),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label) {
    final selected = _filter == label;
    return InkWell(
      onTap: () => setState(() => _filter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _userCard(Student s) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentDetailScreen(student: s),
        ),
      ),
      child: Row(
        children: [
          UserAvatar(name: s.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text('${s.rollNumber} · ${s.department}',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
