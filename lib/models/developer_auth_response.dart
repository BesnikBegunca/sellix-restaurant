/// Developer session returned by the external licensing API.
class DeveloperAuthResponse {
  const DeveloperAuthResponse({required this.accessToken, this.developerName});

  final String accessToken;
  final String? developerName;

  factory DeveloperAuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'];
    if (token is! String || token.trim().isEmpty) {
      throw const FormatException(
        'Developer login response has no access token',
      );
    }
    return DeveloperAuthResponse(
      accessToken: token,
      developerName:
          json['developerName'] as String? ?? json['name'] as String?,
    );
  }
}
