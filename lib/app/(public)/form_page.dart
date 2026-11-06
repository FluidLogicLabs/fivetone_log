import 'package:flutter/material.dart';
import 'package:fivethreeone_log/app/widgets/forms/initial_form.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FormPage extends StatelessWidget {
  const FormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      // Titled, because the entry screen is reachable from home at any time and
      // not only as the first screen of a fresh install.
      appBar: AppBar(title: Text(localizations.trainingSetup)),
      body: SafeArea( // Prevent content from touching the status bar
        child: SingleChildScrollView(
          child: InitialForm(),
        ),
      ),
    );
  }
}
