class AppConfig {
  // URL lässt sich später via Codemagic überschreiben:
  // --dart-define=START_URL=https://release-domain.com/
  static const String startUrl = String.fromEnvironment(
    'START_URL',
    defaultValue: "https://soleco-optimizer-beta.azurewebsites.net/",
  );

  // Domain-Lock: nur diese Hosts werden innerhalb der App geladen
  static const allowedHosts = <String>{
    "soleco-optimizer-beta.azurewebsites.net",
    // später z.B. "soleco-optimizer.com"
  };
}
