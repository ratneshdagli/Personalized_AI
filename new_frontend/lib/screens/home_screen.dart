import 'package:flutter/material.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../state/app_state.dart';
import '../theme/gradients.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/add_item_sheet.dart';
import '../widgets/detail_sheet.dart';
import '../widgets/model_manager_card.dart';
import '../widgets/hf_model_manager_card.dart';

// Home screen mapped from `src/components/HomeFeed.tsx`:
// - Header with title and gradient square icon
// - Search bar with leading/trailing icons
// - View toggle stub and actions
// - Dashboard grid of category hubs with gradient accents
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return GradientBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // Breakpoints: 360, 390, 420, 480 (Tailwind-like tiers)
            // <390: very compact; <420: compact; <480: medium; else: roomy
            final isCompact = w < 420;
            final gridCount = 3; // always show 3 hubs per row for compact layout parity
            final gridSpacing = w < 390 ? 6.0 : 8.0; // gap-1.5 -> 6, gap-2 -> 8

            return RefreshIndicator(
              onRefresh: () => context.read<AppState>().refreshFeed(),
              color: const Color(0xFFA855F7),
              backgroundColor: const Color(0xFF1E293B),
              child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your Space', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              '${appState.filteredFeed.length} updates',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFA855F7), Color(0xFFEC4899), Color(0xFFA855F7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(color: Color(0x4DA855F7), blurRadius: 16, spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search bar (glass)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(10),
                      child: TextField(
                        controller: context.read<AppState>().searchController,
                        decoration: InputDecoration(
                          hintText: 'Search everything...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                            onPressed: () => context.read<AppState>().clearSearch(),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) => context.read<AppState>().search = v,
                      ),
                    ),
                  ),
                ),

                // Toggle + actions bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0x4D0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _seg(context.watch<AppState>().selectedHubTab == 'Hubs', 'Hubs', onTap: () => context.read<AppState>().setHubTab('Hubs')),
                                _seg(context.watch<AppState>().selectedHubTab == 'All', 'All', onTap: () => context.read<AppState>().setHubTab('All')),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _squareBtn(Icons.add, onTap: () => _openAdd(context)),
                      ],
                    ),
                  ),
                ),

                // Model Management Card
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: HFModelManagerCard(),
                  ),
                ),

                // Priority Spotlight - Dynamic from backend
                if (!appState.isLoadingFeed && appState.priorityFeed.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const _SectionTitle(icon: Icons.bolt, color: Color(0xFFF87171), title: 'Priority Spotlight'),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${appState.priorityFeed.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: appState.priorityFeed.take(2).map((item) {
                              IconData icon = Icons.notification_important;
                              if (item.type == FeedType.email) icon = Icons.mail;
                              if (item.type == FeedType.whatsapp) icon = Icons.chat;
                              if (item.type == FeedType.message) icon = Icons.message;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _priorityCard(icon, item.title, '${item.sender} • ${item.time}', const [Color(0xFFEF4444), Color(0xFFF97316)]),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Loading indicator
                if (appState.isLoadingFeed)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFA855F7),
                        ),
                      ),
                    ),
                  ),
                
                // Error message
                if (appState.errorMessage != null && !appState.isLoadingFeed)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  appState.errorMessage!,
                                  style: const TextStyle(color: Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Hubs grid or All list
                if (context.watch<AppState>().selectedHubTab == 'Hubs' && !appState.isLoadingFeed) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: const _SectionTitle(icon: Icons.hub, color: Color(0xFF93C5FD), title: 'Your Hubs'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCount,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: gridSpacing,
                        mainAxisSpacing: gridSpacing,
                      ),
                      delegate: SliverChildListDelegate([
                        _HubCard(
                          'Urgent & Priority',
                          Icons.error_outline,
                          const [Color(0xFFEF4444), Color(0xFFF97316)],
                          onTap: () {
                            context.read<AppState>().setHubTab('Urgent & Priority');
                            _openHubSheet(context, 'Urgent & Priority');
                          },
                        ),
                        _HubCard(
                          'Conversations',
                          Icons.forum,
                          const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          onTap: () {
                            context.read<AppState>().setHubTab('Conversations');
                            _openHubSheet(context, 'Conversations');
                          },
                        ),
                        _HubCard(
                          'Work & Email',
                          Icons.work_outline,
                          const [Color(0xFF6366F1), Color(0xFF4338CA)],
                          onTap: () {
                            context.read<AppState>().setHubTab('Work & Email');
                            _openHubSheet(context, 'Work & Email');
                          },
                        ),
                        _HubCard(
                          'Reminders',
                          Icons.event,
                          const [Color(0xFFA855F7), Color(0xFF7C3AED)],
                          onTap: () {
                            context.read<AppState>().setHubTab('Reminders');
                            _openHubSheet(context, 'Reminders');
                          },
                        ),
                        _HubCard(
                          'Finance',
                          Icons.attach_money,
                          const [Color(0xFF22C55E), Color(0xFF16A34A)],
                          onTap: () {
                            context.read<AppState>().setHubTab('Finance');
                            _openHubSheet(context, 'Finance');
                          },
                        ),
                        _HubCard(
                          'News & Trends',
                          Icons.trending_up,
                          const [Color(0xFFF59E0B), Color(0xFFD97706)],
                          onTap: () {
                            context.read<AppState>().setHubTab('News & Trends');
                            _openHubSheet(context, 'News & Trends');
                          },
                        ),
                        _HubCard(
                          'Personal',
                          Icons.favorite_border,
                          const [Color(0xFFEC4899), Color(0xFFDB2777)],
                          onTap: () {
                            context.read<AppState>().setHubTab('Personal');
                            _openHubSheet(context, 'Personal');
                          },
                        ),
                      ]),
                    ),
                  ),
                  // Recent Activity section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: const _SectionTitle(
                        icon: LucideIcons.history,
                        color: Colors.white70,
                        title: 'Recent Activity',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final filtered = context.watch<AppState>().filteredFeed;
                          final item = filtered[index];
                          return _RecentActivityCard(item: item);
                        },
                        childCount: (() {
                          final n = context.watch<AppState>().filteredFeed.length;
                          return n > 5 ? 5 : n;
                        })(),
                      ),
                    ),
                  ),
                ] else if (!appState.isLoadingFeed) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: const _SectionTitle(icon: Icons.all_inbox, color: Color(0xFFC084FC), title: 'All'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final items = context.watch<AppState>().hubFeed;
                          final it = items[index];
                          return _feedRow(context, it);
                        },
                        childCount: context.watch<AppState>().hubFeed.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    )); // Added closing parenthesis here
  }

  void _openHubSheet(BuildContext context, String hub) {
    final state = context.read<AppState>();
    // When on 'Hubs' tab, hubFeed contains all; filter by hub
    final items = state.hubFeed.where((e) => e.hub == hub).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hub, size: 16, color: Color(0xFFC084FC)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(hub, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hub == 'Urgent & Priority' ? const Color(0xFFEF4444) : const Color(0x334B5563),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final it = items[i];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              HomeScreen._openItemDetailStatic(context, it);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: GlassCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: it.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(it.icon, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(it.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterSheet(),
    );
  }

  void _openAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddItemSheet(),
    );
  }

  Widget _seg(bool active, String label, {VoidCallback? onTap}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active ? const Color(0x33A855F7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFc084fc) : const Color(0xFF94a3b8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _squareBtn(IconData icon, {VoidCallback? onTap}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0x800F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _priorityCard(IconData icon, String title, String meta, List<Color> grad) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: grad.first.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(meta, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
        ],
        ),
      ),
    );
  }

  Widget _feedRow(BuildContext context, HubItem it) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openItemDetail(context, it),
        borderRadius: BorderRadius.circular(16),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: it.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(it.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(it.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  void _openItemDetail(BuildContext context,HubItem it) {
    _openItemDetailStatic(context, it);
  }

  static void _openItemDetailStatic(BuildContext context, HubItem it) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DetailSheet(
        sender: it.hub,
        title: it.title,
        time: it.meta,
        content: 'This is a sample hub item. In a real app, this would contain the full message or event details.',
        tags: const ['Important', 'Hub'],
        icon: it.icon,
        gradient: it.gradient,
        showAIBadge: false,
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final dynamic item;
  const _RecentActivityCard({required this.item});

  IconData _iconFor(dynamic t) {
    if (t == FeedType.email) return LucideIcons.mail;
    if (t == FeedType.message) return LucideIcons.messageSquare;
    if (t == FeedType.news) return LucideIcons.newspaper;
    if (t == FeedType.whatsapp) return LucideIcons.messageCircle;
    return LucideIcons.bell;
  }

  LinearGradient _gradFor(BuildContext context, dynamic t) {
    if (t == FeedType.email) return AppGradients.email(context);
    if (t == FeedType.message) return AppGradients.message(context);
    if (t == FeedType.news) return AppGradients.news(context);
    if (t == FeedType.whatsapp) return AppGradients.whatsapp(context);
    return AppGradients.message(context);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(item.type);
    final grad = _gradFor(context, item.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => HomeScreen._openItemDetailStatic(
          context,
          HubItem(item.id, item.sender, item.title, '${item.sender} • ${item.time}', [grad.colors.first, grad.colors.last], icon),
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: grad,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(item.time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(LucideIcons.arrowRight, color: Color(0xFF94A3B8), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _SectionTitle({required this.icon, required this.color, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;
  const _HubCard(this.title, this.icon, this.gradient, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AppState>().hubCount(title);
    final isUrgent = title == 'Urgent & Priority';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: gradient.last.withOpacity(0.25), blurRadius: 10),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 10),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [Icon(Icons.arrow_outward_rounded, size: 16, color: Color(0xFF94A3B8))],
                )
              ],
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent ? const Color(0xFFEF4444) : const Color(0x334B5563),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
