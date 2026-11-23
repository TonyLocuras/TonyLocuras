import 'geo.dart';

enum Activity { hiking, trail, alpine, caving }

const _factor = {
  Activity.hiking: 1.0,
  Activity.trail: 0.6,
  Activity.alpine: 1.4,
  Activity.caving: 1.8,
};

Duration estimateTime(RouteStats s,
    {double packKg = 8, Activity activity = Activity.hiking}) {
  final hours = s.km / 5 + s.gainM / 600 + s.lossM / 1200;
  final packMult = 1 + (packKg > 10 ? (packKg - 10) * 0.03 : 0);
  final minutes = hours * 60 * _factor[activity]! * packMult;
  return Duration(minutes: minutes.round());
}
