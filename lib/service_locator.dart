import 'package:get_it/get_it.dart';
import 'package:iitd_app/events/data/events_api.dart';

final _getIt = GetIt.instance;
GetIt get getIt => _getIt;

Future<void> setupServiceLocator() async {
  _getIt.registerSingleton(EventsAPI());
}
