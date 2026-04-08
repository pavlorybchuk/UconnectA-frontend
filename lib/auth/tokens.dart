class JwtTokens {
  final String access;
  final String refresh;

  JwtTokens({required this.access, required this.refresh});

  factory JwtTokens.fromJson(Map<String, dynamic> json) {
    return JwtTokens(
      access: json["access"] as String,
      refresh: json["refresh"] as String,
    );
  }
}