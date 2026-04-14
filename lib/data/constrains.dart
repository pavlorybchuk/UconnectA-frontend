import 'package:flutter/material.dart';
import 'package:uconnecta/data/api.dart';

class KColors {
  static const Color mainColor = Color(0xFF5E81AC);
  static const Color secondaryColor = Color(0xFF88C0D0);
  static const Color thirdColor = Color(0xFFBBDEFB);
  static const Color backgroundColor = Color(0xFF506A8B);
  static const Color placeholderColor = Color(0xFFCFCFCF);
  static const Color darkPlaceholderColor = Color(0xFF565656);
  static const Color thirdColorHover = Color.fromARGB(255, 207, 233, 255);
  static const BoxShadow mainBoxShadow = BoxShadow(
    color: Color.fromARGB(25, 0, 0, 0),
    blurRadius: 4,
    offset: Offset(3, 3),
  );
  static const LinearGradient mainGradient = LinearGradient(
    transform: GradientRotation(1.5708),
    colors: [
      KColors.mainColor,
      Color.fromARGB(255, 94, 137, 172),
      Color.fromARGB(255, 136, 188, 208),
      KColors.secondaryColor,
    ],
  );
  static const Color goodColor = Color(0xFF00D207);
  static const Color mediumColor = Color(0xFFD1A700);
  static const Color badColor = Color.fromARGB(255, 255, 98, 98);
  static const Color lightBackgroundColor = Color(0xFFECEFF4);
  static const Color darkenGreyColor = Color(0xFF989898);
  static const Color policeColor = Color.fromARGB(255, 19, 0, 229);
}

class DriverProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? about;
  final String? photo;
  final double? rating;
  final bool isBlocked;
  final String? carNumber;

  DriverProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.about,
    this.photo,
    this.rating,
    required this.isBlocked,
    this.carNumber,
  });

  DriverProfile copyWith({String? carNumber}) {
    return DriverProfile(
      id: id,
      username: username,
      displayName: displayName,
      about: about,
      photo: photo,
      rating: rating,
      isBlocked: isBlocked,
      carNumber: carNumber ?? this.carNumber,
    );
  }

  String? get photoUrl {
    if (photo == null || photo!.isEmpty) return null;
    if (photo!.startsWith("http")) return photo;
    return "${Api.baseUrl}$photo";
  }

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: (json["id"] ?? "").toString(),
      username: (json["username"] ?? "").toString(),
      displayName: json["display_name"]?.toString(),
      about: json["about"]?.toString(),
      photo: json["photo"]?.toString(),
      rating: json["rating"] != null
          ? double.tryParse(json["rating"].toString())
          : null,
      isBlocked: json["isBlocked"] == true,
    );
  }
}

const List<QuickMsg> quickMessages = [
  QuickMsg(
    body: 'Your car is obstructing traffic.',
    subject: 'Bad parking',
    icon: Icons.no_transfer,
  ),
  QuickMsg(
    body: 'Your car blocked the exit.',
    subject: 'Bad parking',
    icon: Icons.block,
  ),
  QuickMsg(
    body: 'Your car was in an accident.',
    subject: 'Car accident',
    icon: Icons.car_crash,
  ),
  QuickMsg(
    body: 'I need your help, please come quickly.',
    subject: 'Emergency',
    icon: Icons.emergency,
  ),
  QuickMsg(
    body: 'Your car is damaged.',
    subject: 'Damaged car',
    icon: Icons.build,
  ),
];

class QuickMsg {
  final String body;
  final String subject; // used as email subject / category label
  final IconData icon;

  const QuickMsg({
    required this.body,
    required this.subject,
    required this.icon,
  });
}

class ChatListItem {
  final String id;
  final String type;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final DateTime? autoDeleteEnabledAt;
  final bool autoDelete;
  final DriverProfile otherUser;

  ChatListItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.lastMessageAt,
    required this.autoDelete,
    required this.otherUser,
    this.autoDeleteEnabledAt,
  });

  factory ChatListItem.fromJson(Map<String, dynamic> json) {
    final other = json["other_user"];
    if (other is! Map<String, dynamic>) {
      throw FormatException("ChatListItem.other_user is missing or invalid");
    }

    return ChatListItem(
      id: (json["id"] ?? "").toString(),
      type: (json["type"] ?? "").toString(),
      createdAt: DateTime.parse(json["created_at"].toString()),
      lastMessageAt: json["last_message_at"] == null
          ? null
          : DateTime.parse(json["last_message_at"].toString()),
      autoDelete: json["auto_delete"] == true,
      otherUser: DriverProfile.fromJson(other),
      autoDeleteEnabledAt: json["auto_delete_enabled_at"] != null
          ? DateTime.parse(json["auto_delete_enabled_at"])
          : null,
    );
  }

  ChatListItem copyWith({
    String? id,
    String? type,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    DateTime? autoDeleteEnabledAt,
    bool? autoDelete,
    DriverProfile? otherUser,
  }) {
    return ChatListItem(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      autoDelete: autoDelete ?? this.autoDelete,
      autoDeleteEnabledAt: autoDeleteEnabledAt ?? this.autoDeleteEnabledAt,
      otherUser: otherUser ?? this.otherUser,
    );
  }
}

class MessageItem {
  final int id;
  final String chat;
  final String sender;
  final String senderUsername;
  final String? body;
  final String? image;
  final DateTime createdAt;

  MessageItem({
    required this.id,
    required this.chat,
    required this.sender,
    required this.senderUsername,
    required this.body,
    required this.image,
    required this.createdAt,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json["id"] as int,
      chat: json["chat"] as String,
      sender: json["sender"] as String,
      senderUsername: (json["sender_username"] as String?) ?? "",
      body: json["body"] as String?,
      image: json["image"] as String?,
      createdAt: DateTime.parse(json["created_at"] as String),
    );
  }
}

class Country {
  final String iso2;
  final String dialCode;
  final String flag;

  const Country({
    required this.iso2,
    required this.dialCode,
    required this.flag,
  });
}

const countries = <Country>[
  Country(iso2: "UA", dialCode: "+380", flag: "🇺🇦"),
  Country(iso2: "PL", dialCode: "+48", flag: "🇵🇱"),
  Country(iso2: "DE", dialCode: "+49", flag: "🇩🇪"),
  Country(iso2: "FR", dialCode: "+33", flag: "🇫🇷"),
  Country(iso2: "IT", dialCode: "+39", flag: "🇮🇹"),
  Country(iso2: "ES", dialCode: "+34", flag: "🇪🇸"),
  Country(iso2: "GB", dialCode: "+44", flag: "🇬🇧"),
  Country(iso2: "US", dialCode: "+1", flag: "🇺🇸"),
  Country(iso2: "CA", dialCode: "+1", flag: "🇨🇦"),
  Country(iso2: "LT", dialCode: "+370", flag: "🇱🇹"),
  Country(iso2: "LV", dialCode: "+371", flag: "🇱🇻"),
  Country(iso2: "EE", dialCode: "+372", flag: "🇪🇪"),
  Country(iso2: "CZ", dialCode: "+420", flag: "🇨🇿"),
  Country(iso2: "SK", dialCode: "+421", flag: "🇸🇰"),
  Country(iso2: "HU", dialCode: "+36", flag: "🇭🇺"),
  Country(iso2: "RO", dialCode: "+40", flag: "🇷🇴"),
  Country(iso2: "MD", dialCode: "+373", flag: "🇲🇩"),
  Country(iso2: "BG", dialCode: "+359", flag: "🇧🇬"),
  Country(iso2: "TR", dialCode: "+90", flag: "🇹🇷"),
  Country(iso2: "GE", dialCode: "+995", flag: "🇬🇪"),
  Country(iso2: "AM", dialCode: "+374", flag: "🇦🇲"),
  Country(iso2: "AZ", dialCode: "+994", flag: "🇦🇿"),
  Country(iso2: "KZ", dialCode: "+7", flag: "🇰🇿"),
  Country(iso2: "IN", dialCode: "+91", flag: "🇮🇳"),
  Country(iso2: "CN", dialCode: "+86", flag: "🇨🇳"),
  Country(iso2: "JP", dialCode: "+81", flag: "🇯🇵"),
  Country(iso2: "KR", dialCode: "+82", flag: "🇰🇷"),
];

class KTextStyles {
  static final TextStyle fontVeryBigStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle fontBigStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle fontBiggerStyle = TextStyle(
    fontSize: 24,
    fontWeight: .normal,
  );

  static final TextStyle fontMediumBigStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle fontMediumStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle fontSmallStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle fontSmallestStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle fontSecondaryMedium = TextStyle(
    fontSize: 18,
    fontFamily: "Jura",
    fontWeight: .normal,
  );
}
