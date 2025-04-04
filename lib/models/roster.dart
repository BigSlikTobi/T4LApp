class Roster {
  final String teamId;
  final int id; // Adding numeric id field
  final String name;
  final int number;
  final String headshotUrl;
  final String position;
  final int age;
  final String height;
  final String weight;
  final String college;
  final String yearsExp;

  Roster({
    required this.teamId,
    required this.id, // Added to constructor
    required this.name,
    required this.number,
    required this.headshotUrl,
    required this.position,
    required this.age,
    required this.height,
    required this.weight,
    required this.college,
    required this.yearsExp,
  });

  factory Roster.fromJson(Map<String, dynamic> json) {
    // Clean and parse the height (remove quotes and convert to standard format)
    String cleanHeight = (json['height'] as String).replaceAll('"', '');

    // Clean and parse the weight (remove 'lbs' and convert to standard format)
    String cleanWeight = (json['weight'] as String).replaceAll(' lbs', '');

    // Handle missing id by using teamId mapping
    String teamIdStr = json['teamId'] as String;
    int numericId = _getNumericIdFromTeamId(teamIdStr);

    return Roster(
      teamId: teamIdStr,
      id:
          json['id'] as int? ??
          numericId, // Use the mapped ID if API id is missing
      name: json['name'] as String,
      number: json['number'] as int,
      headshotUrl: json['headshotURL'] as String,
      position: json['position'] as String,
      age: json['age'] as int,
      height: cleanHeight,
      weight: cleanWeight,
      college: json['college'] as String,
      yearsExp: json['years_exp'].toString(),
    );
  }

  // TeamId to numeric id mapping
  static int _getNumericIdFromTeamId(String teamId) {
    const Map<String, int> teamIdMap = {
      'ARI': 1,
      'ATL': 2,
      'BAL': 5,
      'BUF': 6,
      'CAR': 7,
      'CHI': 8,
      'CIN': 9,
      'CLE': 10,
      'DAL': 11,
      'DEN': 12,
      'DET': 13,
      'GB': 14,
      'HOU': 15,
      'IND': 16,
      'JAX': 17,
      'KC': 18,
      'LV': 19,
      'LAC': 20,
      'LAR': 21,
      'MIA': 22,
      'MIN': 23,
      'NE': 24,
      'NO': 25,
      'NYG': 26,
      'NYJ': 27,
      'PHI': 28,
      'PIT': 29,
      'SF': 30,
      'SEA': 31,
      'TB': 32,
      'TEN': 33,
      'WAS': 34,
    };
    return teamIdMap[teamId.toUpperCase()] ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'id': id, // Include id in JSON
      'name': name,
      'number': number,
      'headshotURL': headshotUrl,
      'position': position,
      'age': age,
      'height': height,
      'weight': weight,
      'college': college,
      'years_exp': yearsExp,
    };
  }
}
