Future<String> getProxiedImageUrl(String url) async {
  // For non-web platforms, return the URL as-is
  return url;
}
