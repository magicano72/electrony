import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Electrony/screens/dashboard/transactions/activity_logic.dart';
import 'package:Electrony/models/sign_model.dart';
import 'package:Electrony/networking/api_services.dart';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'master_event.dart';
import 'master_state.dart';

class MasterBloc extends Bloc<MasterEvent, MasterState> {
  final AuthApiService apiService;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController NewPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController first_name = TextEditingController();
  final TextEditingController last_name = TextEditingController();
  final TextEditingController birthDate = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  MasterBloc({
    required this.apiService,
  }) : super(UserInitial()) {
    // Register all event handlers
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<OtpVerificationRestPasswordRequested>(
        _onOtpVerificationRestPasswordRequested);
    on<ResetPassword>(_onRestPassword);
    on<OtpVerificationRequested>(_onOtpVerificationRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<LoadUserProfile>(_onLoadUserProfile);
    on<CheckInternetConnection>(_onCheckInternetConnection);
    on<PickAndUploadProfileImage>(_onPickAndUploadProfileImage);
    on<CheckingUserCredential>(_onCheckingUserCredential);
    on<FetchSignatureData>(_onFetchSignatureData);
    on<LoadUserEmail>(_onLoadUserEmail);
    on<DeleteDocumentRequested>(_onDeleteDocumentRequested);
    on<FilterDocuments>(_onFilterDocuments);
    on<UpdateUserBalanceRequested>(_onUpdateUserBalanceRequested);
    on<LoadActivities>(_onLoadActivities);
    on<RefreshActivities>(_onRefreshActivities);
  }

  @override
  Future<void> close() async {
    _connectivitySubscription?.cancel();
    super.close();
  }

  void clearAllControllers() {
    emailController.clear();
    passwordController.clear();
    NewPasswordController.clear();
    confirmPasswordController.clear();
    phoneController.clear();
    first_name.clear();
    last_name.clear();
    birthDate.clear();
    otpController.clear();
  }

  Future<void> _onLoginRequested(
      AuthLoginRequested event, Emitter<MasterState> emit) async {
    emit(SignInLoading());
    try {
      await apiService.login(event.email, event.password);
      emit(SignInSuccess());
      clearAllControllers();

      // Load user data immediately after successful login
      add(LoadUserProfile());
      // add(LoadActivities());
    } catch (e) {
      emit(SignInFailure(errMessage: e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
      AuthRegisterRequested event, Emitter<MasterState> emit) async {
    emit(SignUpLoading());
    try {
      await apiService.register(event.password, event.first_name,
          event.last_name, event.token, event.otp);
      await apiService.addUserEmail(emailController.text, birthDate.text);
      emit(SignUpSuccess());
      clearAllControllers();
    } catch (e) {
      emit(SignUpFailure(errMessage: e.toString()));
    }
  }

  Future<void> _onRestPassword(
      ResetPassword event, Emitter<MasterState> emit) async {
    emit(ResetPasswordLoading());
    try {
      await apiService.resetPassword(event.token, event.password, event.otp);
      clearAllControllers();
      emit(ResetPasswordSuccess());
    } catch (e) {
      emit(ResetPasswordFailure(errMessage: e.toString()));
    }
  }

  Future<void> _onOtpVerificationRequested(
      OtpVerificationRequested event, Emitter<MasterState> emit) async {
    emit(OtpLoading());
    try {
      await apiService.requestRegisteredOtp(event.phone);
      emit(OtpSuccess());
    } catch (e) {
      emit(OtpFailure(errMessage: e.toString()));
    }
  }

  Future<void> _onOtpVerificationRestPasswordRequested(
      OtpVerificationRestPasswordRequested event,
      Emitter<MasterState> emit) async {
    emit(OtpLoading());
    try {
      await apiService.requestRestOtp(event.phone);
      emit(OtpSuccess());
    } catch (e) {
      emit(OtpFailure(errMessage: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
      AuthLogoutRequested event, Emitter<MasterState> emit) async {
    emit(LogoutLoading());
    try {
      await apiService.logout();
      clearAllControllers();
      emit(LogoutSuccess());
    } catch (e) {
      emit(LogoutFailure(errMessage: 'Error logging out'));
    }
  }

  Future<void> _onLoadUserProfile(
      LoadUserProfile event, Emitter<MasterState> emit) async {
    emit(UserProfileLoading());
    try {
      print('Fetching user profile...');
      final userProfile = await apiService.getUserProfile();
      print('User profile loaded: $userProfile');
      emit(UserProfileLoaded(userProfile));
    } catch (e) {
      print('Error loading user profile: $e');
      emit(UserProfileLoadFailure('Failed to load user profile: $e'));
    }
  }

  Future<void> _onLoadActivities(
      LoadActivities event, Emitter<MasterState> emit) async {
    await _loadActivities(emit);
  }

  Future<void> _onRefreshActivities(
      RefreshActivities event, Emitter<MasterState> emit) async {
    await _loadActivities(emit);
  }

  Future<void> _loadActivities(Emitter<MasterState> emit) async {
    try {
      emit(ActivitiesLoading());

      // Get current user ID
      String userId;
      if (state is UserProfileLoaded) {
        userId = (state as UserProfileLoaded).userProfile['id'];
      } else {
        final userProfile = await apiService.getUserProfile();
        userId = userProfile['id'];
      }

      // In your BLoC when making the API request
      final response = await http.get(
        Uri.parse('${dotenv.env['API_BASE_URL']}/items/activity?'
            'filter[user_id][_eq]=$userId&'
            'fields=*,signed_document.*,transactions.*,signed_document.created_file.title&'
            'sort=-created_at' // <-- This is the critical part
            ),
        headers: {
          'Authorization': 'Bearer ${await apiService.getValidToken()}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'] ?? [];
        final activities = data.map((item) => Activity.fromJson(item)).toList();

        emit(ActivitiesLoaded(activities));
      } else {
        throw Exception('Failed to load activities');
      }
    } catch (e) {
      emit(ActivitiesLoadFailure(e.toString()));
    }
  }

  Future<void> _onCheckInternetConnection(
      CheckInternetConnection event, Emitter<MasterState> emit) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    emit(InternetConnectionChecked(
        connectivityResult != ConnectivityResult.none));
  }

  Future<void> _onPickAndUploadProfileImage(
      PickAndUploadProfileImage event, Emitter<MasterState> emit) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      try {
        emit(ProfileImageUploadLoading());
        final imageFile = File(image.path);
        final imageFileId = await apiService.uploadProfileImage(imageFile);
        await apiService.updateUserProfileImage(imageFileId);

        // Refresh user profile
        final userProfile = await apiService.getUserProfile();
        emit(UserProfileLoaded(userProfile));
        emit(ProfileImageUploadSuccess());
      } catch (e) {
        emit(ProfileImageUploadFailure('Failed to upload profile image.'));
      }
    }
  }

  Future<void> _onFetchSignatureData(
      FetchSignatureData event, Emitter<MasterState> emit) async {
    emit(FetchSignatureDataLoading());
    try {
      final response = await http.get(Uri.parse(
          '${dotenv.env['API_BASE_URL']}/items/docs?fields=user_id.email,status,created_at,id,created_file.id,created_file.title,created_file.filename_download,signer.signer_id.*'));

      if (response.statusCode == 200) {
        List<SignatureData> documents = parseSignatureData(response.body);
        final token = await apiService.getValidToken() ?? '';
        final userId = JwtDecoder.decode(token)['id'];

        // Get user email
        String userEmail;
        if (state is UserEmailLoaded) {
          userEmail = (state as UserEmailLoaded).userEmail;
        } else {
          final userProfile = await apiService.getUserProfile();
          userEmail = userProfile["email"] ?? '';
        }

        // Filter documents
        documents = documents.where((doc) {
          final isCreator = doc.creatorEmail == userEmail;
          final allSignersMatch = doc.signers.every((signer) =>
              signer.contriputerEmail == userEmail && signer.userId == userId);
          return isCreator && allSignersMatch;
        }).toList();

        documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        emit(FetchSignatureDataSuccess(documents));
      } else {
        throw Exception('Failed to load signature data');
      }
    } catch (e) {
      emit(FetchSignatureDataFailure('Failed to load signature data: $e'));
    }
  }

  Future<void> _onLoadUserEmail(
      LoadUserEmail event, Emitter<MasterState> emit) async {
    emit(UserEmailLoading());
    try {
      final userProfile = await apiService.getUserProfile();
      emit(UserEmailLoaded(userProfile["email"] ?? ''));
    } catch (e) {
      emit(UserEmailLoadFailure('Failed to load user email.'));
    }
  }

  Future<void> _onDeleteDocumentRequested(
      DeleteDocumentRequested event, Emitter<MasterState> emit) async {
    emit(DeleteDocumentLoading());
    try {
      await apiService.deleteSignatureDataDocument(event.documentId);
      emit(DeleteDocumentSuccess());
      add(FetchSignatureData()); // Refresh the list
    } catch (e) {
      emit(DeleteDocumentFailure('Failed to delete document: $e'));
    }
  }

  void _onFilterDocuments(FilterDocuments event, Emitter<MasterState> emit) {
    if (state is! FetchSignatureDataSuccess) return;

    final allDocuments = (state as FetchSignatureDataSuccess).documents;
    if (event.query.isEmpty) {
      emit(FetchSignatureDataSuccess(allDocuments));
      return;
    }

    final filtered = allDocuments
        .where((doc) =>
            doc.createdFile.title
                ?.toLowerCase()
                .contains(event.query.toLowerCase()) ??
            false)
        .toList();
    emit(FilteredDocuments(filtered));
  }

  Future<void> _onUpdateUserBalanceRequested(
      UpdateUserBalanceRequested event, Emitter<MasterState> emit) async {
    if (state is UserProfileLoaded) {
      final updatedProfile =
          Map<String, dynamic>.from((state as UserProfileLoaded).userProfile);
      updatedProfile['points_balance'] = event.newBalance;
      emit(UserProfileLoaded(updatedProfile));
    }
  }

  Future<void> _onCheckingUserCredential(
      CheckingUserCredential event, Emitter<MasterState> emit) async {
    emit(SignInLoading());
    try {
      await apiService.login(event.email, event.password);
      clearAllControllers();
      emit(CheckUserCredential());
    } catch (e) {
      emit(SignInFailure(errMessage: 'Invalid email or password.'));
    }
  }
}
