import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onLogout;
  final Function(String mode)? onModeChanged;
  final Function(UserModel updatedUser)? onUserUpdated;
  final VoidCallback? onBackToHome;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.onModeChanged,
    this.onUserUpdated,
    this.onBackToHome,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentMode;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _user = widget.user;
    _currentMode = widget.user?.currentMode ?? 'common';
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      setState(() {
        _user = widget.user;
        _currentMode = widget.user?.currentMode ?? 'common';
      });
    }
  }

  Future<void> _handleModeSwitch(String mode) async {
    try {
      final newMode = await ApiService.switchMode(mode);
      setState(() => _currentMode = newMode);
      widget.onModeChanged?.call(newMode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${newMode.toUpperCase()} Mode!'),
            backgroundColor: AppTheme.brandBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      }
    }
  }

  void _openEditProfileDialog(bool isDark, {int initialTab = 0}) {
    final personal = _user?.personalProfile;
    final prof = _user?.professionalProfile;

    final fullNameCtrl = TextEditingController(text: personal?.fullName ?? '');
    final displayNameCtrl = TextEditingController(text: personal?.displayName ?? '');
    final bioCtrl = TextEditingController(text: personal?.bio ?? '');
    final locationCtrl = TextEditingController(text: personal?.location ?? '');
    final websiteCtrl = TextEditingController(text: personal?.website ?? '');

    final headlineCtrl = TextEditingController(text: prof?.headline ?? '');
    final companyCtrl = TextEditingController(text: prof?.currentCompany ?? '');
    final industryCtrl = TextEditingController(text: prof?.industry ?? '');
    final expCtrl = TextEditingController(text: prof?.yearsOfExperience.toString() ?? '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.bgCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        int selectedSheetTab = initialTab;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final primaryColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
            final sheetBorderColor = isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Set & Edit Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Inner Tab Switcher (Personal / Career)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.bgInput : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sheetBorderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedSheetTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedSheetTab == 0 ? AppTheme.brandBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Personal Info',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: selectedSheetTab == 0
                                        ? Colors.white
                                        : (isDark ? AppTheme.textSecondary : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedSheetTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedSheetTab == 1 ? AppTheme.brandBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Career & Professional',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: selectedSheetTab == 1
                                        ? Colors.white
                                        : (isDark ? AppTheme.textSecondary : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (selectedSheetTab == 0) ...[
                      // Personal Fields
                      TextField(
                        controller: fullNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Legal Name',
                          hintText: 'e.g. Koushiki Podder',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: displayNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'e.g. Koushiki',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bioCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          hintText: 'Tell others about yourself...',
                          prefixIcon: Icon(Icons.info_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'e.g. Kolkata, India',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: websiteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                          hintText: 'e.g. https://koushiki.dev',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                    ] else ...[
                      // Professional Fields
                      TextField(
                        controller: headlineCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Professional Headline',
                          hintText: 'e.g. Lead Software Engineer',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: companyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Current Company / Organization',
                          hintText: 'e.g. CONNEKT Technologies',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: industryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Industry',
                          hintText: 'e.g. Information Technology',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: expCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Years of Experience',
                          hintText: 'e.g. 3',
                          prefixIcon: Icon(Icons.history),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Save Button
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                UserModel updatedUser;
                                if (selectedSheetTab == 0) {
                                  updatedUser = await ApiService.updatePersonalProfile(
                                    fullName: fullNameCtrl.text.trim(),
                                    displayName: displayNameCtrl.text.trim(),
                                    bio: bioCtrl.text.trim(),
                                    location: locationCtrl.text.trim(),
                                    website: websiteCtrl.text.trim(),
                                  );
                                } else {
                                  final expYears = int.tryParse(expCtrl.text.trim()) ?? 0;
                                  updatedUser = await ApiService.updateProfessionalProfile(
                                    headline: headlineCtrl.text.trim(),
                                    currentCompany: companyCtrl.text.trim(),
                                    industry: industryCtrl.text.trim(),
                                    yearsOfExperience: expYears,
                                  );
                                }

                                if (mounted) {
                                  setState(() => _user = updatedUser);
                                  widget.onUserUpdated?.call(updatedUser);
                                }

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated successfully!'),
                                      backgroundColor: AppTheme.brandBlue,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: AppTheme.accentCoral,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? widget.user;
    final personal = user?.personalProfile;
    final prof = user?.professionalProfile;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark ? AppTheme.textSecondary : const Color(0xFF475569);
    final mutedTextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final cardBgColor = isDark ? AppTheme.bgCard : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBackToHome != null
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
                tooltip: 'Back to Home',
                onPressed: widget.onBackToHome,
              )
            : null,
        title: Text(
          'My Profile & Modes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.brandRed),
            tooltip: 'Log Out',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Avatar Header with Tap to Edit
            Center(
              child: GestureDetector(
                onTap: () => _openEditProfileDialog(isDark),
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.brandBlue,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(45),
                        child: personal?.avatarUrl.isNotEmpty == true && (personal!.avatarUrl.startsWith('http://') || personal!.avatarUrl.startsWith('https://'))
                            ? Image.network(
                                personal!.avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 45, color: Colors.white),
                              )
                            : const Icon(Icons.person, size: 45, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.bgDark : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Display Name (Dynamic Contrast Color)
            Text(
              personal?.displayName.isNotEmpty == true
                  ? personal!.displayName
                  : (personal?.fullName.isNotEmpty == true ? personal!.fullName : (user?.username ?? 'User')),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 2),

            // Username Handle
            Text(
              '@${user?.username ?? 'username'}',
              style: TextStyle(
                color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),

            // Email Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.bgInput : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                user?.email ?? 'user@connekt.me',
                style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),

            // Explicit "Edit Profile" Button
            ElevatedButton.icon(
              onPressed: () => _openEditProfileDialog(isDark),
              icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white),
              label: const Text('Edit Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 16),

            // Mode Switcher Widget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    _buildModeButton('common', 'Personal', isDark),
                    _buildModeButton('professional', 'Professional', isDark),
                    _buildModeButton('both', 'Both Modes', isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tabs: Personal, Career & Skills, Settings
            TabBar(
              controller: _tabController,
              indicatorColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
              labelColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
              unselectedLabelColor: mutedTextColor,
              tabs: const [
                Tab(text: 'Personal'),
                Tab(text: 'Career & Skills'),
                Tab(text: 'Settings'),
              ],
            ),

            SizedBox(
              height: 480,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Personal
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Personal Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: primaryTextColor,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _openEditProfileDialog(isDark, initialTab: 0),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoTile('Full Legal Name', personal?.fullName.isNotEmpty == true ? personal!.fullName : 'Not set', Icons.person_outline, isDark),
                        _buildInfoTile('Display Name', personal?.displayName.isNotEmpty == true ? personal!.displayName : (user?.username ?? 'Not set'), Icons.badge_outlined, isDark),
                        _buildInfoTile('Bio', personal?.bio.isNotEmpty == true ? personal!.bio : 'No personal bio added yet.', Icons.info_outline, isDark),
                        _buildInfoTile('Location', personal?.location.isNotEmpty == true ? personal!.location : 'Location not set', Icons.location_on_outlined, isDark),
                        _buildInfoTile('Website', personal?.website.isNotEmpty == true ? personal!.website : 'No website', Icons.link, isDark),
                      ],
                    ),
                  ),

                  // Tab 2: Career & Skills
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ListView(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Professional Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: primaryTextColor,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _openEditProfileDialog(isDark, initialTab: 1),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoTile('Headline', prof?.headline.isNotEmpty == true ? prof!.headline : 'Member at CONNEKT', Icons.work_outline, isDark),
                        _buildInfoTile('Company', prof?.currentCompany.isNotEmpty == true ? prof!.currentCompany : 'Not specified', Icons.business_outlined, isDark),
                        _buildInfoTile('Industry', prof?.industry.isNotEmpty == true ? prof!.industry : 'Not specified', Icons.category_outlined, isDark),
                        _buildInfoTile('Experience', '${prof?.yearsOfExperience ?? 0} Years', Icons.history, isDark),
                        const SizedBox(height: 12),
                        Text('Verified Skills', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (user?.skills ?? []).isEmpty
                              ? [
                                  Text('No skills added yet', style: TextStyle(fontSize: 12, color: mutedTextColor)),
                                ]
                              : (user?.skills ?? []).map((s) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppTheme.brandBlue.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '${s.skillName} • ${s.proficiency}',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Tab 3: Appearance, Theme & Privacy
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ListView(
                      children: [
                        Text(
                          'Appearance & Theme Mood',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select your preferred visual mode for CONNEKT',
                          style: TextStyle(fontSize: 12, color: mutedTextColor),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: ThemeService.themeModeNotifier,
                          builder: (context, currentMode, _) {
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.bgInput : AppTheme.bgInputLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildThemeOption(
                                    mode: ThemeMode.dark,
                                    current: currentMode,
                                    label: 'Dark Mood',
                                    icon: Icons.dark_mode_rounded,
                                  ),
                                  _buildThemeOption(
                                    mode: ThemeMode.light,
                                    current: currentMode,
                                    label: 'Light Mood',
                                    icon: Icons.light_mode_rounded,
                                  ),
                                  _buildThemeOption(
                                    mode: ThemeMode.system,
                                    current: currentMode,
                                    label: 'System',
                                    icon: Icons.brightness_auto_rounded,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Privacy Controls',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: Text('Group Invitation Approval', style: TextStyle(fontSize: 14, color: primaryTextColor)),
                          subtitle: Text('Require approval before joining groups', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                          value: user?.privacySettings?.groupInvitationApproval ?? true,
                          onChanged: (_) {},
                          activeColor: AppTheme.brandBlue,
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: Text('Read Receipts', style: TextStyle(fontSize: 14, color: primaryTextColor)),
                          subtitle: Text('Show double blue checks on read', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                          value: user?.privacySettings?.readReceipts ?? true,
                          onChanged: (_) {},
                          activeColor: AppTheme.brandBlue,
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: Text('Online Status', style: TextStyle(fontSize: 14, color: primaryTextColor)),
                          subtitle: Text('Show green online indicator', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                          value: user?.privacySettings?.onlineStatus ?? true,
                          onChanged: (_) {},
                          activeColor: AppTheme.brandBlue,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, bool isDark) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleModeSwitch(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.brandBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.brandBlue.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppTheme.textSecondary : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required ThemeMode mode,
    required ThemeMode current,
    required String label,
    required IconData icon,
  }) {
    final isSelected = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ThemeService.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.brandBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.brandBlue.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppTheme.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
