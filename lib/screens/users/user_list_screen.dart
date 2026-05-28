import 'package:flutter/material.dart';

import '../../models/api_user.dart';
import '../../services/face_register_api.dart';
import '../../services/user_list_api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/secondary_button.dart';
import 'add_user_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  final _search = TextEditingController();
  String _query      = '';
  String _regFilter  = 'all'; // 'all' | 'register' | 'unregister'
  String _deptFilter = 'All'; // 'All' | 'CSE' | 'ECE' | ...

  List<ApiUser> _allUsers  = [];
  bool   _loading = false;
  bool   _firstLoad = true;
  String? _error;

  int _registeredCount = 0;
  int _unregisteredCount = 0;

  static const _deptFilters = ['All', 'CSE', 'ECE', 'Mech', 'Faculty', 'Admin'];

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
    _loadUsers();
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    if (_query != _search.text) setState(() => _query = _search.text);
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  Future<void> _loadUsers({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });

    try {
      final res = await UserListApi.fetchUsers();
      final fetched = res.users;

      if (mounted) {
        setState(() {
          _allUsers  = fetched;
          _registeredCount = fetched.where((u) => u.isRegistered).length;
          _unregisteredCount = fetched.where((u) => !u.isRegistered).length;
          _loading   = false;
          _firstLoad = false;
          _error     = null;
        });
      }
    } on UserListException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Filtered list ─────────────────────────────────────────────────────────
  List<ApiUser> get _filtered {
    return _allUsers.where((u) {
      // Registration filter (server already filtered, keeping it is safe)
      if (_regFilter == 'register'   && !u.isRegistered) return false;
      if (_regFilter == 'unregister' && u.isRegistered)  return false;

      // Department filter
      if (_deptFilter != 'All') {
        final dept = (u.department ?? '').toLowerCase();
        if (dept != _deptFilter.toLowerCase()) return false;
      }

      // Search
      final q = _query.toLowerCase();
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
             (u.department ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // ── Add user ──────────────────────────────────────────────────────────────
  Future<void> _addUser() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddUserScreen()),
    );
    // Refresh silently after returning from add screen
    _loadUsers(silent: true);
  }

  // ── Unregister All ────────────────────────────────────────────────────────
  Future<void> _unregisterAll() async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle,
                color: AppColors.danger, size: 22),
            const SizedBox(width: 8),
            Text('Unregister All', style: AppTextStyles.bodyStrong),
          ],
        ),
        content: Text(
          'This will delete face data for ALL active users.\nThis action cannot be undone.',
          style: AppTextStyles.caption,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unregister All'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Progress bottom sheet
    int _done = 0;
    int _total = 0;
    String? _lastError;
    bool _started = false;
    bool _finished = false;
    UnregisterAllResult? _result;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (_, setSheet) {
            // Kick off the operation only once
            if (!_started) {
              _started = true;
              FaceRegisterApi.unregisterAll(
                onProgress: (done, total, error) {
                  setSheet(() {
                    _done = done;
                    _total = total;
                    _lastError = error;
                  });
                },
              ).then((result) {
                setSheet(() {
                  _result = result;
                  _finished = true;
                });
              }).catchError((e) {
                setSheet(() {
                  _lastError = e.toString();
                  _finished = true;
                });
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  if (!_finished) ...[
                    // In-progress
                    Text(
                      'Unregistering users…',
                      style: AppTextStyles.bodyStrong,
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _total > 0 ? _done / _total : null,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _total == 0
                          ? 'Fetching user list…'
                          : '$_done / $_total users processed',
                      style: AppTextStyles.caption,
                    ),
                    if (_lastError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '⚠ $_lastError',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ] else ...[
                    // Done
                    Icon(
                      _result != null && _result!.failed == 0
                          ? LucideIcons.checkCircle
                          : LucideIcons.alertCircle,
                      size: 48,
                      color: _result != null && _result!.failed == 0
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _result != null
                          ? '${_result!.succeeded} / ${_result!.total} unregistered'
                          : _lastError ?? 'Unknown error',
                      style: AppTextStyles.bodyStrong,
                      textAlign: TextAlign.center,
                    ),
                    if (_result != null && _result!.hasErrors) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_result!.failed} failed — check logs',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    // Refresh the list after closing
    _loadUsers(silent: true);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search + Add
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      hint: 'Search by name or ID',
                      prefixIcon: LucideIcons.search,
                      controller: _search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SecondaryButton(
                    label: 'Add',
                    icon: LucideIcons.plus,
                    fullWidth: false,
                    onPressed: _addUser,
                  ),
                  const SizedBox(width: 6),
                  // Unregister-all button
                  Tooltip(
                    message: 'Unregister all users',
                    child: InkWell(
                      onTap: _loading ? null : _unregisterAll,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.userX,
                          size: 18,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Registered / Unregistered pills
              if (!_firstLoad)
                Row(
                  children: [
                    _regPill(
                      label: '$_registeredCount Registered',
                      icon: LucideIcons.checkCircle,
                      value: 'register',
                      activeColor: AppColors.success,
                      bg: AppColors.successBg,
                    ),
                    const SizedBox(width: 8),
                    _regPill(
                      label: '$_unregisteredCount Unregistered',
                      icon: LucideIcons.alertCircle,
                      value: 'unregister',
                      activeColor: AppColors.warning,
                      bg: AppColors.warningBg,
                    ),
                    const Spacer(),
                    // Refresh button
                    InkWell(
                      onTap: _loading ? null : _loadUsers,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textMuted,
                                ),
                              )
                            : const Icon(LucideIcons.refresh,
                                size: 18, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),

              // Department chips
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _deptFilters.length,
                  separatorBuilder: (_, sep) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _deptChip(_deptFilters[i]),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    // First load spinner
    if (_firstLoad && _loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Loading users…', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    // Error state
    if (_error != null && _allUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                'Failed to load users',
                style: AppTextStyles.bodyStrong,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(LucideIcons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final users = _filtered;

    if (users.isEmpty) {
      return EmptyState(
        icon: _regFilter == 'unregister'
            ? LucideIcons.checkCircle
            : LucideIcons.users,
        title: _regFilter == 'unregister'
            ? 'All faces registered!'
            : 'No users found',
        subtitle: _regFilter == 'unregister'
            ? 'Every user has face photos enrolled.'
            : 'Try a different search or filter.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: users.length,
        separatorBuilder: (_, sep) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _userCard(users[i]),
      ),
    );
  }

  // ── Registration pill ──────────────────────────────────────────────────────
  Widget _regPill({
    required String label,
    required IconData icon,
    required String value,
    required Color activeColor,
    required Color bg,
  }) {
    final active = _regFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _regFilter = active ? 'all' : value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? activeColor
                : activeColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? Colors.white : activeColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: active ? Colors.white : activeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Department chip ────────────────────────────────────────────────────────
  Widget _deptChip(String label) {
    final selected = _deptFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _deptFilter = label;
          if (label == 'All') {
            _regFilter = 'all';
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  // ── User card ──────────────────────────────────────────────────────────────
  Widget _userCard(ApiUser u) {
    final registered = u.isRegistered;

    return AppCard(
      child: Row(
        children: [
          // Avatar circle
          _Avatar(initials: u.initials),
          const SizedBox(width: 12),

          // Name + ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName, style: AppTextStyles.bodyStrong),
                if (u.department != null && u.department!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    u.department!,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),

          // Face badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: registered
                  ? AppColors.successBg
                  : AppColors.warningBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  registered
                      ? LucideIcons.scanFace
                      : LucideIcons.alertTriangle,
                  size: 12,
                  color: registered
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  registered
                      ? (u.faceCount != null
                          ? '${u.faceCount} photos'
                          : 'Registered')
                      : 'No face',
                  style: AppTextStyles.label.copyWith(
                    color: registered
                        ? AppColors.success
                        : AppColors.warning,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(LucideIcons.chevronRight,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ── Avatar widget ──────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  static const _palette = [
    Color(0xFF2E5C8A),
    Color(0xFF1B7A5E),
    Color(0xFF7C3AED),
    Color(0xFFB45309),
    Color(0xFFBE185D),
    Color(0xFF0369A1),
  ];

  Color get _color =>
      _palette[initials.codeUnitAt(0) % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
