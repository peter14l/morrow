import 'package:flutter/material.dart';

enum PulseStatus {
  online('Online', '🟢'),
  busy('Busy', '🔴'),
  focusing('Focusing', '🎯'),
  chilling('Chilling', '🛋️'),
  working('Working', '💼'),
  listening('Listening', '🎧'),
  traveling('Traveling', '✈️'),
  gaming('Gaming', '🎮'),
  withFriend('With Friend', '👥'),
  atLocation('At Location', '📍');

  final String label;
  final String emoji;

  const PulseStatus(this.label, this.emoji);
}
