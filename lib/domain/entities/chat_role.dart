enum ChatRole {
  system,
  user,
  assistant;

  static ChatRole fromName(String value) {
    return ChatRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => ChatRole.user,
    );
  }
}
