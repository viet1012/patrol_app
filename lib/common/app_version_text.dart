import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';

import '../animate/glow_title.dart';

class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    // info.version = 1.9.4, info.buildNumber = 58
    return 'V${info.version}+${info.buildNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getVersion(),
      builder: (_, snap) {
        final text = snap.data ?? 'V...';
        return EmbossGlowTitle(text: text, fontSize: 13);
      },
    );
  }
}
