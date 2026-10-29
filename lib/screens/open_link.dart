import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Only web links are opened. Problem links can be typed by the user, so other schemes
/// (javascript:, intent:, file:, tel: …) are refused instead of handed to the system.
bool isWebLink(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}

/// Opens a link in the browser (or the LeetCode/YouTube app), with a message if it fails.
Future<void> openLink(BuildContext context, String url) async {
  final opened = isWebLink(url) && await launchUrl(Uri.parse(url.trim()), mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}
