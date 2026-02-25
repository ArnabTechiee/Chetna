class VoiceSettings {
  final bool isEnabled;
  final bool isListening;
  final String emergencyKeyword;
  final String trustedVoicePath;
  final String caregiverName;
  final int escalationDelay; // seconds

  const VoiceSettings({
    required this.isEnabled,
    required this.isListening,
    required this.emergencyKeyword,
    required this.trustedVoicePath,
    required this.caregiverName,
    required this.escalationDelay,
  });

  factory VoiceSettings.defaultSettings() => VoiceSettings(
    isEnabled: true,
    isListening: false,
    emergencyKeyword: "Help",
    trustedVoicePath: "assets/audio/trusted_voice_message.mp3",
    caregiverName: "Family",
    escalationDelay: 10,
  );
}
