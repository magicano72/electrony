import 'dart:async';

import 'package:Electrony/Networking/api_services.dart';
// ignore: depend_on_referenced_packages
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthApiService apiService;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController first_name = TextEditingController();
  final TextEditingController last_name = TextEditingController();
  final TextEditingController birthDate = TextEditingController();
  AuthBloc({
    required this.apiService,
  }) : super(UserInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  // Login event
  Future<void> _onLoginRequested(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(SignInLoading());

    try {
      await apiService.login(event.email, event.password);
      emit(SignInSuccess());
    } catch (e) {
      String errorMessage = 'Invalid email or password.';
      emit(SignInFailure(errMessage: errorMessage));
    }
  }

  Future<void> _onRegisterRequested(
      AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(SignUpLoading());
    try {
      await apiService.register(event.email, event.password, event.first_name,
          event.last_name, event.phoneNumber, event.birthDate);
      emit(SignUpSuccess());
    } catch (e) {
      String errorRegisterMessage = 'This email is already registered';
      emit(SignUpFailure(errMessage: errorRegisterMessage));
    }
  }

  Future<void> _onLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(LogoutLoading());
    try {
      await apiService.logout(); // Use actual user token here
      emit(LogoutSuccess());
    } catch (e) {
      String errorLofoutMessage = 'Error logging out';
      emit(LogoutFailure(errMessage: errorLofoutMessage));
    }
  }
}
