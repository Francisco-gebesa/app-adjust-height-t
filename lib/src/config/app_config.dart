class AppConfig {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static String get apiBaseUrl {
    return 'https://api.gebesa-app.com/';
  }
  static String get apiWhisper {
    return '';
  }
}
