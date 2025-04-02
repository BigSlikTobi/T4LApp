import 'package:flutter/material.dart';
import 'package:app/models/team.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/screens/team_details_page.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  TeamsPageState createState() => TeamsPageState();
}

class TeamsPageState extends State<TeamsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _conferences = ['AFC', 'NFC'];

  List<Team> _teams = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _conferences.length, vsync: this);
    _fetchTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final teams = await SupabaseService.getTeams();
      setState(() {
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load teams: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Group teams by conference and division
  Map<String, Map<String, List<Team>>> _groupTeams() {
    final Map<String, Map<String, List<Team>>> groupedTeams = {};

    // Initialize the structure for both conferences
    for (final conference in _conferences) {
      groupedTeams[conference] = {};
    }

    // Group teams by conference and division
    for (final team in _teams) {
      final conference = team.conference;
      final division = team.division;

      if (!groupedTeams.containsKey(conference)) {
        groupedTeams[conference] = {};
      }

      if (!groupedTeams[conference]!.containsKey(division)) {
        groupedTeams[conference]![division] = [];
      }

      groupedTeams[conference]![division]!.add(team);
    }

    // Sort teams alphabetically within each division
    for (final conference in groupedTeams.keys) {
      for (final division in groupedTeams[conference]!.keys) {
        groupedTeams[conference]![division]!.sort(
          (a, b) => a.fullName.compareTo(b.fullName),
        );
      }
    }

    return groupedTeams;
  }

  Widget _buildTeamCard(Team team) {
    // Make card more compact especially for web view
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(4.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeamDetailsPage(team: team),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Team logo
              Hero(
                tag: 'team-logo-${team.teamId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: Image.asset(
                    team.logoPath,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.sports_football,
                          color: Colors.grey,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Team name
              Expanded(
                child: Text(
                  team.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionSection(String division, List<Team> teams) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we're on a wider screen (web)
        final isWideScreen = constraints.maxWidth > 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(0, 0, 0, 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Color.fromRGBO(0, 0, 0, 0.3)),
                ),
                child: Text(
                  division,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(0, 0, 0, 1),
                  ),
                ),
              ),
            ),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    isWideScreen ? 4 : 2, // 4 columns on web, 2 on mobile
                childAspectRatio: isWideScreen ? 4 : 1.5, // Wider cards on web
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                return _buildTeamCard(teams[index]);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildConferenceTab(
    String conference,
    Map<String, List<Team>> divisions,
  ) {
    final sortedDivisions = divisions.keys.toList()..sort();

    if (sortedDivisions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_football, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No teams found for $conference',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTeams,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Add horizontal padding on wider screens
          final horizontalPadding =
              constraints.maxWidth > 1200
                  ? (constraints.maxWidth - 1200) / 2
                  : constraints.maxWidth > 600
                  ? 50.0
                  : 0.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8.0,
              horizontalPadding,
              8.0,
            ),
            child: Column(
              children:
                  sortedDivisions
                      .map(
                        (division) => _buildDivisionSection(
                          division,
                          divisions[division]!,
                        ),
                      )
                      .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading teams...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchTeams,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedTeams = _groupTeams();
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make background transparent
        elevation: 0, // Remove shadow
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom TabBar with white background and responsive design
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                tabs:
                    _conferences.map((conference) {
                      return Tab(
                        height: 60,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/logos/${conference.toLowerCase()}.png',
                              width: isSmallScreen ? 30 : 40,
                              height: isSmallScreen ? 30 : 40,
                              semanticLabel: '$conference Conference logo',
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Icon(Icons.sports_football),
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 8),
                            Text(conference, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
            // TabBarView
            Expanded(
              child:
                  _isLoading
                      ? _buildLoadingState()
                      : _errorMessage != null
                      ? _buildErrorState()
                      : TabBarView(
                        controller: _tabController,
                        children:
                            _conferences.map((conference) {
                              return _buildConferenceTab(
                                conference,
                                groupedTeams[conference] ?? {},
                              );
                            }).toList(),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
