import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/social_models.dart';
import '../../models/user_model.dart';
import '../../services/social_service.dart';
import '../safe_avatar.dart';
import 'post_card_widget.dart';
import 'user_profile_sheet.dart';

class ProfessionalView extends StatefulWidget {
  final UserModel? user;

  const ProfessionalView({super.key, this.user});

  @override
  State<ProfessionalView> createState() => _ProfessionalViewState();
}

class _ProfessionalViewState extends State<ProfessionalView> {
  int _subTab = 0; // 0: Pro Feed & Articles, 1: Jobs & Internships, 2: Network, 3: Profile & Analytics
  String _jobFilter = 'all';
  bool _loading = true;

  UserSubscriptionState _subscription = const UserSubscriptionState();
  List<SubscriptionPlan> _plans = [];
  List<SocialPost> _posts = [];
  List<JobListing> _jobs = [];
  List<CompanyProfile> _companies = [];
  List<PersonSummary> _connections = [];
  List<PersonSummary> _incomingRequests = [];
  List<PersonSummary> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String get _currentUserId => widget.user?.id ?? '';

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SocialService.getSubscriptionOverview(),
        SocialService.getFeed(mode: 'professional'),
        SocialService.listJobsAndCompanies(jobType: _jobFilter),
        SocialService.getPeopleOverview(kind: 'professional'),
      ]);
      if (!mounted) return;

      final subData = results[0] as Map<String, dynamic>;
      final posts = results[1] as List<SocialPost>;
      final jobData = results[2] as Map<String, dynamic>;
      final people = results[3] as Map<String, dynamic>;

      setState(() {
        if (subData['currentSubscription'] is Map) {
          _subscription = UserSubscriptionState.fromJson(Map<String, dynamic>.from(subData['currentSubscription']));
        }
        _plans = (subData['plans'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((p) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        _posts = posts;
        _jobs = (jobData['jobs'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((j) => JobListing.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _companies = (jobData['companies'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((c) => CompanyProfile.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        _connections = (people['connections'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _incomingRequests = (people['incomingRequests'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _suggestions = (people['suggestions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUpgradeSheet({String? featureHint}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        final textPrimary = AppTheme.getTextPrimary(ctx);
        final textSecondary = AppTheme.getTextSecondary(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.brandBlue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Connekt Pro Membership', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(
                            featureHint != null ? 'Required for: $featureHint' : 'Unlock recruiter tools, articles & analytics',
                            style: TextStyle(color: textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                ..._plans.map((plan) {
                  final isCurrent = _subscription.planId == plan.id && _subscription.isSubscribed;
                  final isPaid = plan.priceCents > 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent ? AppTheme.brandBlue : AppTheme.getBorderColor(ctx),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(plan.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                            ),
                            Text(plan.formattedPrice, style: const TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.w800, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(plan.tagline, style: TextStyle(color: textSecondary, fontSize: 12.5)),
                        const SizedBox(height: 8),
                        if (isPaid)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                              onPressed: isCurrent
                                  ? null
                                  : () async {
                                      final res = await SocialService.subscribePlan(plan.id);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (res.success && res.data != null && mounted) {
                                        setState(() => _subscription = res.data!);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
                                        await _loadAll();
                                      }
                                    },
                              child: Text(isCurrent ? 'Active Plan' : 'Activate ${plan.name}'),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                if (_subscription.isSubscribed)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        final res = await SocialService.cancelSubscription(mode: 'expire');
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (res.data != null && mounted) {
                          setState(() => _subscription = res.data!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Subscription expired — premium features locked')),
                          );
                        }
                      },
                      child: const Text('Cancel / Simulate Expiry', style: TextStyle(color: AppTheme.accentCoral)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAchievementOrArticleComposer({required bool isArticle}) async {
    if (isArticle && !_subscription.hasFeature('publish_articles')) {
      await _openUpgradeSheet(featureHint: 'Publish Professional Articles');
      return;
    }

    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArticle ? 'Publish Article (Pro)' : 'Share Achievement / Update'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isArticle) ...[
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Article Headline')),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: isArticle ? 'Article Content' : 'Share milestone, project launch, or industry insight...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (ok == true && contentCtrl.text.trim().isNotEmpty) {
      if (isArticle) {
        final res = await SocialService.publishArticle(
          title: titleCtrl.text.trim(),
          content: contentCtrl.text.trim(),
        );
        if (res.requiresSubscription) {
          await _openUpgradeSheet(featureHint: res.message);
        } else {
          await _loadAll();
        }
      } else {
        await SocialService.createPost(
          mode: 'professional',
          postType: 'achievement',
          content: contentCtrl.text.trim(),
          visibility: 'public',
        );
        await _loadAll();
      }
    }
    titleCtrl.dispose();
    contentCtrl.dispose();
  }

  Future<void> _openPostJobDialog() async {
    if (!_subscription.hasFeature('post_job_listings')) {
      await _openUpgradeSheet(featureHint: 'Post Job & Internship Listings');
      return;
    }
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'Remote');
    final salaryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String jobType = 'full-time';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Post Career Opportunity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Role Title')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: jobType,
                  decoration: const InputDecoration(labelText: 'Opportunity Type'),
                  items: const [
                    DropdownMenuItem(value: 'full-time', child: Text('Full-Time Job')),
                    DropdownMenuItem(value: 'internship', child: Text('Internship')),
                    DropdownMenuItem(value: 'part-time', child: Text('Part-Time')),
                    DropdownMenuItem(value: 'contract', child: Text('Contract')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlg(() => jobType = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 8),
                TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: 'Compensation / Stipend')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Role Summary')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final res = await SocialService.createJob({
        'title': titleCtrl.text.trim(),
        'jobType': jobType,
        'location': locationCtrl.text.trim(),
        'salaryRange': salaryCtrl.text.trim(),
        'description': descCtrl.text.trim(),
      });
      if (res.requiresSubscription) {
        await _openUpgradeSheet(featureHint: res.message);
      } else {
        await _loadAll();
      }
    }
    titleCtrl.dispose();
    locationCtrl.dispose();
    salaryCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _openAnalyticsModal() async {
    final res = await SocialService.getProfileAnalytics();
    if (!mounted) return;
    if (res.requiresSubscription || !res.success) {
      await _openUpgradeSheet(featureHint: 'Who Viewed Your Profile & Career Analytics');
      return;
    }
    final data = res.data ?? const {};
    final viewers = (data['recentViewers'] as List<dynamic>? ?? const []);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Career & Profile Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricBox('Total Views', '${data['totalProfileViews'] ?? 0}'),
                  _metricBox('Last 7 Days', '${data['viewsLast7Days'] ?? 0}'),
                  _metricBox('Reactions', '${data['totalReactions'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 14),
              if (viewers.isNotEmpty) ...[
                const Text('Recent Profile Viewers', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...viewers.take(5).map((v) {
                  final m = Map<String, dynamic>.from(v as Map);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_outlined, color: AppTheme.brandBlue),
                    title: Text((m['full_name'] ?? m['username'] ?? 'Member').toString()),
                    subtitle: Text((m['headline'] ?? '').toString()),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricBox(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.brandBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(val, style: const TextStyle(color: AppTheme.brandBlue, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Column(
      children: [
        // Subscription Banner
        Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _subscription.isSubscribed
                ? AppTheme.brandBlue.withValues(alpha: 0.12)
                : AppTheme.accentAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _subscription.isSubscribed
                  ? AppTheme.brandBlue.withValues(alpha: 0.4)
                  : AppTheme.accentAmber.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _subscription.isSubscribed ? Icons.verified_rounded : Icons.lock_outline_rounded,
                size: 18,
                color: _subscription.isSubscribed ? AppTheme.brandBlue : AppTheme.accentAmber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _subscription.isSubscribed
                      ? '${_subscription.planName} Active'
                      : 'Free Plan — Some Pro career tools locked',
                  style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _openUpgradeSheet(),
                child: Text(_subscription.isSubscribed ? 'Manage' : 'Upgrade Pro'),
              ),
            ],
          ),
        ),

        // Sub-tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              _subChip('Pro Feed', 0, Icons.newspaper_rounded),
              const SizedBox(width: 8),
              _subChip('Jobs & Internships', 1, Icons.work_outline_rounded),
              const SizedBox(width: 8),
              _subChip('Network (${_connections.length})', 2, Icons.hub_outlined),
              const SizedBox(width: 8),
              _subChip('Career Profile', 3, Icons.badge_outlined),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.brandBlue))
              : _subTab == 0
                  ? _buildProFeed(cardColor, borderColor, textPrimary, textSecondary)
                  : _subTab == 1
                      ? _buildJobsTab(cardColor, borderColor, textPrimary, textSecondary)
                      : _subTab == 2
                          ? _buildNetworkTab(cardColor, borderColor, textPrimary, textSecondary)
                          : _buildProProfileTab(cardColor, borderColor, textPrimary, textSecondary),
        ),
      ],
    );
  }

  Widget _subChip(String label, int idx, IconData icon) {
    final active = _subTab == idx;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: active ? Colors.white : AppTheme.brandBlue),
      label: Text(label),
      selected: active,
      selectedColor: AppTheme.brandBlue,
      labelStyle: TextStyle(
        color: active ? Colors.white : AppTheme.getTextSecondary(context),
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _subTab = idx),
    );
  }

  Widget _buildProFeed(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    final canPublishArticle = _subscription.hasFeature('publish_articles');
    final hasAnalytics = _subscription.hasFeature('profile_analytics');
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.emoji_events_outlined, size: 18),
                        label: const Text('Share Update'),
                        onPressed: () => _openAchievementOrArticleComposer(isArticle: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canPublishArticle ? AppTheme.brandBlue : AppTheme.getInputColor(context),
                          foregroundColor: canPublishArticle ? Colors.white : textPrimary,
                        ),
                        icon: Icon(canPublishArticle ? Icons.article_outlined : Icons.lock_outline_rounded, size: 17),
                        label: Text(canPublishArticle ? 'Write Article' : 'Article (PRO)'),
                        onPressed: () => _openAchievementOrArticleComposer(isArticle: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _openAnalyticsModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: AppTheme.getInputColor(context), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(hasAnalytics ? Icons.insights_rounded : Icons.lock_outline_rounded, size: 18, color: AppTheme.brandBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasAnalytics ? 'View Who Viewed Your Profile & Analytics' : 'Who Viewed Your Profile & Analytics (PRO Locked)',
                            style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(child: Text('No professional updates yet.', style: TextStyle(color: textSecondary))),
            )
          else
            ..._posts.map((post) => PostCardWidget(
                  post: post,
                  onTapAuthor: () => showUserProfileSheet(context, userId: post.authorId, currentUserId: _currentUserId, mode: 'professional'),
                  onReact: (reaction) async {
                    final res = await SocialService.reactToPost(post.id, reaction);
                    if (res != null && mounted) {
                      setState(() {
                        final i = _posts.indexWhere((p) => p.id == post.id);
                        if (i != -1) {
                          _posts[i] = _posts[i].copyWith(
                            likesCount: res['likesCount'] as int? ?? _posts[i].likesCount,
                            myReaction: res['myReaction']?.toString(),
                            clearReaction: res['myReaction'] == null,
                          );
                        }
                      });
                    }
                  },
                  onOpenComments: () => showPostCommentsSheet(
                    context,
                    post: post,
                    onCommentsUpdated: (cnt) {
                      setState(() {
                        final i = _posts.indexWhere((p) => p.id == post.id);
                        if (i != -1) _posts[i] = _posts[i].copyWith(commentsCount: cnt);
                      });
                    },
                  ),
                  onShare: () async {
                    await SocialService.createPost(mode: 'professional', postType: 'share', content: 'Reposted', sharedPostId: post.id);
                    await _loadAll();
                  },
                  onToggleSave: () async {
                    final saved = await SocialService.toggleSavePost(post.id);
                    if (saved != null && mounted) {
                      setState(() {
                        final i = _posts.indexWhere((p) => p.id == post.id);
                        if (i != -1) _posts[i] = _posts[i].copyWith(isSaved: saved);
                      });
                    }
                  },
                  onDelete: () async {
                    await SocialService.deletePost(post.id);
                    await _loadAll();
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildJobsTab(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    final canPostJobs = _subscription.hasFeature('post_job_listings');
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in const [
                        {'id': 'all', 'label': 'All'},
                        {'id': 'full-time', 'label': 'Jobs'},
                        {'id': 'internship', 'label': 'Internships'},
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(f['label']!),
                            selected: _jobFilter == f['id'],
                            onSelected: (_) {
                              setState(() => _jobFilter = f['id']!);
                              _loadAll();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canPostJobs ? AppTheme.brandBlue : AppTheme.getInputColor(context),
                  foregroundColor: canPostJobs ? Colors.white : textPrimary,
                ),
                icon: Icon(canPostJobs ? Icons.add_business_outlined : Icons.lock_outline_rounded, size: 17),
                label: Text(canPostJobs ? 'Post Job' : 'Post (PRO)'),
                onPressed: _openPostJobDialog,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_jobs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Center(child: Text('No openings posted yet.', style: TextStyle(color: textSecondary))),
            )
          else
            ..._jobs.map((job) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(job.title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15.5)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.brandBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(job.jobType.toUpperCase(), style: const TextStyle(color: AppTheme.brandBlue, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${job.companyName} • ${job.location} (${job.workMode})', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                      if (job.salaryRange.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(job.salaryRange, style: const TextStyle(color: AppTheme.brandBlueLight, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                      if (job.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textPrimary, fontSize: 13)),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: job.hasApplied ? AppTheme.brandBlueLight : AppTheme.brandBlue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: job.hasApplied
                              ? null
                              : () async {
                                  final noteCtrl = TextEditingController();
                                  final apply = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Apply for ${job.title}'),
                                      content: TextField(controller: noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Cover Note')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit Application')),
                                      ],
                                    ),
                                  );
                                  if (apply == true) {
                                    final outcome = await SocialService.applyForJob(job.id, coverNote: noteCtrl.text.trim());
                                    if (outcome.requiresSubscription) {
                                      await _openUpgradeSheet(featureHint: outcome.message);
                                    } else if (outcome.success && mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted!')));
                                      await _loadAll();
                                    }
                                  }
                                  noteCtrl.dispose();
                                },
                          child: Text(job.hasApplied ? 'Applied ✓' : 'Apply Now'),
                        ),
                      ),
                    ],
                  ),
                )),

          if (_companies.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Recruiter & Company Pages (${_companies.length})', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            ..._companies.map((c) => ListTile(
                  leading: const CircleAvatar(backgroundColor: AppTheme.brandBlue, child: Icon(Icons.business_rounded, color: Colors.white, size: 18)),
                  title: Text(c.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                  subtitle: Text('${c.industry} • ${c.location}', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkTab(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          if (_incomingRequests.isNotEmpty) ...[
            Text('Connection Requests', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            ..._incomingRequests.map((u) => ListTile(
                  leading: SafeAvatar(url: u.avatarUrl, fallbackText: u.fullName[0].toUpperCase(), size: 40, radius: 20),
                  title: Text(u.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                  subtitle: Text(u.headline.isNotEmpty ? u.headline : '@${u.username}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (u.requestId != null) {
                        await SocialService.respondConnectionRequest(u.requestId!, 'accept');
                        await _loadAll();
                      }
                    },
                    child: const Text('Connect'),
                  ),
                )),
          ],
          Text('Your Network (${_connections.length})', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          ..._connections.map((u) => ListTile(
                leading: SafeAvatar(url: u.avatarUrl, fallbackText: u.fullName[0].toUpperCase(), size: 40, radius: 20),
                title: Text(u.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text(u.headline.isNotEmpty ? u.headline : '@${u.username}'),
                onTap: () => showUserProfileSheet(context, userId: u.id, currentUserId: _currentUserId, mode: 'professional'),
              )),
          const SizedBox(height: 14),
          Text('People You May Know', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          ..._suggestions.map((u) => ListTile(
                leading: SafeAvatar(url: u.avatarUrl, fallbackText: u.fullName[0].toUpperCase(), size: 40, radius: 20),
                title: Text(u.fullName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text(u.headline.isNotEmpty ? u.headline : '@${u.username}'),
                trailing: OutlinedButton(
                  onPressed: () async {
                    await SocialService.sendConnectionRequest(u.id, kind: 'professional');
                    await _loadAll();
                  },
                  child: const Text('Connect'),
                ),
                onTap: () => showUserProfileSheet(context, userId: u.id, currentUserId: _currentUserId, mode: 'professional'),
              )),
        ],
      ),
    );
  }

  Widget _buildProProfileTab(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Professional Profile & Portfolio', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Preview'),
                    onPressed: () => showUserProfileSheet(context, userId: _currentUserId, currentUserId: _currentUserId, mode: 'professional'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit Headline & Resume'),
                    onPressed: _openEditProProfileDialog,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.workspace_premium_outlined, size: 17),
                    label: const Text('+ Certification'),
                    onPressed: _openAddCertDialog,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_special_outlined, size: 17),
                    label: const Text('+ Project'),
                    onPressed: _openAddProjectDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openEditProProfileDialog() async {
    final headlineCtrl = TextEditingController(text: widget.user?.professionalProfile?.headline ?? '');
    final aboutCtrl = TextEditingController(text: widget.user?.professionalProfile?.summary ?? '');
    final portfolioCtrl = TextEditingController();
    String? uploadedResumeName;
    String? resumeUrl;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Update Professional Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: headlineCtrl, decoration: const InputDecoration(labelText: 'Professional Headline')),
                const SizedBox(height: 8),
                TextField(controller: aboutCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'About Summary')),
                const SizedBox(height: 8),
                TextField(controller: portfolioCtrl, decoration: const InputDecoration(labelText: 'Portfolio / Website URL')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(uploadedResumeName != null ? 'Resume: $uploadedResumeName' : 'Upload Resume (PDF/DOC)'),
                  onPressed: () async {
                    final files = await FilePicker.pickFiles();
                    if (files.isEmpty) return;
                    final f = files.first;
                    final bytes = await f.readAsBytes();
                    final att = await SocialService.uploadSocialMedia(filename: f.name, bytes: bytes);
                    if (att != null) {
                      setDlg(() {
                        uploadedResumeName = f.name;
                        resumeUrl = att.url;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await SocialService.updateProProfile({
        'headline': headlineCtrl.text.trim(),
        'about': aboutCtrl.text.trim(),
        if (portfolioCtrl.text.trim().isNotEmpty) 'portfolioUrl': portfolioCtrl.text.trim(),
        'resumeUrl': ?resumeUrl,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Professional profile saved')));
    }
    headlineCtrl.dispose();
    aboutCtrl.dispose();
    portfolioCtrl.dispose();
  }

  Future<void> _openAddCertDialog() async {
    final nameCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Certification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Certification Name')),
            const SizedBox(height: 8),
            TextField(controller: issuerCtrl, decoration: const InputDecoration(labelText: 'Issuing Organization')),
            const SizedBox(height: 8),
            TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Issue Date (e.g. Nov 2026)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await SocialService.addCertification({
        'name': nameCtrl.text.trim(),
        'issuer': issuerCtrl.text.trim(),
        'issueDate': dateCtrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Certification added')));
    }
    nameCtrl.dispose();
    issuerCtrl.dispose();
    dateCtrl.dispose();
  }

  Future<void> _openAddProjectDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Portfolio Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Project Title')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 8),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Project URL (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      await SocialService.addProject({
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'projectUrl': urlCtrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project added')));
    }
    titleCtrl.dispose();
    descCtrl.dispose();
    urlCtrl.dispose();
  }
}
