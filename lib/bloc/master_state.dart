import 'package:Electrony/models/sign_model.dart';

class MasterState {}

final class UserInitial extends MasterState {}

final class SignInLoading extends MasterState {}

final class SignInSuccess extends MasterState {}

final class CheckUserCredential extends MasterState {}

final class SignInFailure extends MasterState {
  final String errMessage;
  SignInFailure({required this.errMessage});
}

final class SignUpLoading extends MasterState {}

final class SignUpSuccess extends MasterState {}

final class SignUpFailure extends MasterState {
  final String errMessage;
  SignUpFailure({required this.errMessage});
}

final class OtpLoading extends MasterState {}

final class OtpSuccess extends MasterState {}

final class OtpFailure extends MasterState {
  final String errMessage;
  OtpFailure({required this.errMessage});
}

final class ResetPasswordLoading extends MasterState {}

final class ResetPasswordSuccess extends MasterState {}

final class ResetPasswordFailure extends MasterState {
  final String errMessage;
  ResetPasswordFailure({required this.errMessage});
}

final class LogoutLoading extends MasterState {}

final class LogoutSuccess extends MasterState {}

final class LogoutFailure extends MasterState {
  final String errMessage;
  LogoutFailure({required this.errMessage});
}

final class UserProfileLoading extends MasterState {}

final class UserProfileLoaded extends MasterState {
  final Map<String, dynamic> userProfile;
  UserProfileLoaded(this.userProfile);
}

final class UserProfileLoadFailure extends MasterState {
  final String errorMessage;
  UserProfileLoadFailure(this.errorMessage);
}

final class InternetConnectionChecked extends MasterState {
  final bool isConnected;
  InternetConnectionChecked(this.isConnected);
}

final class ProfileImageUploadLoading extends MasterState {}

final class ProfileImageUploadSuccess extends MasterState {}

final class ProfileImageUploadFailure extends MasterState {
  final String errorMessage;
  ProfileImageUploadFailure(this.errorMessage);
}

final class FetchSignatureDataLoading extends MasterState {}

final class FetchSignatureDataSuccess extends MasterState {
  final List<SignatureData> documents;
  FetchSignatureDataSuccess(this.documents);
}

final class FetchSignatureDataFailure extends MasterState {
  final String errorMessage;
  FetchSignatureDataFailure(this.errorMessage);
}

final class UserEmailLoading extends MasterState {}

final class UserEmailLoaded extends MasterState {
  final String userEmail;
  UserEmailLoaded(this.userEmail);
}

final class UserEmailLoadFailure extends MasterState {
  final String errorMessage;
  UserEmailLoadFailure(this.errorMessage);
}

final class DeleteDocumentLoading extends MasterState {}

final class DeleteDocumentSuccess extends MasterState {}

final class DeleteDocumentFailure extends MasterState {
  final String errorMessage;
  DeleteDocumentFailure(this.errorMessage);
}

final class FilteredDocuments extends MasterState {
  final List<SignatureData> filteredDocuments;

  FilteredDocuments(this.filteredDocuments);
}

// Add these to your MasterState class
class ActivitiesLoading extends MasterState {}

class ActivitiesLoaded extends MasterState {
  final List<dynamic> activities;

  ActivitiesLoaded(this.activities);
}

class ActivitiesLoadFailure extends MasterState {
  final String error;

  ActivitiesLoadFailure(this.error);
}
