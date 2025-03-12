abstract class AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  AuthLoginRequested(this.email, this.password);
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String first_name;
  final String last_name;
  final String phoneNumber;
  final String birthDate;
  AuthRegisterRequested(this.email, this.password, this.phoneNumber,
      this.first_name, this.last_name, this.birthDate);
}

class AuthLogoutRequested extends AuthEvent {}
