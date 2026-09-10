class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profileImageUrl;
  final String? address, city, province;
  final String role;
  final String status;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profileImageUrl,
    this.address,
    this.city,
    this.province,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      role: (json['role'] as String).toUpperCase(),
      status: (json['status'] as String).toUpperCase(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isFarmer => role == 'FARMER';
  bool get isCustomer => role == 'CUSTOMER';
  bool get isAdmin => role == 'ADMIN';
  bool get isActive => status == 'ACTIVE';
}
