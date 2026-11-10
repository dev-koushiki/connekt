class UserModel {
  final String id;
  final String phone;
  final String username;
  final String email;
  final String currentMode;
  final String role;
  final PersonalProfile? personalProfile;
  final ProfessionalProfile? professionalProfile;
  final List<SkillModel> skills;
  final List<ExperienceModel> experience;
  final List<EducationModel> education;
  final PrivacySettingsModel? privacySettings;

  UserModel({
    required this.id,
    required this.phone,
    required this.username,
    required this.email,
    required this.currentMode,
    required this.role,
    this.personalProfile,
    this.professionalProfile,
    this.skills = const [],
    this.experience = const [],
    this.education = const [],
    this.privacySettings,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      currentMode: json['current_mode'] ?? 'common',
      role: json['role'] ?? 'user',
      personalProfile: json['personalProfile'] != null
          ? PersonalProfile.fromJson(json['personalProfile'])
          : null,
      professionalProfile: json['professionalProfile'] != null
          ? ProfessionalProfile.fromJson(json['professionalProfile'])
          : null,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((s) => SkillModel.fromJson(s))
              .toList() ??
          [],
      experience: (json['experience'] as List<dynamic>?)
              ?.map((e) => ExperienceModel.fromJson(e))
              .toList() ??
          [],
      education: (json['education'] as List<dynamic>?)
              ?.map((e) => EducationModel.fromJson(e))
              .toList() ??
          [],
      privacySettings: json['privacySettings'] != null
          ? PrivacySettingsModel.fromJson(json['privacySettings'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'username': username,
      'email': email,
      'current_mode': currentMode,
      'role': role,
      if (personalProfile != null) 'personalProfile': personalProfile!.toJson(),
      if (professionalProfile != null) 'professionalProfile': professionalProfile!.toJson(),
      'skills': skills.map((s) => s.toJson()).toList(),
      'experience': experience.map((e) => e.toJson()).toList(),
      'education': education.map((e) => e.toJson()).toList(),
      if (privacySettings != null) 'privacySettings': privacySettings!.toJson(),
    };
  }
}

class PersonalProfile {
  final String fullName;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final String location;
  final String website;

  PersonalProfile({
    required this.fullName,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.location,
    required this.website,
  });

  factory PersonalProfile.fromJson(Map<String, dynamic> json) {
    return PersonalProfile(
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? (json['full_name'] ?? json['fullName'] ?? ''),
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'] ?? '',
      bio: json['bio'] ?? '',
      location: json['location'] ?? '',
      website: json['website'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'location': location,
      'website': website,
    };
  }
}

class ProfessionalProfile {
  final String headline;
  final String currentCompany;
  final String industry;
  final String summary;
  final int yearsOfExperience;
  final bool isOpenToWork;
  final bool isHiring;

  ProfessionalProfile({
    required this.headline,
    required this.currentCompany,
    required this.industry,
    required this.summary,
    required this.yearsOfExperience,
    required this.isOpenToWork,
    required this.isHiring,
  });

  factory ProfessionalProfile.fromJson(Map<String, dynamic> json) {
    return ProfessionalProfile(
      headline: json['headline'] ?? '',
      currentCompany: json['current_company'] ?? json['currentCompany'] ?? '',
      industry: json['industry'] ?? '',
      summary: json['summary'] ?? '',
      yearsOfExperience: json['years_of_experience'] ?? json['yearsOfExperience'] ?? 0,
      isOpenToWork: json['is_open_to_work'] ?? json['isOpenToWork'] ?? false,
      isHiring: json['is_hiring'] ?? json['isHiring'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'headline': headline,
      'current_company': currentCompany,
      'industry': industry,
      'summary': summary,
      'years_of_experience': yearsOfExperience,
      'is_open_to_work': isOpenToWork,
      'is_hiring': isHiring,
    };
  }
}

class SkillModel {
  final String id;
  final String skillName;
  final String proficiency;

  SkillModel({
    required this.id,
    required this.skillName,
    required this.proficiency,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      id: json['id'] ?? '',
      skillName: json['skill_name'] ?? json['skillName'] ?? '',
      proficiency: json['proficiency'] ?? 'Intermediate',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'skill_name': skillName,
      'proficiency': proficiency,
    };
  }
}

class ExperienceModel {
  final String id;
  final String companyName;
  final String title;
  final String description;

  ExperienceModel({
    required this.id,
    required this.companyName,
    required this.title,
    required this.description,
  });

  factory ExperienceModel.fromJson(Map<String, dynamic> json) {
    return ExperienceModel(
      id: json['id'] ?? '',
      companyName: json['company_name'] ?? json['companyName'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'title': title,
      'description': description,
    };
  }
}

class EducationModel {
  final String id;
  final String institution;
  final String degree;

  EducationModel({
    required this.id,
    required this.institution,
    required this.degree,
  });

  factory EducationModel.fromJson(Map<String, dynamic> json) {
    return EducationModel(
      id: json['id'] ?? '',
      institution: json['institution'] ?? '',
      degree: json['degree'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institution': institution,
      'degree': degree,
    };
  }
}

class PrivacySettingsModel {
  final String profileVisibility;
  final bool readReceipts;
  final bool onlineStatus;
  final bool groupInvitationApproval;

  PrivacySettingsModel({
    required this.profileVisibility,
    required this.readReceipts,
    required this.onlineStatus,
    required this.groupInvitationApproval,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      profileVisibility: json['profile_visibility'] ?? json['profileVisibility'] ?? 'public',
      readReceipts: json['read_receipts'] ?? json['readReceipts'] ?? true,
      onlineStatus: json['online_status'] ?? json['onlineStatus'] ?? true,
      groupInvitationApproval: json['group_invitation_approval'] ?? json['groupInvitationApproval'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_visibility': profileVisibility,
      'read_receipts': readReceipts,
      'online_status': onlineStatus,
      'group_invitation_approval': groupInvitationApproval,
    };
  }
}
