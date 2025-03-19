import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app/models/article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/image_utils.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'dart:convert';

class NewsCard extends StatefulWidget {
  final Article article;
  final Function(int) onArticleClick;
  final String variant; // 'vertical' or 'horizontal'

  const NewsCard({
    super.key,
    required this.article,
    required this.onArticleClick,
    this.variant = 'vertical',
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  String? teamCode;
  bool isLoading = true;
  String? _processedImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchTeamCode();
    _processImageUrl();
  }

  // Fetch the teamId (code like "ARI") from the Teams table using the numerical ID
  Future<void> _fetchTeamCode() async {
    if (widget.article.team == null || widget.article.team!.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Parse the team ID - ensure it's a valid value for the query
      final teamId = int.tryParse(widget.article.team!) ?? widget.article.team!;

      // Query the Teams table for the team with the given ID
      final response =
          await SupabaseService.client
              .from('Teams')
              .select('teamId')
              .eq('id', teamId) // Now using the non-nullable teamId
              .maybeSingle();

      if (response != null) {
        setState(() {
          teamCode = response['teamId'] as String?;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error fetching team', e);
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _processImageUrl() async {
    if (widget.article.imageUrl != null &&
        widget.article.imageUrl!.isNotEmpty) {
      try {
        final processed = await getProxiedImageUrl(widget.article.imageUrl!);
        if (mounted) {
          setState(() {
            _processedImageUrl = processed;
          });
        }
      } catch (e) {
        AppLogger.error('Error processing image', e);
        if (mounted) {
          setState(() {
            _processedImageUrl = widget.article.imageUrl;
          });
        }
      }
    }
  }

  // Builds a badge widget if the article has a status (e.g., NEW or UPDATED).
  Widget _buildBadge() {
    if (widget.article.status == null) return SizedBox.shrink();

    final statusUpper = widget.article.status!.toUpperCase();
    Color badgeColor;

    if (statusUpper == 'NEW') {
      badgeColor = Colors.orange;
    } else if (statusUpper == 'UPDATED') {
      badgeColor = Colors.blue;
    } else {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(
          red: badgeColor.r / 255,
          green: badgeColor.g / 255,
          blue: badgeColor.b / 255,
          alpha: 0.9,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusUpper,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish =
        languageProvider.currentLanguage == LanguageProvider.english;

    // Select content based on current language
    final headline =
        isEnglish
            ? widget.article.englishHeadline
            : widget.article.germanHeadline;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double imageHeight =
            constraints.maxWidth * 0.6; // Increased to 60%

        return GestureDetector(
          onTap: () => widget.onArticleClick(widget.article.id),
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: imageHeight,
                      child:
                          widget.article.imageUrl != null &&
                                  widget.article.imageUrl!.isNotEmpty
                              ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  _processedImageUrl != null &&
                                          _processedImageUrl!.startsWith(
                                            'data:image',
                                          )
                                      ? Image.memory(
                                        base64Decode(
                                          _processedImageUrl!.split(',')[1],
                                        ),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _buildFallbackImage(theme),
                                      )
                                      : CachedNetworkImage(
                                        imageUrl:
                                            _processedImageUrl ??
                                            widget.article.imageUrl!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        placeholder:
                                            (context, url) =>
                                                _buildLoadingPlaceholder(theme),
                                        errorWidget:
                                            (context, url, error) =>
                                                _buildFallbackImage(theme),
                                      ),
                                ],
                              )
                              : _buildNoImagePlaceholder(theme),
                    ),
                    Positioned(top: 8, left: 8, child: _buildBadge()),
                    // Always show a team logo, either the specific team or NFL
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            red: 1.0,
                            green: 1.0,
                            blue: 1.0,
                            alpha: 0.9,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        child:
                            isLoading
                                ? CircularProgressIndicator(strokeWidth: 2)
                                : Image.asset(
                                  'assets/logos/${_getTeamLogo()}',
                                  fit: BoxFit.contain,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          Image.asset(
                                            'assets/logos/nfl.png',
                                            fit: BoxFit.contain,
                                          ),
                                ),
                      ),
                    ),
                    // Add language indicator in top-right corner
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isEnglish ? 'EN' : 'DE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 0.0),
                  child: Text(
                    headline,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize:
                          (theme.textTheme.titleSmall?.fontSize ?? 14) * 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
                  child: Text(
                    widget.article.createdAt != null
                        ? DateFormat(
                          'MMM d, yyyy',
                        ).format(widget.article.createdAt!)
                        : '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontSize: 11, // Smaller font size for date
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to get team logo filename based on team ID from database
  String _getTeamLogo() {
    if (teamCode == null || teamCode!.isEmpty) {
      return 'nfl.png';
    }

    return _teamLogoMapping[teamCode!] ?? 'nfl.png';
  }

  // Static mapping of team IDs to logo filenames
  static const Map<String, String> _teamLogoMapping = {
    'ARI': 'arizona_cardinals.png',
    'ATL': 'atlanta_falcons.png',
    'BAL': 'baltimore_ravens.png',
    'BUF': 'buffalo_bills.png',
    'CAR': 'carolina_panthers.png',
    'CHI': 'chicago_bears.png',
    'CIN': 'cincinnati_bengals.png',
    'CLE': 'cleveland_browns.png',
    'DAL': 'dallas_cowboys.png',
    'DEN': 'denver_broncos.png',
    'DET': 'detroit_lions.png',
    'GB': 'Green_bay_packers.png',
    'HOU': 'houston_texans.png',
    'IND': 'indianapolis_colts.png',
    'JAX': 'jacksonville_jaguars.png',
    'KC': 'kansas_city_chiefs.png',
    'LV': 'las_vegas_raiders.png',
    'LAC': 'los_angeles_chargers.png',
    'LAR': 'los_angeles_rams.png',
    'MIA': 'miami_dolphins.png',
    'MIN': 'minnesota_vikings.png',
    'NE': 'new_england_patriots.png',
    'NO': 'new_orleans_saints.png',
    'NYG': 'new_york_giants.png',
    'NYJ': 'new_york_jets.png',
    'PHI': 'philadelphia_eagles.png',
    'PIT': 'pittsbourg_steelers.png',
    'SF': 'san_francisco_49ers.png',
    'SEA': 'seattle_seahawks.png',
    'TB': 'tampa_bay_buccaneers.png',
    'TEN': 'tennessee_titans.png',
    'WAS': 'washington_commanders.png',
  };

  Widget _buildLoadingPlaceholder(ThemeData theme) => Container(
    color: theme.colorScheme.surface,
    child: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildFallbackImage(ThemeData theme) => Container(
    color: theme.colorScheme.surface,
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.red, size: 32),
    ),
  );

  Widget _buildNoImagePlaceholder(ThemeData theme) => Container(
    color: theme.colorScheme.surface,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: theme.colorScheme.onSurface.withValues(
              red: theme.colorScheme.onSurface.r / 255,
              green: theme.colorScheme.onSurface.g / 255,
              blue: theme.colorScheme.onSurface.b / 255,
              alpha: 0.6,
            ),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'No image',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(
                red: theme.colorScheme.onSurface.r / 255,
                green: theme.colorScheme.onSurface.g / 255,
                blue: theme.colorScheme.onSurface.b / 255,
                alpha: 0.6,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
