enum UserGender {
  unspecified,
  male,
  female,
  other;

  String get label => switch (this) {
    UserGender.unspecified => '未设置',
    UserGender.male => '男',
    UserGender.female => '女',
    UserGender.other => '其他',
  };

  static UserGender fromName(String? name) {
    for (final gender in values) {
      if (gender.name == name) {
        return gender;
      }
    }
    return UserGender.unspecified;
  }
}

class UserProfile {
  const UserProfile({
    this.name = '',
    this.avatar = '',
    this.gender = UserGender.unspecified,
    this.birthday,
    this.signature = '',
  });

  static const UserProfile defaults = UserProfile();

  final String name;
  final String avatar;
  final UserGender gender;
  final DateTime? birthday;
  final String signature;

  String get displayName => name.trim().isEmpty ? '我' : name.trim();

  String get birthdayLabel {
    final value = birthday;
    if (value == null) {
      return '未设置';
    }
    return '${value.year}年${value.month}月${value.day}日';
  }

  UserProfile normalized() {
    return UserProfile(
      name: name.trim(),
      avatar: avatar.trim(),
      gender: gender,
      birthday: birthday == null
          ? null
          : DateTime(birthday!.year, birthday!.month, birthday!.day),
      signature: signature.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'gender': gender.name,
    'birthday': birthday == null
        ? null
        : '${birthday!.year.toString().padLeft(4, '0')}-'
              '${birthday!.month.toString().padLeft(2, '0')}-'
              '${birthday!.day.toString().padLeft(2, '0')}',
    'signature': signature,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final birthdayValue = json['birthday'];
    return UserProfile(
      name: json['name'] is String ? (json['name'] as String).trim() : '',
      avatar: json['avatar'] is String ? (json['avatar'] as String).trim() : '',
      gender: UserGender.fromName(
        json['gender'] is String ? json['gender'] as String : null,
      ),
      birthday: birthdayValue is String
          ? DateTime.tryParse(birthdayValue)
          : null,
      signature: json['signature'] is String
          ? (json['signature'] as String).trim()
          : '',
    );
  }
}
