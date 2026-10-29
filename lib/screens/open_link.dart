import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Only web links are opened. Problem links can be typed by the user, so other schemes
/// (javascript:, intent:, file:, tel: …) are refused instead of handed to the system.
bool isWebLink(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}

/// Opens a link with a message if it fails. Problem pages open in an in-app browser sheet
/// (Chrome Custom Tab / Safari view) so you come straight back; videos ([inApp] false) go to the YouTube app.
Future<void> openLink(BuildContext context, String url, {bool inApp = true}) async {
  final mode = inApp && !kIsWeb ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication;
  final opened = isWebLink(url) && await launchUrl(Uri.parse(url.trim()), mode: mode);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}
