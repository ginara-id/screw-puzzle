import 'package:flutter/material.dart';

enum Character { silas, robot }

class StoryBeat {
  final int level;
  final Character character;
  final String text;
  final String? portraitPath;

  StoryBeat({
    required this.level,
    required this.character,
    required this.text,
    this.portraitPath,
  });
}

class StoryManager {
  static final List<StoryBeat> beats = [
    StoryBeat(
      level: 1,
      character: Character.silas,
      text: "Another day, another pile of scrap... Wait, what's this? A clockwork heart? It's been centuries since I saw one of these.",
      portraitPath: 'assets/images/silas_portrait.png',
    ),
    StoryBeat(
      level: 5,
      character: Character.silas,
      text: "The gears are starting to turn, but the rust is thick. I need to be careful with the support plates or the whole leg will collapse.",
      portraitPath: 'assets/images/silas_portrait.png',
    ),
    StoryBeat(
      level: 10,
      character: Character.robot,
      text: "...SYSTEM... REBOOT... DETECTED... INITIALIZING... OPTICAL... SENSORS...",
      portraitPath: 'assets/images/robot_portrait.png',
    ),
    StoryBeat(
      level: 10,
      character: Character.silas,
      text: "It lives! Steady now, old friend. You've been asleep for a very long time.",
      portraitPath: 'assets/images/silas_portrait.png',
    ),
  ];

  static List<StoryBeat> getBeatsForLevel(int level) {
    return beats.where((b) => b.level == level).toList();
  }
}
