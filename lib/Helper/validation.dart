String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter an email';
  }

  // Check if any character is uppercase
  if (value != value.toLowerCase()) {
    return 'Please enter a valid email';
  }

  final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  if (!emailRegExp.hasMatch(value)) {
    return 'Please enter a valid email';
  }
  return null;
}

String? validateName(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your name';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a password';
  }
  if (value.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

String? validatePhoneNumber(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a phone number';
  }

  final phoneRegExp = RegExp(r'^(?:\+201|01|00201)[0-2,5][0-9]{8}$');

  if (!phoneRegExp.hasMatch(value)) {
    return 'Please enter a valid phone number';
  }

  return null;
}

String? validateBirthDate(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a birth of date';
  }

  return null;
}
