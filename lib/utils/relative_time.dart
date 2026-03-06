String formatRelativeTime(DateTime? dt) {
  if (dt == null) return 'A l\'instant';
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 45) return 'A l\'instant';
  if (diff.inMinutes < 1) return 'Il y a 1 min';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 2) return 'Il y a 1 h';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays < 2) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return 'Il y a $weeks sem';
  final months = (diff.inDays / 30).floor();
  if (months < 12) return 'Il y a $months mois';
  final years = (diff.inDays / 365).floor();
  return 'Il y a $years an${years > 1 ? 's' : ''}';
}
