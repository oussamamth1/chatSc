/// Base URL of the NestJS yt-dlp backend.
///
/// - Android emulator -> host machine: http://10.0.2.2:3000
/// - Physical device on same Wi-Fi as your dev machine: http://YOUR-LAN-IP:3000
/// - Deployed backend: https://YOUR-SERVICE.onrender.com
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://yt-dlp-backend-dx9i.onrender.com',
);
