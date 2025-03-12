class AuthState {}

final class UserInitial extends AuthState {}

final class SignInLoading extends AuthState {}

final class SignInSuccess extends AuthState {}

final class SignInFailure extends AuthState {
  final String errMessage;
  SignInFailure({required this.errMessage});
}

final class SignUpLoading extends AuthState {}

final class SignUpSuccess extends AuthState {}

final class SignUpFailure extends AuthState {
  final String errMessage;
  SignUpFailure({required this.errMessage});
}

final class LogoutLoading extends AuthState {}

final class LogoutSuccess extends AuthState {}

final class LogoutFailure extends AuthState {
  final String errMessage;
  LogoutFailure({required this.errMessage});
}
