enum AdminAnnouncementType {
  information,
  reminder,
  urgent,
}

extension AdminAnnouncementTypeX on AdminAnnouncementType {
  String get label {
    switch (this) {
      case AdminAnnouncementType.information:
        return 'Informace';
      case AdminAnnouncementType.reminder:
        return 'Připomínka';
      case AdminAnnouncementType.urgent:
        return 'Naléhavé';
    }
  }

  String get value => name;
}
