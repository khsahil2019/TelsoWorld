class UserModel {
  final int? id;
  final String username;
  final String email;
  final String? mobileNo;
  final String? schoolName;
  final String? token;

  UserModel({
    this.id,
    required this.username,
    required this.email,
    this.mobileNo,
    this.schoolName,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobileNo: json['mobile_no']?.toString(),
      schoolName: json['school_name']?.toString(),
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'mobile_no': mobileNo,
      'school_name': schoolName,
      'token': token,
    };
  }
}
