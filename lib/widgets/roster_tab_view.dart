import 'package:flutter/material.dart';
import 'package:app/models/roster.dart'; // Assuming Roster model is defined correctly
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/logger.dart';

// --- Define Colors from Style Sheet (still useful for accents/text) ---
const Color t4lPrimaryGreen = Color(0xFF20452b);
const Color t4lDarkGrey = Color(0xFF333333); // Good for primary text on white
const Color t4lBlack = Color(0xFF000000);
// const Color t4lOffWhite = Color(0xFFF5F5F5); // No longer needed for main text/bg
const Color t4lSecondaryGreyText = Color(
  0xFF616161,
); // Colors.grey[700] - For subtitles etc.
const Color t4lLightGreyDivider = Color(
  0xFFE0E0E0,
); // Colors.grey[300] - For dividers
const Color t4lErrorRed = Color(
  0xFFD32F2F,
); // Colors.red[700] - Standard error red

class RosterTabView extends StatefulWidget {
  final String teamId;

  const RosterTabView({super.key, required this.teamId});

  @override
  State<RosterTabView> createState() => _RosterTabViewState();
}

class _RosterTabViewState extends State<RosterTabView> {
  List<Roster> _roster = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, List<Roster>> _positionGroups = {};

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  // --- LOGIC REMAINS UNCHANGED ---
  static const Map<String, int> teamIdMap = {
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

  static const List<String> offensePositions = ['QB', 'WR', 'RB', 'OL', 'TE'];
  static const List<String> defensePositions = ['LB', 'DL', 'DB'];
  static const List<String> specialPositions = ['K', 'P', 'LS'];

  Future<void> _loadRoster() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      AppLogger.debug('Loading roster for team: ${widget.teamId}');
      final numericId = teamIdMap[widget.teamId.toUpperCase()];
      if (numericId == null) {
        throw Exception('Invalid team ID: ${widget.teamId}');
      }
      AppLogger.debug('Using numeric ID $numericId for team ${widget.teamId}');

      final roster = await SupabaseService.getRoster(
        teamId: numericId.toString(),
        page: 1,
        pageSize: 100,
      );

      AppLogger.debug(
        'Received ${roster.length} players from API for team ${widget.teamId}',
      );

      if (!mounted) return;

      if (roster.isEmpty) {
        AppLogger.debug('No roster data received for team: ${widget.teamId}');
        setState(() {
          _errorMessage = 'No roster information available for this team';
          _isLoading = false;
        });
        return;
      }

      final groups = <String, List<Roster>>{};
      for (var player in roster) {
        if (!groups.containsKey(player.position)) {
          groups[player.position] = [];
        }
        groups[player.position]!.add(player);
      }

      groups.forEach((key, value) {
        value.sort((a, b) => (a.number).compareTo(b.number));
      });

      if (!mounted) return;

      setState(() {
        _roster = roster;
        _positionGroups = groups;
        _isLoading = false;
      });

      AppLogger.debug(
        'Successfully loaded ${roster.length} players for team: ${widget.teamId}',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error loading roster for team: ${widget.teamId}',
        e,
        stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
            e.toString().contains('Exception:')
                ? e.toString().split('Exception:')[1].trim()
                : 'Failed to load roster. Please try again later.';
        _isLoading = false;
      });
    }
  }
  // --- END OF UNCHANGED LOGIC ---

  // --- STYLING CHANGES FOR LIGHT THEME ---

  Widget _buildPlayerRow(Roster player, BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 6.0,
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: t4lLightGreyDivider, // Light grey placeholder bg
        backgroundImage: NetworkImage(player.headshotUrl),
        onBackgroundImageError: (exception, stackTrace) {
          AppLogger.error(
            'Error loading player image: ${player.headshotUrl}',
            exception,
            stackTrace,
          );
        },
        child:
            player.headshotUrl.isEmpty
                ? const Icon(
                  Icons.person,
                  size: 25,
                  color: t4lSecondaryGreyText,
                ) // Darker grey icon
                : null,
      ),
      title: Text(
        '#${player.number} ${player.name}',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: t4lDarkGrey, // Dark text for title
          fontSize: 15,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: Wrap(
          spacing: 14.0,
          runSpacing: 5.0,
          children: [
            _buildDetailItem(Icons.cake_outlined, '${player.age} yrs', context),
            _buildDetailItem(Icons.height, player.height, context),
            _buildDetailItem(Icons.scale_outlined, player.weight, context),
            if (player.college.isNotEmpty)
              _buildDetailItem(Icons.school_outlined, player.college, context),
          ],
        ),
      ),
      dense: true,
    );
  }

  Widget _buildDetailItem(IconData icon, String text, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: t4lSecondaryGreyText), // Grey icon
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: t4lSecondaryGreyText, // Grey text
          ),
        ),
      ],
    );
  }

  Widget _buildPositionSection(
    String position,
    List<Roster> players,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Row(
              children: [
                Text(
                  position,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: t4lBlack, // Black or t4lDarkGrey for position header
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${players.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    color: t4lSecondaryGreyText, // Grey count
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: players.length,
            itemBuilder: (context, index) {
              return _buildPlayerRow(players[index], context);
            },
            separatorBuilder:
                (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 70,
                  endIndent: 16,
                  color: t4lLightGreyDivider, // Light grey divider
                ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    List<String> positions,
    BuildContext context,
  ) {
    bool hasPlayers = positions.any((pos) => _positionGroups.containsKey(pos));
    if (!hasPlayers) return const SizedBox.shrink();

    final availablePositions =
        positions.where((pos) => _positionGroups.containsKey(pos)).toList();

    return Card(
      key: ValueKey(title),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      color: Colors.white,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('expansion_$title'),
        initiallyExpanded: title == 'OFFENSE',
        maintainState: true,
        backgroundColor: Colors.grey[50],
        collapsedBackgroundColor: Colors.white,
        iconColor: t4lSecondaryGreyText,
        collapsedIconColor: t4lSecondaryGreyText,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: t4lPrimaryGreen,
          ),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 8.0),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
        children:
            availablePositions
                .map(
                  (pos) => _buildPositionSection(
                    pos,
                    _positionGroups[pos]!,
                    context,
                  ),
                )
                .toList(),
      ),
    );
  }

  List<Widget> _buildOrderedPositions(BuildContext context) {
    return [
      _buildCategoryCard('OFFENSE', offensePositions, context),
      _buildCategoryCard('DEFENSE', defensePositions, context),
      _buildCategoryCard('SPECIAL TEAMS', specialPositions, context),
    ];
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(
          color: t4lPrimaryGreen, // Green loading indicator
        ),
      );
    } else if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: t4lErrorRed,
              ), // Error icon color
              const SizedBox(height: 20),
              const Text(
                'Error Loading Roster',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: t4lErrorRed,
                ), // Error text color
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: t4lSecondaryGreyText,
                ), // Grey text for detail
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                ), // White icon on button
                onPressed: _loadRoster,
                label: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ), // White text on button
                style: ElevatedButton.styleFrom(
                  backgroundColor: t4lPrimaryGreen, // Green button background
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_roster.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 60,
                color: Colors.grey[400],
              ), // Lighter grey icon
              const SizedBox(height: 20),
              const Text(
                'No Roster Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: t4lDarkGrey,
                ), // Dark grey title
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Roster data is currently unavailable for this team.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t4lSecondaryGreyText,
                ), // Grey detail text
              ),
            ],
          ),
        ),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _loadRoster,
        color: t4lPrimaryGreen, // Green refresh indicator color
        backgroundColor: Colors.white, // White background for indicator circle
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8.0, bottom: 24),
          child: Column(children: _buildOrderedPositions(context)),
        ),
      );
    }

    // Apply the main white background color here
    return Container(
      color: Colors.white, // Apply the main white background
      child: content,
    );
  }
}
