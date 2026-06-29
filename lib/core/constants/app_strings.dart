/// Plain-string fallbacks used only when AppLocalizations is unavailable
/// (e.g. inside top-level error handlers before MaterialApp boots).
class AppStrings {
  AppStrings._();

  static const appName = 'Bazaar';
  static const error = 'Error';
  static const ok = 'OK';
  static const retry = 'Retry';
}
