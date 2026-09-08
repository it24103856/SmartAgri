class Helpers {
  // Add your helper methods here
  static bool isValidPhone(String phone) {
    return RegExp(r'^[0-9]{10,}$').hasMatch(phone);
  }

  static String getInitials(String name) {
    return name
        .split(' ')
        .map((word) => word[0].toUpperCase())
        .join()
        .substring(0, 2);
  }
}
