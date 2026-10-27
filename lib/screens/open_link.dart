import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in the browser (or the LeetCode/YouTube app), with a message if it fails.
Future<void> openLink(BuildContext context, String url) async {
  final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}
