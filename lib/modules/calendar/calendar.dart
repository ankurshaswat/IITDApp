// ignore_for_file: await_only_futures

library event_calendar;

import 'dart:convert';
import 'dart:math';
import 'package:IITDAPP/modules/calendar/data/CalendarModel.dart';
import 'package:IITDAPP/modules/settings/data/SettingsHandler.dart';
import 'package:IITDAPP/ThemeModel.dart';
import 'package:IITDAPP/utility/UrlHandler.dart';
import 'package:IITDAPP/widgets/choice_alert.dart';
import 'package:IITDAPP/widgets/error_alert.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:IITDAPP/widgets/CustomAppBar.dart';
import 'package:IITDAPP/widgets/CustomSnackbar.dart';
import 'package:IITDAPP/widgets/Drawer.dart';
import 'package:IITDAPP/widgets/loading.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:IITDAPP/modules/calendar/data/Constants.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:localstorage/localstorage.dart';
//import 'package:google_fonts/google_fonts.dart';
//import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'package:IITDAPP/values/Constants.dart';

part './screens/AppointmentEditor.dart';
part './data/MeetingClass.dart';
part './widgets/color-picker.dart';
part './utility/CalendarHandler.dart';
part './utility/CommunFunctions.dart';
part './widgets/CustomSwiper.dart';
part './widgets/CustomModal.dart';
part './serverConnection/RequestsHandler.dart';
part './serverConnection/QueueManager.dart';

List<Color> _colorCollection;
List<String> _colorNames;
int _selectedColorIndex = 0;
int _selectedColor = -65535;
// ignore: unused_element
int _selectedTimeZoneIndex = 0;
List<String> _timeZoneCollection;
DataSource _events;
Meeting _selectedAppointment;
DateTime _startDate;
TimeOfDay _startTime;
DateTime _endDate;
TimeOfDay _endTime;
bool _isAllDay;
String _subject = '';
String _notes = '';
String _reminder = '';
String _recurrence = 'Does Not Repeat';
String _location = '';
String _attendee = '';
List<String> eventNameCollection;
// ignore: non_constant_identifier_names
String IITDCalendarId = '';
String starredCalendarId = '';
String userEventsCalendarId = '';
var calForceSetsState;

class CalendarScreen extends StatefulWidget {
  static const String routeName = '/calendar';

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DeviceCalendarPlugin _deviceCalendarPlugin;
  List<CalendarModel> calendarModel = [];
  List<Calendar> _calendars;
  List<Calendar> get _writableCalendars =>
      _calendars?.where((c) => !c.isReadOnly)?.toList() ?? <Calendar>[];

//  List<Calendar> get _readOnlyCalendars =>
//      _calendars?.where((c) => c.isReadOnly)?.toList() ?? <Calendar>[];

  _CalendarScreenState() {
    _deviceCalendarPlugin = DeviceCalendarPlugin();
  }

  var viewType;
  List<Meeting> appointments;
  bool showAgenda;
  var lastSelectedDate;
  var exempted;
  var _tasks;
  bool showPopUp;
  var excludeOtherCalendars;
  List<Appointment> agendaAppointments;
  var events2;
  var appBarText = 'Calendar (Loading)';

  CalendarController _calendarController;

  void loadLicences() async {}

  // ignore: always_declare_return_types
  changeViewType(var view) {
    setState(() {
      if (view == 0) {
        viewType = CalendarView.month;
        showAgenda = true;
      } else {
        viewType = view;
        showAgenda = false;
      }
      print('odasjl');
    });
  }

  void changeExempted(var res) {
    setState(() {
      exempted = res;
      _events = filterEvents(calendarModel, res);
    });
  }

  // ignore: always_declare_return_types
  forceSetState() {
    setState(() {
      events2 = _events;
    });
  }

  @override
  void initState() {
    excludeOtherCalendars = false;
    agendaAppointments = <Appointment>[];
    showPopUp = false;
    exempted = {};
    getAppSettings();
//    showAgenda = true;
//    viewType = CalendarView.month;
    appointments = null; //getMeetingDetails();
    _calendarController = CalendarController();
    _calendarController.selectedDate = DateTime.now();
    lastSelectedDate = _calendarController.displayDate;
    _events = DataSource(appointments);
    events2 = _events;
    _selectedAppointment = null;
    _selectedColorIndex = 0;
    _selectedColor = -65535;
    _selectedTimeZoneIndex = 0;
    _subject = '';
    _notes = '';
    _tasks = _retrieveCalendars();
    calForceSetsState = forceSetState;
    super.initState();
  }

  // ignore: always_declare_return_types
  getAppSettings() async {
    excludeOtherCalendars =
        !(await SettingsHandler.getSettingValue('showOtherCalendars'));
    var res = await SettingsHandler.getSettingValue('defaultCalendarView');
    changeViewType(viewOptions[res]);
  }

  Future _retrieveCalendars() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data) {
          return;
        }
      }

      print('Calendars will be retrieved now');
      unawaited(showLoading(context, message: 'Syncing Changes'));
      await QueueManager.executeList(await QueueManager.getList());
      // print('List Execution Complete');
      Navigator.pop(context);
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      setState(() {
        _calendars = calendarsResult?.data;
        print('recieved data');
        print(calendarsResult?.data);
        for (var idx in _writableCalendars.asMap().keys) {
          var data = _writableCalendars.asMap()[idx];

          if (excludeOtherCalendars && idx != _writableCalendars.length - 1) {
            if (!(data.name == 'User Events' ||
                data.name == 'IITD Connect' ||
                data.name == 'Academic Calendar')) {
              continue;
            }
          }
          print('CALENDAR_LOG_KEY Loading Calendar: ${data.name}');
          Future _retrieveCalendarEvents(bool last) async {
            final startDate = DateTime.now().add(Duration(days: -90));
            final endDate = DateTime.now().add(Duration(days: 180));
            print('CALENDAR_LOG_KEY Retrieving Events for ${data.name}');
            var calendarEventsResult =
                await _deviceCalendarPlugin.retrieveEvents(
                    data.id,
                    RetrieveEventsParams(
                        startDate: startDate, endDate: endDate));
            print('CALENDAR_LOG_KEY Retrieved Events for ${data.name}');
            calendarModel.add(CalendarModel(
                id: data.id,
                name: data.name,
                accountName: data.accountName,
                color: data.color,
                events: calendarEventsResult));
            if (data.name == 'User Events') {
              await getAllEvents(calendarEventsResult, 1, startDate, endDate);
            }
            if (data.name == 'IITD Connect') {
              await getAllEvents(calendarEventsResult, 0, startDate, endDate);
            }
            if (last) {
              appBarText = 'Calendar';
              checkForCalIds(calendarModel);
            }
            print('last also executed');
            print('Events shud be displayed now');
            _events = filterEvents(calendarModel, exempted);
            events2 = _events;
            forceSetState();
            // }
            // forceSetState();
          }

          _retrieveCalendarEvents(idx == _writableCalendars.length - 1);
        }
        print('hello');
      });
    } on PlatformException catch (e) {
      print(e);
    }
    print('exiting retrieve calendars');
  }

  @override
  Widget build(BuildContext context) {
    void onCalendarTapped(CalendarTapDetails calendarTapDetails) {
      if (showPopUp) {
        setState(() {
          showPopUp = false;
        });
        return;
      }
//
//      if (calendarTapDetails.targetElement == CalendarElement.calendarCell) {
//        setState(() {
//          agendaAppointments = calendarTapDetails.appointments;
//        });
//      }

      if (calendarTapDetails.targetElement != CalendarElement.calendarCell &&
          calendarTapDetails.targetElement != CalendarElement.appointment) {
        return;
      }

      if (viewType == CalendarView.month &&
          (calendarTapDetails.appointments.isEmpty || showAgenda)) {
        if (_calendarController.selectedDate != lastSelectedDate) {
          lastSelectedDate = _calendarController.selectedDate;
          return;
        }
      }

      if (viewType == CalendarView.month &&
          !showAgenda &&
          calendarTapDetails.appointments.isNotEmpty) {
        setState(() {
          showPopUp = true;
          lastSelectedDate = _calendarController.selectedDate;
        });
        return;
      }

      setState(() {
        lastSelectedDate = _calendarController.selectedDate;
        _selectedAppointment = null;
        _isAllDay = false;
        _selectedColor = -65535;
        _selectedColorIndex = 0;
        _selectedTimeZoneIndex = 0;
        _subject = '';
        _notes = '';
        if (viewType == CalendarView.month) {
          viewType = CalendarView.day;
        } else {
          if (calendarTapDetails.appointments != null &&
              calendarTapDetails.appointments.length == 1) {
            final Meeting meetingDetails = calendarTapDetails.appointments[0];
            _startDate = meetingDetails.from;
            _endDate = meetingDetails.to;
            _isAllDay = meetingDetails.isAllDay;
            _selectedColor = meetingDetails.background.value;
            // _selectedColorIndex = _colorCollection.indexOf(meetingDetails.background);
            _selectedTimeZoneIndex = meetingDetails.startTimeZone == ''
                ? 0
                : _timeZoneCollection.indexOf(meetingDetails.startTimeZone);
            _subject = meetingDetails.eventName == '(No title)'
                ? ''
                : meetingDetails.eventName;
            _notes = meetingDetails.description;
            _location = meetingDetails.location;
            _reminder = getReminderString(meetingDetails.reminder);
            _attendee = getAttendeeString(meetingDetails.attendee);
            _recurrence = getRecurrenceString(meetingDetails.recurrence);
            _selectedAppointment = meetingDetails;
          } else {
            // ignore: omit_local_variable_types
            final DateTime date = calendarTapDetails.date;
            _startDate = date;
            _endDate = date.add(const Duration(hours: 1));
          }
          _startTime =
              TimeOfDay(hour: _startDate.hour, minute: _startDate.minute);
          _endTime = TimeOfDay(hour: _endDate.hour, minute: _endDate.minute);
          Navigator.push<Widget>(
            context,
            MaterialPageRoute(
                builder: (BuildContext context) => AppointmentEditor()),
          );
        }
      });
    }

    void openEditorDirectly() {
//      getEventsInRange(_events, _calendarController.selectedDate, 3);
      // ignore: omit_local_variable_types
      final DateTime date =
          _calendarController.selectedDate ?? _calendarController.displayDate;
      _startDate = date;
      _endDate = date.add(const Duration(hours: 1));
      _startTime = TimeOfDay(hour: _startDate.hour, minute: _startDate.minute);
      _endTime = TimeOfDay(hour: _endDate.hour, minute: _endDate.minute);
      _selectedAppointment = null;
      _isAllDay = false;
      _selectedColor = -65535;
      _selectedColorIndex = 0;
      _selectedTimeZoneIndex = 0;
      _subject = '';
      _notes = '';
      Navigator.push<Widget>(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => AppointmentEditor()),
      );
    }

    SfCalendar CustomCalendar() {
      return SfCalendar(
        initialSelectedDate: _calendarController.displayDate,
        controller: _calendarController,
        headerHeight: 60,
        headerStyle: CalendarHeaderStyle(
            textAlign: TextAlign.center,
            textStyle: TextStyle(
                fontSize: 32,
                color: Colors.red,
                fontWeight: FontWeight.w500,
                letterSpacing: 1)),
        view: viewType,
        onViewChanged: (ViewChangedDetails details) {
          lastSelectedDate = _calendarController.selectedDate;
        },
        onTap: onCalendarTapped,
        firstDayOfWeek: 1,
        dataSource: events2, //DataSource(getMeetingDetails()),
        monthViewSettings: MonthViewSettings(
          showAgenda: showAgenda,
          appointmentDisplayMode: showAgenda
              ? MonthAppointmentDisplayMode.indicator
              : MonthAppointmentDisplayMode.appointment,
          dayFormat: 'EEE',
          monthCellStyle: MonthCellStyle(
            textStyle: TextStyle(
                fontSize: 17,
                color:
                    Provider.of<ThemeModel>(context).theme.PRIMARY_TEXT_COLOR),
            // ignore: deprecated_member_use
            todayTextStyle: TextStyle(fontSize: 17),
          ),
        ),
        selectionDecoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.blue, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          shape: BoxShape.rectangle,
        ),
        todayHighlightColor: Colors.blue,
      );
    }

    return
        //  WillPopScope(
        //   onWillPop: () {
        //     if (showPopUp) {
        //       setState(() {
        //         showPopUp = false;
        //       });
        //       return Future.value(false);
        //     } else {
        //       return Future.value(true);
        //     }
        //   },
        // child:
        Scaffold(
      backgroundColor:
          Provider.of<ThemeModel>(context).theme.SCAFFOLD_BACKGROUND,
      key: scaffoldKey,
      appBar: CustomAppBar(
        title: Text(appBarText),
        actions: [
          IconButton(
              icon: Icon(CupertinoIcons.calendar),
              iconSize: 30,
              color: Colors.white,
              onPressed: () async {
                var openExternalCalendar = await showChoiceAlert(
                    context,
                    'Open Calendar in Device Default',
                    'Are you sure you want to open events in Device Calendar?',
                    UrlHandler.launchDeviceCalendar);
                if (openExternalCalendar == null) {}
                // Navigator.pop(context);
              }),
        ],
      ),
      drawer: AppDrawer(tag: 'Calendar'),
      floatingActionButton: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(left: 31),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                onPressed: () async {
                  openEditorDirectly();
                },
                child: Icon(Icons.add),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () {
                showModalBottomSheet(
                  //expand: false,
                  context: context,
                  builder: (context) => CustomModal(changeViewType, viewType,
                      showAgenda, calendarModel, changeExempted, exempted),
                );
              },
              child: Icon(Icons.graphic_eq),
            ),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _tasks,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error occured'));
          } else if (snapshot.connectionState == ConnectionState.done) {
            return Stack(children: [
              Opacity(
                opacity: showPopUp ? 0.2 : 1,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: CustomCalendar(),
                    ),
                  ],
                ),
              ),
              !showPopUp
                  ? Container()
                  : Center(
                      child: Container(
                        color: Colors.transparent,
                        height: 500,
                        child: Center(
                            child: CustomSwiper(
                                _calendarController.selectedDate, _events)),
                      ),
                    ),
            ]);
          }
          return SpinKitWave(color: Colors.white, type: SpinKitWaveType.end);
        },
      ),
      // ),
    );
  }
}
