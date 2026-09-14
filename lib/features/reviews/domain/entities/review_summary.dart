/// Lightweight domain model for displaying review snippets in lists or profiles.
class ReviewSummary {
  final String id;
  final String reviewerName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewSummary({
    required this.id,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
}
