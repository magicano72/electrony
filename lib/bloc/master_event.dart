abstract class MasterEvent {}

class AuthLoginRequested extends MasterEvent {
  final String email;
  final String password;

  AuthLoginRequested(this.email, this.password);
}

class CheckingUserCredential extends MasterEvent {
  final String email;
  final String password;

  CheckingUserCredential(this.email, this.password);
}

class AuthRegisterRequested extends MasterEvent {
  final String password;
  final String first_name;
  final String last_name;

  final String token;
  final String otp;
  AuthRegisterRequested(
      this.password, this.first_name, this.last_name, this.token, this.otp);
}

class OtpVerificationRequested extends MasterEvent {
  final String phone;
  final String email;
  OtpVerificationRequested(this.phone, this.email);
}

class OtpVerificationRestPasswordRequested extends MasterEvent {
  final String phone;

  OtpVerificationRestPasswordRequested(this.phone);
}

class ResetPassword extends MasterEvent {
  final String token;
  final String password;
  final String otp;
  ResetPassword(this.token, this.password, this.otp);
}

class AuthLogoutRequested extends MasterEvent {}

class LoadUserProfile extends MasterEvent {}

class CheckInternetConnection extends MasterEvent {}

class PickAndUploadProfileImage extends MasterEvent {}

class FetchSignatureData extends MasterEvent {}

class LoadUserEmail extends MasterEvent {}

class DeleteDocumentRequested extends MasterEvent {
  final String documentId;

  DeleteDocumentRequested(this.documentId);
}

class FilterDocuments extends MasterEvent {
  final String query;

  FilterDocuments(this.query);
}
// Add this event to your master_event.dart file

class UpdateUserBalanceRequested extends MasterEvent {
  final double newBalance;

  UpdateUserBalanceRequested({required this.newBalance});
}

// Add these to your MasterEvent class
class LoadActivities extends MasterEvent {}

class RefreshActivities extends MasterEvent {}
