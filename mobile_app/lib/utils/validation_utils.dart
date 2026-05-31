class ValidationUtils {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value, {bool isRequired = true}) {
    if (value == null || value.isEmpty) {
      return isRequired ? 'Password is required' : null;
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    
    return null;
  }

  // Strong password validation
  static String? validateStrongPassword(String? value, {String? currentPassword}) {
    final basicValidation = validatePassword(value);
    if (basicValidation != null) return basicValidation;
    
    if (currentPassword != null && value == currentPassword) {
      return 'New password must be different from current password';
    }
    
    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value!)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    // Check for at least one digit
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    // Check for minimum length of 8 for strong passwords
    if (value.length < 8) {
      return 'Strong password should be at least 8 characters long';
    }
    
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  // Name validation
  static String? validateName(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Name is required' : null;
    }
    
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    
    return null;
  }

  // Student ID validation
  static String? validateStudentId(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Student ID is required' : null;
    }
    
    // Basic format validation (adjust based on your institution's format)
    if (!RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(value.trim())) {
      return 'Student ID must be 6-12 characters (letters and numbers only)';
    }
    
    return null;
  }

  // Department validation
  static String? validateDepartment(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Department is required' : null;
    }
    
    if (value.trim().length < 2) {
      return 'Department name must be at least 2 characters long';
    }
    
    if (value.trim().length > 100) {
      return 'Department name must be less than 100 characters';
    }
    
    return null;
  }

  // Phone number validation
  static String? validatePhoneNumber(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }
    
    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Phone number must be between 10-15 digits';
    }
    
    return null;
  }

  // Generic text validation
  static String? validateText(String? value, {
    bool isRequired = false,
    int? minLength,
    int? maxLength,
    String? fieldName,
  }) {
    final field = fieldName ?? 'Field';
    
    if (value == null || value.trim().isEmpty) {
      return isRequired ? '$field is required' : null;
    }
    
    if (minLength != null && value.trim().length < minLength) {
      return '$field must be at least $minLength characters long';
    }
    
    if (maxLength != null && value.trim().length > maxLength) {
      return '$field must be less than $maxLength characters';
    }
    
    return null;
  }

  // Password strength checker
  static PasswordStrength getPasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    
    int score = 0;
    
    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    
    // Character variety checks
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    
    // Return strength based on score
    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  // Get password strength color
  static String getPasswordStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }
}

enum PasswordStrength {
  empty,
  weak,
  medium,
  strong,
}
