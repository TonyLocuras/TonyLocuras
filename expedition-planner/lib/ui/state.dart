import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/open_meteo_client.dart';
import '../domain/geo.dart';
import '../domain/time_model.dart';

class RouteNotifier extends Notifier<List<LatLngEle>> {
  @override
  List<LatLngEle> build() => const [];
  void set(List<LatLngEle> r) => state = r;
}

class ActivityNotifier extends Notifier<Activity> {
  @override
  Activity build() => Activity.hiking;
  void set(Activity a) => state = a;
}

class StepNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void go(int s) => state = s;
}

class NightNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final routeProvider =
    NotifierProvider<RouteNotifier, List<LatLngEle>>(RouteNotifier.new);
final activityProvider =
    NotifierProvider<ActivityNotifier, Activity>(ActivityNotifier.new);
final stepProvider = NotifierProvider<StepNotifier, int>(StepNotifier.new);
final nightProvider = NotifierProvider<NightNotifier, bool>(NightNotifier.new);

final forecastClientProvider = Provider<OpenMeteoClient>((_) => OpenMeteoClient());

/// Forecast for the route start. Re-fetched when the route changes.
final forecastProvider = FutureProvider<List<HourlyForecast>>((ref) async {
  final r = ref.watch(routeProvider);
  if (r.isEmpty) return const [];
  return ref.watch(forecastClientProvider).fetch(r.first.lat, r.first.lon);
});
