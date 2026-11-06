import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fivethreeone_log/app/utils/backup.dart'; // Shared export and import
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization

class ExportImportPage extends ConsumerWidget {
  const ExportImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.exportImportData),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              // Both actions live in backup.dart, so this page and the 1RM
              // entry screen write and read exactly the same file.
              ElevatedButton(
                onPressed: () => runExport(context, ref, localizations),
                child: Text(localizations.exportData),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () => runImport(context, ref, localizations),
                child: Text(localizations.importData),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
