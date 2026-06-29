class ProfilModel {
  final String profileImageUrl; // Store the URL for the profile image
  final String userEmail;
  final String firstName;
  final String lastName;
  final String phoneNumber;

  ProfilModel({
    required this.profileImageUrl,
    required this.userEmail,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
  });

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    return ProfilModel(
      profileImageUrl: json['avatar'],
      userEmail: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phoneNumber: json['phone_number'],
    );
  }
}
