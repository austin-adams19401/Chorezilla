import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:chorezilla/state/app_state.dart';

class DevToolsPage extends StatefulWidget {
  const DevToolsPage({super.key});

  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage> {
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (!mounted) return;
      setState(() => _appVersion = '${p.version}+${p.buildNumber}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = FirebaseAuth.instance.currentUser;

    final debugMap = {
      'appVersion': _appVersion,
      'uid': user?.uid,
      'email': user?.email,
      'displayName': user?.displayName,
      'activeFamilyId': app.familyId,         // adjust to your AppState
      'env': 'debug',                         // edit if you track envs
    };

    final pretty = _prettyJson(debugMap);

    return Scaffold(
      appBar: AppBar(title: const Text('Dev Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(pretty, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy debug info'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pretty));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _prettyJson(Map<String, dynamic> m) {
    final buf = StringBuffer();
    buf.writeln('{');
    final entries = m.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final k = entries[i].key;
      final v = entries[i].value ?? 'null';
      buf.writeln('  "$k": "$v"${i == entries.length - 1 ? '' : ','}');
    }
    buf.write('}');
    return buf.toString();
  }
}
