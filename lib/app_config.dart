class AppConfig {
  static const String startUrl = String.fromEnvironment(
    'START_URL',
    defaultValue: 'https://soleco-optimizer-beta.azurewebsites.net/',
  );

  static const List<String> allowedHosts = [
    // Deine Website
    'soleco-optimizer-beta.azurewebsites.net',

    // Azure AD B2C Login (dein Redirect)
    'crystalball.b2clogin.com',
  ];
}
