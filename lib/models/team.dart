class Team {
  final String teamId;
  final String fullName;
  final String division;
  final String conference;

  Team({
    required this.teamId,
    required this.fullName,
    required this.division,
    required this.conference,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    // Handle the misspelled "confernece" field in the API response
    // We expect "conference" but the API returns "confernece"
    String conferenceValue = '';
    if (json['conference'] != null) {
      conferenceValue = json['conference'] ?? '';
    } else if (json['confernece'] != null) {
      // Handle the misspelled field
      conferenceValue = json['confernece'] ?? '';
    }

    return Team(
      teamId: json['teamId'] ?? '',
      fullName: json['fullName'] ?? '',
      division: json['division'] ?? '',
      conference: conferenceValue,
    );
  }

  String get logoPath {
    // Map team IDs to the corresponding logo filenames
    final Map<String, String> teamLogoMap = {
      'ARI': 'arizona_cardinals',
      'ATL': 'atlanta_falcons',
      'BAL': 'baltimore_ravens',
      'BUF': 'buffalo_bills',
      'CAR': 'carolina_panthers',
      'CHI': 'chicago_bears',
      'CIN': 'cincinnati_bengals',
      'CLE': 'cleveland_browns',
      'DAL': 'dallas_cowboys',
      'DEN': 'denver_broncos',
      'DET': 'detroit_lions',
      'GB': 'Green_bay_packers', // Note the capital 'G' to match the filename
      'HOU': 'houston_texans',
      'IND': 'indianapolis_colts',
      'JAC': 'jacksonville_jaguars',
      'JAX': 'jacksonville_jaguars', // Alternative ID
      'KC': 'kansas_city_chiefs',
      'LV': 'las_vegas_raiders',
      'LAC': 'los_angeles_chargers',
      'LAR': 'los_angeles_rams',
      'MIA': 'miami_dolphins',
      'MIN': 'minnesota_vikings',
      'NE': 'new_england_patriots',
      'NO': 'new_orleans_saints',
      'NYG': 'new_york_giants',
      'NYJ': 'new_york_jets',
      'PHI': 'philadelphia_eagles',
      'PIT': 'pittsbourg_steelers',
      'SF': 'san_francisco_49ers',
      'SEA': 'seattle_seahawks',
      'TB': 'tampa_bay_buccaneers',
      'TEN': 'tennessee_titans',
      'WAS': 'washington_commanders',
      'WSH': 'washington_commanders', // Alternative ID
      // Conference logos
      'AFC': 'afc',
      'NFC': 'nfc',
      'NFL': 'nfl',
    };

    // Get the logo filename from the map, or use a default if not found
    final logoName = teamLogoMap[teamId] ?? teamId.toLowerCase();
    return 'assets/logos/$logoName.png';
  }

  @override
  String toString() {
    return 'Team{teamId: $teamId, fullName: $fullName, division: $division, conference: $conference}';
  }
}
