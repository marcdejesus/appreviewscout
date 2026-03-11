import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Curated list of project icon keys and their HugeIcons for the icon picker.
/// Stored in DB as the key (e.g. strokeRoundedFolder01).
const List<MapEntry<String, String>> projectIconPickerOptions = [
  MapEntry('strokeRoundedFolder01', 'Folder'),
  MapEntry('strokeRoundedHome01', 'Home'),
  MapEntry('strokeRoundedBriefcase01', 'Briefcase'),
  MapEntry('strokeRoundedMessage01', 'Message'),
  MapEntry('strokeRoundedBook01', 'Book'),
  MapEntry('strokeRoundedActivity01', 'Activity'),
  MapEntry('strokeRoundedHeartAdd', 'Heart'),
  MapEntry('strokeRoundedMapPinpoint01', 'Map'),
  MapEntry('strokeRoundedMusicNote01', 'Music'),
  MapEntry('strokeRoundedSettings01', 'Settings'),
  MapEntry('strokeRoundedImage01', 'Image'),
  MapEntry('strokeRoundedFile01', 'File'),
  // Motivational / goals / inspiration
  MapEntry('strokeRoundedFire', 'Fire'),
  MapEntry('strokeRoundedRocket01', 'Rocket'),
  MapEntry('strokeRoundedStar', 'Star'),
  MapEntry('strokeRoundedBulb', 'Light bulb'),
  MapEntry('strokeRoundedIdea', 'Idea'),
  MapEntry('strokeRoundedMedal01', 'Medal'),
  MapEntry('strokeRoundedAward01', 'Award'),
  MapEntry('strokeRoundedFlag01', 'Flag'),
  MapEntry('strokeRoundedTarget01', 'Target'),
  MapEntry('strokeRoundedSun01', 'Sun'),
  MapEntry('strokeRoundedChart01', 'Chart'),
];

const String _defaultIconKey = 'strokeRoundedFolder01';

dynamic _iconDataFor(String key) {
  switch (key) {
    case 'strokeRoundedFolder01':
      return HugeIcons.strokeRoundedFolder01;
    case 'strokeRoundedHome01':
      return HugeIcons.strokeRoundedHome01;
    case 'strokeRoundedBriefcase01':
      return HugeIcons.strokeRoundedBriefcase01;
    case 'strokeRoundedMessage01':
      return HugeIcons.strokeRoundedMessage01;
    case 'strokeRoundedBook01':
      return HugeIcons.strokeRoundedBook01;
    case 'strokeRoundedActivity01':
      return HugeIcons.strokeRoundedActivity01;
    case 'strokeRoundedHeartAdd':
      return HugeIcons.strokeRoundedHeartAdd;
    case 'strokeRoundedMapPinpoint01':
      return HugeIcons.strokeRoundedMapPinpoint01;
    case 'strokeRoundedMusicNote01':
      return HugeIcons.strokeRoundedMusicNote01;
    case 'strokeRoundedSettings01':
      return HugeIcons.strokeRoundedSettings01;
    case 'strokeRoundedImage01':
      return HugeIcons.strokeRoundedImage01;
    case 'strokeRoundedFile01':
      return HugeIcons.strokeRoundedFile01;
    case 'strokeRoundedFire':
      return HugeIcons.strokeRoundedFire;
    case 'strokeRoundedRocket01':
      return HugeIcons.strokeRoundedRocket01;
    case 'strokeRoundedStar':
      return HugeIcons.strokeRoundedStar;
    case 'strokeRoundedBulb':
      return HugeIcons.strokeRoundedBulb;
    case 'strokeRoundedIdea':
      return HugeIcons.strokeRoundedIdea;
    case 'strokeRoundedMedal01':
      return HugeIcons.strokeRoundedMedal01;
    case 'strokeRoundedAward01':
      return HugeIcons.strokeRoundedAward01;
    case 'strokeRoundedFlag01':
      return HugeIcons.strokeRoundedFlag01;
    case 'strokeRoundedTarget01':
      return HugeIcons.strokeRoundedTarget01;
    case 'strokeRoundedSun01':
      return HugeIcons.strokeRoundedSun01;
    case 'strokeRoundedChart01':
      return HugeIcons.strokeRoundedChart01;
    default:
      return HugeIcons.strokeRoundedFolder01;
  }
}

/// Returns a HugeIcon widget for the given project icon key, or default folder icon.
Widget projectIconWidget({
  required String? iconKey,
  double size = 24,
  Color? color,
}) {
  final data = _iconDataFor(iconKey ?? _defaultIconKey);
  return HugeIcon(
    icon: data,
    size: size,
    color: color,
  );
}
