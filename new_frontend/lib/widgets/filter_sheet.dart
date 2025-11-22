import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';

// Visual bottom sheet with filter controls for Home/ToDo lists
// CSS→Flutter: p-4 (16), rounded-2xl (20), glass bg + border-white/10
class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    String localSearch = state.search;
    String localHub = state.selectedHubTab;

    return _GlassSheet(
      child: StatefulBuilder(builder: (context, set) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            // Search
            TextField(
              decoration: const InputDecoration(hintText: 'Search…'),
              controller: TextEditingController(text: localSearch),
              onChanged: (v) => set(() => localSearch = v),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            // Hubs selector
            const Text('Hub', style: TextStyle(color: AppColors.slate300, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in ['All', ...state.hubs.map((h) => h.name)])
                  ChoiceChip(
                    label: Text(h),
                    labelStyle: TextStyle(color: localHub == h ? Colors.white : AppColors.slate300),
                    selected: localHub == h,
                    selectedColor: const Color(0x33A855F7),
                    backgroundColor: const Color(0x1AFFFFFF),
                    onSelected: (_) => set(() => localHub = h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Apply to state
                      context.read<AppState>()
                        ..search = localSearch
                        ..setHubTab(localHub);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                )
              ],
            )
          ],
        );
      }),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x800F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: child,
    );
  }
}
