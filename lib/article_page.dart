import 'package:flutter/material.dart';
import 'package:app/models/article.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/utils/image_utils.dart';
import 'package:app/utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ArticlePage extends StatefulWidget {
  final Article article;

  const ArticlePage({super.key, required this.article});

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  String? _processedImageUrl;
  String? teamCode;
  bool isLoading = true;
  List<Article> updatedArticles = []; // To store the articles that are updated

  @override
  void initState() {
    super.initState();
    _processImageUrls();
    _fetchTeamCode();
    if (widget.article.update) {
      _fetchUpdatedArticles();
    }
  }

  Future<void> _fetchUpdatedArticles() async {
    try {
      final articleVectorData = await SupabaseService.getUpdatedArticles(
        widget.article.id,
      );
      if (mounted) {
        setState(() {
          updatedArticles =
              articleVectorData
                  .map((article) => Article.fromJson(article))
                  .toList();
        });
      }
    } catch (e) {
      AppLogger.error('Error fetching updated articles', e);
    }
  }

  Future<void> _processImageUrls() async {
    // Process the main image
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
        AppLogger.error('Error processing main image', e);
        if (mounted) {
          setState(() {
            _processedImageUrl = widget.article.imageUrl;
          });
        }
      }
    }
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
              .eq('id', teamId)
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

    final articleContent =
        isEnglish
            ? widget.article.englishArticle
            : widget.article.germanArticle;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: theme.colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Image.asset(
                  'assets/logos/${_getTeamLogo()}',
                  height: 30,
                ),
              ),
            Flexible(
              child: Text(
                isEnglish ? 'Article' : 'Artikel',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Language toggle button
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                languageProvider.toggleLanguage();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      isEnglish ? 'EN' : 'DE',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.language,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate the content width and padding based on screen width
          final isWeb = constraints.maxWidth > 900;
          final contentWidth = isWeb ? 900.0 : constraints.maxWidth;

          return Center(
            child: SizedBox(
              width: contentWidth,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Article headline
                      Text(
                        headline,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Show update badge if this is an update to a previous article
                      if (widget.article.update)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.update,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  isEnglish
                                      ? 'UPDATED STORY'
                                      : 'AKTUALISIERTE GESCHICHTE',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Date and source
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              widget.article.createdAt != null
                                  ? DateFormat(
                                    'MMM d, yyyy',
                                  ).format(widget.article.createdAt!)
                                  : '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            if (widget.article.sourceAuthor != null &&
                                widget.article.sourceAuthor!.isNotEmpty)
                              Text(
                                ' | ${widget.article.sourceAuthor}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Main image
                      if (_processedImageUrl != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                _processedImageUrl!.startsWith('data:image')
                                    ? Image.memory(
                                      base64Decode(
                                        _processedImageUrl!.split(',')[1],
                                      ),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildFallbackImage(theme),
                                    )
                                    : CachedNetworkImage(
                                      imageUrl: _processedImageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder:
                                          (context, url) =>
                                              _buildLoadingPlaceholder(theme),
                                      errorWidget:
                                          (context, url, error) =>
                                              _buildFallbackImage(theme),
                                    ),
                          ),
                        ),

                      // HTML content
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Html(
                          data: articleContent,
                          style: {
                            "body": Style(
                              fontSize: FontSize(16.0),
                              fontFamily: 'Roboto',
                              lineHeight: LineHeight(1.6),
                            ),
                            "h1": Style(
                              fontSize: FontSize(24.0),
                              fontWeight: FontWeight.bold,
                              margin: Margins(
                                top: Margin(16),
                                bottom: Margin(16),
                              ),
                            ),
                            "h2": Style(
                              fontSize: FontSize(20.0),
                              fontWeight: FontWeight.bold,
                              margin: Margins(
                                top: Margin(12),
                                bottom: Margin(12),
                              ),
                            ),
                            "h3": Style(
                              fontSize: FontSize(18.0),
                              fontWeight: FontWeight.bold,
                              margin: Margins(
                                top: Margin(8),
                                bottom: Margin(8),
                              ),
                            ),
                            "p": Style(margin: Margins(bottom: Margin(16))),
                            "a": Style(color: theme.colorScheme.primary),
                            "ul": Style(
                              margin: Margins(
                                top: Margin(8),
                                bottom: Margin(8),
                              ),
                            ),
                            "ol": Style(
                              margin: Margins(
                                top: Margin(8),
                                bottom: Margin(8),
                              ),
                            ),
                            "li": Style(margin: Margins(bottom: Margin(4))),
                            "blockquote": Style(
                              backgroundColor: theme.colorScheme.surface,
                              border: Border(
                                left: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 4.0,
                                ),
                              ),
                              padding: HtmlPaddings(
                                left: HtmlPadding(16),
                                right: HtmlPadding(16),
                                top: HtmlPadding(16),
                                bottom: HtmlPadding(16),
                              ),
                              margin: Margins(
                                top: Margin(16),
                                bottom: Margin(16),
                              ),
                              fontStyle: FontStyle.italic,
                            ),
                          },
                        ),
                      ),

                      // Display updated articles section if applicable
                      if (updatedArticles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(thickness: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                child: Text(
                                  isEnglish
                                      ? 'UPDATES PREVIOUS STORIES'
                                      : 'AKTUALISIERT FRÜHERE GESCHICHTEN',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              ...updatedArticles.map((article) {
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12.0),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  ArticlePage(article: article),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isEnglish
                                                ? article.englishHeadline
                                                : article.germanHeadline,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          if (article.createdAt != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                DateFormat(
                                                  'MMM d, yyyy',
                                                ).format(article.createdAt!),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .secondary,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
