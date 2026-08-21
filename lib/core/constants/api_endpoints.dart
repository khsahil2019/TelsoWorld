class ApiEndpoints {
  static const String baseUrl = 'https://telsoworld.com/api';
  
  // Auth
  static const String login = '/reporter/login';
  static const String register = '/reporter/register';
  static const String logout = '/reporter/logout';
  
  // Feed & Videos
  static const String dashboard = '/reporter/dashboard';
  static const String adsVideos = '/reporter/ads-all-videos';
  static const String normalVideoView = '/reporter/normal-video/view';
  static const String adsVideoView = '/reporter/adsvideo/view';
  static const String normalVideoLike = '/reporter/normal-video/like';
  static const String adsVideoLike = '/reporter/adsvideo/like';
  static const String uploadVideo = '/reporter/upload-video';
  
  // Comments
  static const String comments = '/comments';
  static const String addComment = '/comments/add';
  static const String likeComment = '/comments/like';
  
  // Wallet & Referral
  static const String wallet = '/reporter/wallet';
  static const String referral = '/reporter/referral';
}
