import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

// Unified detail popup for events, messages, and hub items
// Mirrors Figma design from HomeFeed.tsx item detail dialog
class DetailSheet extends StatelessWidget {
  final String sender;
  final String title;
  final String? time;
  final String content;
  final List<String> tags;
  final IconData icon;
  final List<Color> gradient;
  final bool showAIBadge;

  const DetailSheet({
    super.key,
    required this.sender,
    required this.title,
    this.time,
    required this.content,
    this.tags = const [],
    required this.icon,
    required this.gradient,
    this.showAIBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF20F172A), // bg-slate-900/95
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon, sender, and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: gradient.last.withOpacity(0.3), blurRadius: 12),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender,
                      style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Time if provided
          if (time != null) ...[
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.slate400),
                const SizedBox(width: 6),
                Text(time!, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Content
          Text(
            content,
            style: const TextStyle(color: AppColors.slate300, fontSize: 14, height: 1.5),
          ),
          // Tags and AI badge
          if (tags.isNotEmpty || showAIBadge) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (showAIBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0x33A855F7), Color(0x33EC4899)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x4DA855F7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.auto_awesome, size: 10, color: Color(0xFFC084FC)),
                        SizedBox(width: 4),
                        Text('AI', style: TextStyle(color: Color(0xFFC084FC), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ...tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x33A855F7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x4DA855F7)),
                      ),
                      child: Text(tag, style: const TextStyle(color: Color(0xFFC084FC), fontSize: 11)),
                    )),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0x800F172A),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x1AFFFFFF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
