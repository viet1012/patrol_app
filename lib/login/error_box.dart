import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactConfig {
  static const String supportEmail = "ngu.nguyen@spclt.com.vn";

  static const String teamsUrl =
      "https://teams.microsoft.com/l/chat/0/0?users=$supportEmail";
}

class ErrorBox extends StatelessWidget {
  final String message;
  final bool isServerError;

  const ErrorBox({
    super.key,
    required this.message,
    required this.isServerError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// MESSAGE
          Text(
            message,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),

          /// ?? ONLY WHEN SERVER ERROR
          if (isServerError) ...[
            const SizedBox(height: 6),

            Row(
              children: [
                /// EMAIL
                GestureDetector(
                  onTap: () {
                    launchUrl(
                      Uri.parse("mailto:${ContactConfig.supportEmail}"),
                    );
                  },
                  child: Text(
                    ContactConfig.supportEmail,
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                /// TEAMS
                GestureDetector(
                  onTap: () {
                    launchUrl(Uri.parse(ContactConfig.teamsUrl));
                  },
                  child: const Text(
                    "Teams",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
