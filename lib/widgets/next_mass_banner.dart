import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/layout_scale.dart';
import '../utils/schedule_parser.dart';
import '../theme/app_text.dart';

/// Shows the soonest upcoming event with a live ticking countdown.
class NextMassBanner extends StatefulWidget {
  final List<ScheduleEntry> schedule;
  final String label; // e.g., "Next Mass", "Next Confession"
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final IconData icon;

  const NextMassBanner({
    super.key,
    required this.schedule,
    required this.label,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    this.icon = Icons.access_time_filled,
  });

  @override
  State<NextMassBanner> createState() => _NextMassBannerState();
}

class _NextMassBannerState extends State<NextMassBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tick every minute — countdown is minute-granularity
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedule.isEmpty) return const SizedBox.shrink();

    // Mass-only banner: a Mass already under way is not something to send
    // someone to, so in-progress entries don't count (kCountMassInProgress).
    final next =
        ScheduleParser.findNextOccurrence(widget.schedule, null, kCountMassInProgress);
    if (next == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final occurrence = next.nextOccurrence(now, kCountMassInProgress);
    final minutes = occurrence.difference(now).inMinutes;
    final countdown = _formatCountdown(minutes);
    final whenLabel = _whenLabel(occurrence, now);
    final timeLabel = _formatTime(next.hour, next.minute);

    final isImminent = minutes <= 60;

    // At large text sizes the countdown pill and the "Tomorrow · 7:30 AM" line
    // can't share a row — the pill kept its width and the line shredded into
    // "Tom / orro / w ·". Past this threshold the pill moves under the time.
    final stacked = context.prefersStackedLayout;
    final countdownPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isImminent
            ? Colors.amber.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        countdown,
        style: AppText.label(color: isImminent ? Colors.black87 : Colors.white)
            .copyWith(fontSize: 13),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.accentColor,
            Color.lerp(widget.accentColor, Colors.black, 0.25)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppText.kicker(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$whenLabel · $timeLabel',
                        style: AppText.bodyLarge(color: Colors.white).copyWith(fontSize: 16),
                      ),
                    ),
                    if (next.languageBadge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          next.languageBadge!,
                          style: AppText.label(color: Colors.white).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (stacked) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: countdownPill),
                ],
              ],
            ),
          ),
          if (!stacked) countdownPill,
        ],
      ),
    );
  }

  String _formatCountdown(int minutes) {
    if (minutes < 1) return 'now';
    if (minutes < 60) return 'in ${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours < 24) {
      return mins == 0 ? 'in ${hours}h' : 'in ${hours}h ${mins}m';
    }
    final days = hours ~/ 24;
    return days == 1 ? 'tomorrow' : 'in ${days}d';
  }

  String _whenLabel(DateTime when, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(when.year, when.month, when.day);
    final days = eventDay.difference(today).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[when.weekday - 1];
  }

  String _formatTime(int hour, int minute) {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mer = hour >= 12 ? 'PM' : 'AM';
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm $mer';
  }
}
