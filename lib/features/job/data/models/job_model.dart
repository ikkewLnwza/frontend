class JobModel {
  final String id;
  final String title;
  final String type; // e.g., 'Freelance', 'Part-time', 'Delivery'
  final String estimatedIncome;
  final String incomeType; // 'daily' or 'monthly'
  final String description;
  final String requirement;
  final Map<String, String> platformLinks; // e.g., {'JobsDB': 'url', 'Fastwork': 'url'}
  final bool isRecommended;
  final List<String> suitableOccupations;
  final List<String> requiredSkills; // New field for skill-based matching
  final String? recommendationReason;
  final String dataSource; // New field for reference

  JobModel({
    required this.id,
    required this.title,
    required this.type,
    required this.estimatedIncome,
    required this.incomeType,
    required this.description,
    required this.requirement,
    required this.platformLinks,
    required this.dataSource,
    this.isRecommended = false,
    this.suitableOccupations = const [],
    this.requiredSkills = const [],
    this.recommendationReason,
  }) : assert(title.isNotEmpty, 'Job title cannot be empty'),
       assert(estimatedIncome.isNotEmpty, 'Estimated income must be provided'),
       assert(platformLinks.isNotEmpty, 'At least one platform link must be provided');
}
