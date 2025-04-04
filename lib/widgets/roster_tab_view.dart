import 'package:flutter/material.dart';
import 'package:app/models/roster.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/logger.dart';

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

  // TeamId to numeric id mapping
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

  // Position ordering
  static const List<String> offensePositions = ['QB', 'WR', 'RB', 'OL', 'TE'];
  static const List<String> defensePositions = ['LB', 'DL', 'DB'];
  static const List<String> specialPositions = ['K', 'P', 'LS'];

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      AppLogger.debug('Loading roster for team: ${widget.teamId}');

      // Get numeric id from mapping
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

      // Group players by position
      final groups = <String, List<Roster>>{};
      for (var player in roster) {
        if (!groups.containsKey(player.position)) {
          groups[player.position] = [];
        }
        groups[player.position]!.add(player);
      }

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

  Widget _buildPositionSection(String position, List<Roster> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[200],
          child: Text(
            position,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Age')),
              DataColumn(label: Text('Height')),
              DataColumn(label: Text('Weight')),
              DataColumn(label: Text('College')),
            ],
            rows:
                players.map((player) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundImage: NetworkImage(player.headshotUrl),
                              onBackgroundImageError: (e, s) {
                                AppLogger.error(
                                  'Error loading player image',
                                  e,
                                );
                              },
                              child: const Icon(Icons.person),
                            ),
                            const SizedBox(width: 8),
                            Text(player.name),
                          ],
                        ),
                      ),
                      DataCell(Text(player.number.toString())),
                      DataCell(Text(player.age.toString())),
                      DataCell(Text(player.height)),
                      DataCell(Text(player.weight)),
                      DataCell(Text(player.college)),
                    ],
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue[700],
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  List<Widget> _buildOrderedPositions() {
    final widgets = <Widget>[];

    // OFFENSE
    widgets.add(_buildCategoryHeader('OFFENSE'));
    for (final position in offensePositions) {
      if (_positionGroups.containsKey(position)) {
        widgets.add(
          _buildPositionSection(position, _positionGroups[position]!),
        );
      }
    }

    // DEFENSE
    widgets.add(_buildCategoryHeader('DEFENSE'));
    for (final position in defensePositions) {
      if (_positionGroups.containsKey(position)) {
        widgets.add(
          _buildPositionSection(position, _positionGroups[position]!),
        );
      }
    }

    // SPECIAL TEAMS
    widgets.add(_buildCategoryHeader('SPECIAL'));
    for (final position in specialPositions) {
      if (_positionGroups.containsKey(position)) {
        widgets.add(
          _buildPositionSection(position, _positionGroups[position]!),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadRoster, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_roster.isEmpty) {
      return const Center(child: Text('No roster information available'));
    }

    return SingleChildScrollView(
      child: Column(children: _buildOrderedPositions()),
    );
  }
}
