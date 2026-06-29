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

String? validateEmailOrPhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter an email or phone number';
  }

  // Check if it's a valid email
  final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  if (emailRegExp.hasMatch(value)) {
    return null; // Valid email
  }

  // Check if it's a valid Egyptian phone number with or without +20
  final phoneRegExp = RegExp(r'^(?:\+20|0)?1[0-9]{9}$');
  if (phoneRegExp.hasMatch(value)) {
    return null; // Valid phone
  }

  return 'Please enter a valid email or phone number';
}

String normalizePhoneOrEmail(String input) {
  final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  if (emailRegExp.hasMatch(input)) {
    return input; // Already email, return as is
  }

  // Normalize phone number to +20 format
  if (input.startsWith('0')) {
    return '+2${input}';
  } else if (!input.startsWith('+2')) {
    return '+2$input';
  }
  return input;
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
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

String? validatePhoneNumber(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your phone number';
  }

  // Add +2 prefix if not present
  String phoneNumber = value;
  if (!phoneNumber.startsWith('+2')) {
    phoneNumber = '+2$phoneNumber';
  }

  // Remove +2 prefix temporarily for validation
  String numberWithoutPrefix = phoneNumber.substring(2);

  if (numberWithoutPrefix.length != 11) {
    return 'Phone number must be 11 digits';
  }
  if (!numberWithoutPrefix.startsWith('01')) {
    return 'Phone number must start with 01';
  }

  return null;
}

String? validateBirthDate(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a birth of date';
  }

  return null;
}
