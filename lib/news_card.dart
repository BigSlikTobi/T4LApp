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

  Future<void> _processImageUrl() async {
    // Get the processed image URL
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
        AppLogger.error('Error processing image URL', e);
        if (mounted) {
          setState(() {
            _processedImageUrl = widget.article.imageUrl;
          });
        }
      }
    }
  }

  Future<void> _fetchTeamCode() async {
    if (widget.article.team == null || widget.article.team!.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    try {
      // Parse the team ID
      final teamId = int.tryParse(widget.article.team!) ?? widget.article.team!;

      // Query the Teams table for the team with the given ID
      final response =
          await SupabaseService.client
              .from('Teams')
              .select('teamId')
              .eq('id', teamId)
              .maybeSingle();

      if (mounted) {
        setState(() {
          teamCode = response != null ? response['teamId'] : null;
          isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error fetching team code', e);
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildFallbackImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          size: 48,
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final theme = Theme.of(context);
    final statusUpper = status.toUpperCase();

    // Determine color based on status
    Color badgeColor;
    switch (statusUpper) {
      case 'BREAKING':
        badgeColor = Colors.red;
        break;
      case 'NEW':
        badgeColor = Colors.green;
        break;
      case 'FEATURED':
        badgeColor = Colors.blue;
        break;
      default:
        badgeColor = theme.colorScheme.primary;
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
    final headline =
        isEnglish
            ? widget.article.englishHeadline
            : widget.article.germanHeadline;

    return LayoutBuilder(
      builder: (context, constraints) {
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
                AspectRatio(
                  aspectRatio: widget.variant == 'horizontal' ? 16 / 9 : 4 / 3,
                  child: Stack(
                    children: [
                      SizedBox.expand(
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
                                                  _buildLoadingPlaceholder(
                                                    theme,
                                                  ),
                                          errorWidget:
                                              (context, url, error) =>
                                                  _buildFallbackImage(theme),
                                        ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.7),
                                          ],
                                          stops: const [0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                : _buildFallbackImage(theme),
                      ),
                      if (teamCode != null && !isLoading)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.asset(
                                'assets/logos/${_getTeamLogo(teamCode!)}',
                                height: 24,
                                width: 24,
                              ),
                            ),
                          ),
                        ),
                      if (widget.article.status != null &&
                          widget.article.status!.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildStatusBadge(
                            context,
                            widget.article.status!,
                          ),
                        ),
                      if (widget.article.isUpdate)
                        Positioned(
                          top:
                              widget.article.status != null &&
                                      widget.article.status!.isNotEmpty
                                  ? 36
                                  : 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.update,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  isEnglish ? 'UPDATE' : 'AKTUELL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Text(
                          widget.article.createdAt != null
                              ? DateFormat(
                                'MMM d, yyyy',
                              ).format(widget.article.createdAt!)
                              : '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 12.0,
                    top: 12.0,
                  ),
                  child: Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.variant == 'horizontal' ? 14 : null,
                    ),
                    maxLines: null, // Remove maxLines constraint
                    overflow:
                        TextOverflow.visible, // Allow text to wrap naturally
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTeamLogo(String code) {
    final String normalizedCode = code.toUpperCase();
    switch (normalizedCode) {
      case 'ARI':
        return 'arizona_cardinals.png';
      case 'ATL':
        return 'atlanta_falcons.png';
      case 'BAL':
        return 'baltimore_ravens.png';
      case 'BUF':
        return 'buffalo_bills.png';
      case 'CAR':
        return 'carolina_panthers.png';
      case 'CHI':
        return 'chicago_bears.png';
      case 'CIN':
        return 'cincinnati_bengals.png';
      case 'CLE':
        return 'cleveland_browns.png';
      case 'DAL':
        return 'dallas_cowboys.png';
      case 'DEN':
        return 'denver_broncos.png';
      case 'DET':
        return 'detroit_lions.png';
      case 'GB':
        return 'Green_bay_packers.png';
      case 'HOU':
        return 'houston_texans.png';
      case 'IND':
        return 'indianapolis_colts.png';
      case 'JAX':
        return 'jacksonville_jaguars.png';
      case 'KC':
        return 'kansas_city_chiefs.png';
      case 'LV':
        return 'las_vegas_raiders.png';
      case 'LAC':
        return 'los_angeles_chargers.png';
      case 'LAR':
        return 'los_angeles_rams.png';
      case 'MIA':
        return 'miami_dolphins.png';
      case 'MIN':
        return 'minnesota_vikings.png';
      case 'NE':
        return 'new_england_patriots.png';
      case 'NO':
        return 'new_orleans_saints.png';
      case 'NYG':
        return 'new_york_giants.png';
      case 'NYJ':
        return 'new_york_jets.png';
      case 'PHI':
        return 'philadelphia_eagles.png';
      case 'PIT':
        return 'pittsbourg_steelers.png';
      case 'SF':
        return 'san_francisco_49ers.png';
      case 'SEA':
        return 'seattle_seahawks.png';
      case 'TB':
        return 'tampa_bay_buccaneers.png';
      case 'TEN':
        return 'tennessee_titans.png';
      case 'WAS':
        return 'washington_commanders.png';
      default:
        return 'nfl.png';
    }
  }
}
