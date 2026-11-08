enum GroupReplyMode {
  sequential,
  randomOrder,
  singleRandom,
  mentioned;

  static GroupReplyMode fromName(String? name) {
    for (final mode in values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return GroupReplyMode.sequential;
  }
}
