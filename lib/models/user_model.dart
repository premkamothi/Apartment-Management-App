class UserModel {
  String id;
  String name;
  String email;
  String phone;
  String role;
  String? flatId;

  UserModel(
      {required this.id,
      required this.name,
      required this.email,
      required this.phone,
      required this.role,
      this.flatId});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'flatId': flatId
      };

  static UserModel fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        role: json['role'],
        flatId: json['flatId'],
      );
}
