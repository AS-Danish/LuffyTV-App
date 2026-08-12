class RelatedSeason {
  final String id;
  final String title;
  final String? titleJp;
  final String posterUrl;
  final String? relation;
  final String href;
  final String? slug;

  const RelatedSeason({
    required this.id,
    required this.title,
    this.titleJp,
    required this.posterUrl,
    this.relation,
    required this.href,
    this.slug,
  });

  factory RelatedSeason.fromJson(Map<String, dynamic> json) {
    return RelatedSeason(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      titleJp: json['titleJp'] as String?,
      posterUrl: json['image'] as String? ?? '',
      relation: json['relation'] as String?,
      href: json['href'] as String? ?? '',
      slug: json['slug'] as String?,
    );
  }
}
