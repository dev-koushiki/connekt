class SocialMediaAttachment {
  final String url;
  final String filename;
  final String type; // image | video | document

  const SocialMediaAttachment({
    required this.url,
    this.filename = '',
    this.type = 'image',
  });

  factory SocialMediaAttachment.fromJson(Map<String, dynamic> json) {
    return SocialMediaAttachment(
      url: (json['url'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      type: (json['type'] ?? 'image').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'filename': filename,
        'type': type,
      };
}

class SocialPost {
  final String id;
  final String authorId;
  final String authorUsername;
  final String authorName;
  final String? authorAvatarUrl;
  final String authorHeadline;
  final bool authorIsPro;
  final String mode;
  final String? communityId;
  final String? groupId;
  final String postType;
  final String title;
  final String content;
  final List<SocialMediaAttachment> mediaUrls;
  final String? sharedPostId;
  final String? sharedPostAuthor;
  final String? sharedPostContent;
  final String visibility;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isPinned;
  final String? myReaction;
  final bool isSaved;
  final bool isOwnPost;
  final DateTime createdAt;

  const SocialPost({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorName,
    this.authorAvatarUrl,
    this.authorHeadline = '',
    this.authorIsPro = false,
    this.mode = 'social',
    this.communityId,
    this.groupId,
    this.postType = 'text',
    this.title = '',
    required this.content,
    this.mediaUrls = const [],
    this.sharedPostId,
    this.sharedPostAuthor,
    this.sharedPostContent,
    this.visibility = 'public',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isPinned = false,
    this.myReaction,
    this.isSaved = false,
    this.isOwnPost = false,
    required this.createdAt,
  });

  factory SocialPost.fromJson(Map<String, dynamic> json) {
    final rawMedia = (json['mediaUrls'] as List<dynamic>? ?? const [])
        .map((m) => m is Map
            ? SocialMediaAttachment.fromJson(Map<String, dynamic>.from(m))
            : SocialMediaAttachment(url: m.toString()))
        .toList();
    return SocialPost(
      id: (json['id'] ?? '').toString(),
      authorId: (json['authorId'] ?? '').toString(),
      authorUsername: (json['authorUsername'] ?? '').toString(),
      authorName: (json['authorName'] ?? json['authorUsername'] ?? 'Member').toString(),
      authorAvatarUrl: json['authorAvatarUrl']?.toString(),
      authorHeadline: (json['authorHeadline'] ?? '').toString(),
      authorIsPro: json['authorIsPro'] == true,
      mode: (json['mode'] ?? 'social').toString(),
      communityId: json['communityId']?.toString(),
      groupId: json['groupId']?.toString(),
      postType: (json['postType'] ?? 'text').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      mediaUrls: rawMedia,
      sharedPostId: json['sharedPostId']?.toString(),
      sharedPostAuthor: json['sharedPostAuthor']?.toString(),
      sharedPostContent: json['sharedPostContent']?.toString(),
      visibility: (json['visibility'] ?? 'public').toString(),
      likesCount: int.tryParse((json['likesCount'] ?? 0).toString()) ?? 0,
      commentsCount: int.tryParse((json['commentsCount'] ?? 0).toString()) ?? 0,
      sharesCount: int.tryParse((json['sharesCount'] ?? 0).toString()) ?? 0,
      isPinned: json['isPinned'] == true,
      myReaction: json['myReaction']?.toString(),
      isSaved: json['isSaved'] == true,
      isOwnPost: json['isOwnPost'] == true,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  SocialPost copyWith({
    String? title,
    String? content,
    String? visibility,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    String? myReaction,
    bool clearReaction = false,
    bool? isSaved,
    bool? isPinned,
  }) {
    return SocialPost(
      id: id,
      authorId: authorId,
      authorUsername: authorUsername,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      authorHeadline: authorHeadline,
      authorIsPro: authorIsPro,
      mode: mode,
      communityId: communityId,
      groupId: groupId,
      postType: postType,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrls: mediaUrls,
      sharedPostId: sharedPostId,
      sharedPostAuthor: sharedPostAuthor,
      sharedPostContent: sharedPostContent,
      visibility: visibility ?? this.visibility,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isPinned: isPinned ?? this.isPinned,
      myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
      isSaved: isSaved ?? this.isSaved,
      isOwnPost: isOwnPost,
      createdAt: createdAt,
    );
  }
}

class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String authorName;
  final String? authorAvatarUrl;
  final String? parentCommentId;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.authorName,
    this.authorAvatarUrl,
    this.parentCommentId,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: (json['id'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      authorName: (json['authorName'] ?? json['username'] ?? 'User').toString(),
      authorAvatarUrl: json['authorAvatarUrl']?.toString(),
      parentCommentId: json['parentCommentId']?.toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class PersonSummary {
  final String? requestId;
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String bio;
  final String headline;
  final String? status;

  const PersonSummary({
    this.requestId,
    required this.id,
    required this.username,
    this.email = '',
    required this.fullName,
    this.avatarUrl,
    this.bio = '',
    this.headline = '',
    this.status,
  });

  factory PersonSummary.fromJson(Map<String, dynamic> json) {
    return PersonSummary(
      requestId: json['requestId']?.toString(),
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['username'] ?? 'User').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      bio: (json['bio'] ?? '').toString(),
      headline: (json['headline'] ?? '').toString(),
      status: json['status']?.toString(),
    );
  }
}

class SocialNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const SocialNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory SocialNotification.fromJson(Map<String, dynamic> json) {
    return SocialNotification(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'info').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      isRead: json['is_read'] == true || json['isRead'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String tagline;
  final int priceCents;
  final String currency;
  final String billingCycle;
  final int durationDays;
  final String gatewayProvider;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.tagline = '',
    this.priceCents = 0,
    this.currency = 'INR',
    this.billingCycle = 'free',
    this.durationDays = 30,
    this.gatewayProvider = 'configurable',
    this.features = const [],
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      tagline: (json['tagline'] ?? '').toString(),
      priceCents: int.tryParse((json['priceCents'] ?? 0).toString()) ?? 0,
      currency: (json['currency'] ?? 'INR').toString(),
      billingCycle: (json['billingCycle'] ?? 'free').toString(),
      durationDays: int.tryParse((json['durationDays'] ?? 30).toString()) ?? 30,
      gatewayProvider: (json['gatewayProvider'] ?? 'configurable').toString(),
      features: (json['features'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  String get formattedPrice {
    if (priceCents <= 0) return 'Free';
    final amount = (priceCents / 100).toStringAsFixed(0);
    final sym = currency == 'INR' ? '₹' : '$currency ';
    return '$sym$amount / $billingCycle';
  }
}

class UserSubscriptionState {
  final bool isSubscribed;
  final String planId;
  final String planName;
  final String status;
  final DateTime? expiresAt;
  final List<String> features;

  const UserSubscriptionState({
    this.isSubscribed = false,
    this.planId = 'free',
    this.planName = 'Starter Free',
    this.status = 'free',
    this.expiresAt,
    this.features = const ['basic_profile', 'basic_feed', 'browse_jobs', 'standard_connect'],
  });

  bool hasFeature(String featureKey) => features.contains(featureKey);

  factory UserSubscriptionState.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionState(
      isSubscribed: json['isSubscribed'] == true,
      planId: (json['planId'] ?? 'free').toString(),
      planName: (json['planName'] ?? 'Starter Free').toString(),
      status: (json['status'] ?? 'free').toString(),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()),
      features: (json['features'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class JobListing {
  final String id;
  final String? companyId;
  final String recruiterId;
  final String title;
  final String jobType;
  final String location;
  final String workMode;
  final String salaryRange;
  final String description;
  final String requirements;
  final String companyName;
  final bool hasApplied;
  final DateTime createdAt;

  const JobListing({
    required this.id,
    this.companyId,
    required this.recruiterId,
    required this.title,
    this.jobType = 'full-time',
    this.location = 'Remote',
    this.workMode = 'remote',
    this.salaryRange = '',
    this.description = '',
    this.requirements = '',
    this.companyName = '',
    this.hasApplied = false,
    required this.createdAt,
  });

  factory JobListing.fromJson(Map<String, dynamic> json) {
    return JobListing(
      id: (json['id'] ?? '').toString(),
      companyId: json['company_id']?.toString(),
      recruiterId: (json['recruiter_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      jobType: (json['job_type'] ?? 'full-time').toString(),
      location: (json['location'] ?? 'Remote').toString(),
      workMode: (json['work_mode'] ?? 'remote').toString(),
      salaryRange: (json['salary_range'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      requirements: (json['requirements'] ?? '').toString(),
      companyName: (json['company_name'] ?? 'Hiring Team').toString(),
      hasApplied: json['has_applied'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class CompanyProfile {
  final String id;
  final String ownerId;
  final String name;
  final String industry;
  final String size;
  final String website;
  final String location;
  final String description;

  const CompanyProfile({
    required this.id,
    required this.ownerId,
    required this.name,
    this.industry = '',
    this.size = '11-50',
    this.website = '',
    this.location = '',
    this.description = '',
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      id: (json['id'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      industry: (json['industry'] ?? '').toString(),
      size: (json['size'] ?? '11-50').toString(),
      website: (json['website'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class CommunityModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String? coverUrl;
  final String rules;
  final String visibility;
  final String category;
  final int membersCount;
  final int groupsCount;
  final int liveCount;
  final String? myRole;
  final String? myStatus;

  const CommunityModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.coverUrl,
    this.rules = '',
    this.visibility = 'public',
    this.category = 'General',
    this.membersCount = 1,
    this.groupsCount = 0,
    this.liveCount = 0,
    this.myRole,
    this.myStatus,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: (json['id'] ?? '').toString(),
      ownerId: (json['ownerId'] ?? json['owner_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      coverUrl: (json['coverUrl'] ?? json['cover_url'])?.toString(),
      rules: (json['rules'] ?? '').toString(),
      visibility: (json['visibility'] ?? 'public').toString(),
      category: (json['category'] ?? 'General').toString(),
      membersCount: int.tryParse((json['membersCount'] ?? json['members_count'] ?? 1).toString()) ?? 1,
      groupsCount: int.tryParse((json['groupsCount'] ?? json['groups_count'] ?? 0).toString()) ?? 0,
      liveCount: int.tryParse((json['liveCount'] ?? json['live_count'] ?? 0).toString()) ?? 0,
      myRole: json['myRole']?.toString(),
      myStatus: json['myStatus']?.toString(),
    );
  }
}

class CommunityGroupModel {
  final String id;
  final String communityId;
  final String name;
  final String description;
  final String topic;
  final bool isAnnouncementOnly;
  final int membersCount;
  final bool isMember;

  const CommunityGroupModel({
    required this.id,
    required this.communityId,
    required this.name,
    this.description = '',
    this.topic = 'General',
    this.isAnnouncementOnly = false,
    this.membersCount = 1,
    this.isMember = false,
  });

  factory CommunityGroupModel.fromJson(Map<String, dynamic> json) {
    return CommunityGroupModel(
      id: (json['id'] ?? '').toString(),
      communityId: (json['community_id'] ?? json['communityId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      topic: (json['topic'] ?? 'General').toString(),
      isAnnouncementOnly: json['is_announcement_only'] == true,
      membersCount: int.tryParse((json['members_count'] ?? 1).toString()) ?? 1,
      isMember: json['is_member'] == true,
    );
  }
}

class CommunityLiveSession {
  final String id;
  final String communityId;
  final String? groupId;
  final String hostId;
  final String hostName;
  final String title;
  final String description;
  final String status; // scheduled | live | ended
  final DateTime? scheduledFor;
  final String roomCode;
  final int viewerCount;

  const CommunityLiveSession({
    required this.id,
    required this.communityId,
    this.groupId,
    required this.hostId,
    required this.hostName,
    required this.title,
    this.description = '',
    this.status = 'live',
    this.scheduledFor,
    required this.roomCode,
    this.viewerCount = 0,
  });

  factory CommunityLiveSession.fromJson(Map<String, dynamic> json) {
    return CommunityLiveSession(
      id: (json['id'] ?? '').toString(),
      communityId: (json['community_id'] ?? '').toString(),
      groupId: json['group_id']?.toString(),
      hostId: (json['host_id'] ?? '').toString(),
      hostName: (json['host_name'] ?? json['host_username'] ?? 'Host').toString(),
      title: (json['title'] ?? 'Community Live').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'live').toString(),
      scheduledFor: DateTime.tryParse((json['scheduled_for'] ?? '').toString()),
      roomCode: (json['room_code'] ?? '').toString(),
      viewerCount: int.tryParse((json['viewer_count'] ?? 0).toString()) ?? 0,
    );
  }
}
