/// SharedPreferences key constants for one-time tutorial steps. Each key
/// gates a single tutorial dialog so it shows exactly once per install.
class TutorialFlags {
  TutorialFlags._();

  static const String roadmapIntro = 'tutorial_seen_roadmap_intro';
  static const String shopTip = 'tutorial_seen_shop';
  static const String firstCompletion = 'tutorial_seen_first_completion';
}
