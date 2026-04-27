class CurrentUser {
  final String id;
  final String email;
  final String phone;
  final String username;
  final String? howToAddress;
  final Map<String, dynamic> profile;
  final List<String> cars;
  final double? rating;
  final bool hasPassword;

  CurrentUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.username,
    required this.profile,
    required this.cars,
    this.howToAddress,
    this.rating,
    required this.hasPassword,
  });

  CurrentUser copyWith({
    String? id,
    String? email,
    String? phone,
    String? username,
    String? howToAddress,
    Map<String, dynamic>? profile,
    List<String>? cars,
    double? rating,
    bool? hasPassword,
  }) {
    return CurrentUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      howToAddress: howToAddress ?? this.howToAddress,
      profile: profile ?? this.profile,
      cars: cars ?? this.cars,
      rating: rating ?? this.rating,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: (json["id"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
      username: (json["username"] ?? "").toString(),
      howToAddress: json["how_to_address"]?.toString(),

      profile: json["profile"] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json["profile"])
          : {},

      cars: json["cars"] is List
          ? List<String>.from(json["cars"].map((e) => e.toString()))
          : [],

      rating: json["rating"] != null
          ? double.tryParse(json["rating"].toString())
          : null,
      hasPassword: (json["has_password"] ?? false) as bool,
    );
  }
}