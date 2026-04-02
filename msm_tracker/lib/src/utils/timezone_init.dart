import 'package:timezone/data/latest.dart' as tzdata;

bool _timeZonesInitialized = false;

/// Loads the IANA database once (required for [ServerRegion.europe]).
void ensureTimezonesInitialized() {
  if (_timeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _timeZonesInitialized = true;
}
