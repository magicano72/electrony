// Constants for API endpoints and headers
class ApiConstants {
  static const String authTokenKey = 'authToken';
  static const String accessTokenKey = 'accessToken';
  static const String refreshTokenKey = 'refreshToken';
  static const String expiryKey = 'expiry';
  static const String contentTypeJson = 'application/json';
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
  static const String filesEndpoint = '/files';
  static const String usersMeEndpoint = '/users/me';
  static const String itemsDocsEndpoint = '/items/docs';
  static const String itemsChatsEndpoint = '/items/chats';
  static const String itemsChatParticipantsEndpoint =
      '/items/chat_participants';
  static const String itemsSignatureFeeEndpoint = '/items/signature_fee';
  static const String itemsPointTransactionsEndpoint =
      '/items/point_transactions';
  static const String itemsActivityEndpoint = '/items/activity';
  static const String authOtpRequestEndpoint = '/auth/otp/request';
  static const String authOtpPasswordResetEndpoint =
      '/auth/otp/request-password-reset';
  static const String PasswordResetEndpoint = '/auth/otp/password-reset';

  static const String authOtpLoginEndpoint = '/auth/otp/login';
  static const String authOtpSignupEndpoint = '/auth/otp/signup';
  static const String authRefreshEndpoint = '/auth/refresh';
  static const String authLogoutEndpoint = '/auth/logout';
}
