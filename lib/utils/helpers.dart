import '../services/api_service.dart';

/// 12345 -> 12,345
String formatNumber(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

/// "5m ago", "3h ago", "2d ago"
String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Already loaded users se numbers nikalta hai (koi extra API call nahi).
class UserStats {
  final int total;
  final int online;
  final int active;
  final int expiringSoon;
  final int planValue;

  const UserStats({
    required this.total,
    required this.online,
    required this.active,
    required this.expiringSoon,
    required this.planValue,
  });

  factory UserStats.from(List<AppUser> users) {
    var online = 0;
    var active = 0;
    var expiring = 0;
    var value = 0;
    final now = DateTime.now();

    for (final user in users) {
      if (user.type == 'online') online++;
      if (user.isActive) active++;

      final membership = user.membership;
      if (membership != null && !membership.expired) {
        value += membership.price;
        if (membership.end.difference(now).inDays <= 7) expiring++;
      }
    }

    return UserStats(
      total: users.length,
      online: online,
      active: active,
      expiringSoon: expiring,
      planValue: value,
    );
  }
}
