import '../../core/config/app_config.dart';

String absoluteApiUrl(String? path) {
  if (path == null || path.isEmpty) {
    return '';
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final normalized = path.startsWith('/') ? path : '/$path';
  return '$base$normalized';
}
