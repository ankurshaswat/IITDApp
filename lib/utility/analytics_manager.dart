import 'package:firebase_analytics/firebase_analytics.dart';

FirebaseAnalytics analytics;

enum AnalyticsEvent {
  AS_GUEST,
  LOGIN_BUTTON,
  LOGOUT_BUTTON,
  STAR_EVENT,
  UNSTAR_EVENT,
  SUB_CLUB,
  UNSUB_CLUB,
  EXPORT_CALENDAR,
  QUICK_LINKS_LINK_CLICK,
  THEME_CHANGE,
  EXPORT_CALENDAR_SUCCESS,
  DASHBOARD_EVENT_CLICKED,
  DASHBOARD_NEWS_CLICKED
}

initializeAnalytics() async {
  analytics = FirebaseAnalytics.instance;
}

logScreen(screen_name) async {
  await FirebaseAnalytics.instance.setCurrentScreen(screenName: screen_name);
}

logEvent(AnalyticsEvent event, {String event_name = '', value}) async {
  if (event_name == '') {
    event_name = event.toString().split('.').last;
  }
  if (value == null) {
    await FirebaseAnalytics.instance.logEvent(
      name: event_name,
    );
  } else {
    await FirebaseAnalytics.instance
        .logEvent(name: event_name, parameters: {'value': value});
  }
}
