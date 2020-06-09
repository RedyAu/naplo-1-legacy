import 'dart:async';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:filcnaplo/cards/lesson_card.dart';
import 'package:filcnaplo/cards/tomorrow_lesson_card.dart';
import 'package:filcnaplo/generated/i18n.dart';
import 'package:filcnaplo/utils/string_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:filcnaplo/cards/summary_card.dart';
import 'package:filcnaplo/cards/absence_card.dart';
import 'package:filcnaplo/cards/changed_lesson_card.dart';
import 'package:filcnaplo/cards/evaluation_card.dart';
import 'package:filcnaplo/cards/note_card.dart';
import 'package:filcnaplo/models/account.dart';
import 'package:filcnaplo/models/lesson.dart';
import 'package:filcnaplo/models/note.dart';
import 'package:filcnaplo/models/student.dart';
import 'package:filcnaplo/global_drawer.dart';
import 'package:filcnaplo/helpers/background_helper.dart';
import 'package:filcnaplo/helpers/settings_helper.dart';
import 'package:filcnaplo/helpers/timetable_helper.dart';
import 'package:filcnaplo/dialogs/add_homework_dialog.dart';
import 'package:filcnaplo/globals.dart' as globals;
import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateMd5(String input) {
  return md5.convert(utf8.encode(input)).toString();
}

void main() {
  runApp(MaterialApp(
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List HomeScreenCards;
  List<Evaluation> evaluations = List();
  Map<String, List<Absence>> absents = Map();
  List<Note> notes = List();
  List<Lesson> lessons = List();
  DateTime get now => DateTime.now();
  DateTime startDate;
  bool hasOfflineLoaded = false;
  bool hasLoaded = true;
  List realLessons;
  bool isLessonsToday = false;
  bool isLessonsTomorrow = false;

  List<Lesson> lessonsToday;
  List<Lesson> lessonsTomorrow;

  void _initSettings() async {
    DynamicTheme.of(context).setBrightness(await SettingsHelper().getDarkTheme()
        ? Brightness.dark
        : Brightness.light);
    BackgroundHelper().configure();
    // refresh color settings
    globals.color1 = await SettingsHelper().getEvalColor(0);
    globals.color2 = await SettingsHelper().getEvalColor(1);
    globals.color3 = await SettingsHelper().getEvalColor(2);
    globals.color4 = await SettingsHelper().getEvalColor(3);
    globals.color5 = await SettingsHelper().getEvalColor(4);
    globals.colorF1 =
        globals.color1.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
    globals.colorF2 =
        globals.color2.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
    globals.colorF3 =
        globals.color3.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
    globals.colorF4 =
        globals.color4.computeLuminance() >= 0.5 ? Colors.black : Colors.white;
    globals.colorF5 =
        globals.color5.computeLuminance() >= 0.5 ? Colors.black : Colors.white;

    if (globals.users.length == 1) {
      globals.isSingle = true;
      SettingsHelper().setSingleUser(true);
    }

    /*
    
    */
  }

  @override
  void initState() {
    _initSettings();
    super.initState();
    
    globals.context = context; //For i18n of error msgs

    //First load in existing data from database, then try to update from kréta.
    _onRefresh(offline: true, showErrors: false).then((var a) async {
      if (globals.firstMain) {
      _onRefresh(offline: false, showErrors: false).then((var a) async {
        HomeScreenCards = await feedItems();
      },
      onError: (e) {print("Online refresh error: " + e.toString());});
      globals.firstMain = false;
    } else {
      HomeScreenCards = await feedItems();
    }
    },
    onError: (e) {print("Offline refresh error: " + e.toString());});
    Timer(Duration(seconds: 3), () async {
      if (!globals.homepageNotificationRead) _showHomepageNotification();
    });
    startDate = now;
    Timer.periodic(
        Duration(seconds: 10),
        (Timer t) => () async {
              HomeScreenCards = await feedItems();
              setState(() {});
            });
  }

  Future<List<Widget>> feedItems() async {
    int maximumFeedLength = 50;
    List<Widget> feedCards = List();

    for (Account account in globals.accounts) {
      List<Evaluation> firstQuarterEvaluations = (evaluations.where(
          (Evaluation evaluation) => (evaluation.isFirstQuarter() &&
              evaluation.owner == account.user))).toList();
      List<Evaluation> secondQuarterEvaluations = (evaluations.where(
          (Evaluation evaluation) => (evaluation.isSecondQuarter() &&
              evaluation.owner == account.user))).toList();
      List<Evaluation> thirdQuarterEvaluations = (evaluations.where(
          (Evaluation evaluation) => (evaluation.isThirdQuarter() &&
              evaluation.owner == account.user))).toList();
      List<Evaluation> fourthQuarterEvaluations = (evaluations.where(
          (Evaluation evaluation) => (evaluation.isFourthQuarter() &&
              evaluation.owner == account.user))).toList();

      List<Evaluation> halfYearEvaluations = (evaluations.where(
          (Evaluation evaluation) => (evaluation.isHalfYear() &&
              evaluation.owner == account.user))).toList();
      List<Evaluation> endYearEvaluations = (evaluations.where(
              (Evaluation evaluation) =>
                  (evaluation.isEndYear() && evaluation.owner == account.user)))
          .toList();

      if (firstQuarterEvaluations.isNotEmpty)
        feedCards.add(SummaryCard(firstQuarterEvaluations, context, 1, false,
            true, !globals.isSingle));
      if (secondQuarterEvaluations.isNotEmpty)
        feedCards.add(SummaryCard(secondQuarterEvaluations, context, 2, false,
            true, !globals.isSingle));
      if (thirdQuarterEvaluations.isNotEmpty)
        feedCards.add(SummaryCard(thirdQuarterEvaluations, context, 3, false,
            true, !globals.isSingle));
      if (fourthQuarterEvaluations.isNotEmpty)
        feedCards.add(SummaryCard(fourthQuarterEvaluations, context, 4, false,
            true, !globals.isSingle));

      if (halfYearEvaluations.isNotEmpty)
        feedCards.add(SummaryCard(
            halfYearEvaluations, context, 5, false, true, !globals.isSingle));
      if (endYearEvaluations.isNotEmpty)
        feedCards.add(SummaryCard(
            endYearEvaluations, context, 6, false, true, !globals.isSingle));
    }
    List<String> noteHashes = [];
    for (String day in absents.keys.toList())
      feedCards.add(AbsenceCard(absents[day], globals.isSingle, context));
    for (Evaluation evaluation in evaluations.where((Evaluation evaluation) =>
        !evaluation.isSummaryEvaluation())) //Only add non-summary evals
      feedCards.add(EvaluationCard(
          evaluation, globals.isColor, globals.isSingle, context));
    for (Note note in notes) {
      Codec<String, String> stringToBase64 = utf8.fuse(base64);
      String currentNoteHash = generateMd5(stringToBase64.encode(note.content));

      if (!noteHashes.contains(currentNoteHash)) {
        feedCards.add(NoteCard(note, globals.isSingle, context));
      } else {
        print("[i] home_screen.feedItems(): skipped duplicate note #" +
            currentNoteHash);
      }
      noteHashes.add(currentNoteHash);
    }
    for (Lesson l in lessons.where((Lesson lesson) =>
        (lesson.isMissed || lesson.isSubstitution) && lesson.date.isAfter(now)))
      feedCards.add(ChangedLessonCard(l, context));

    //realLessons = lessons.where((Lesson l) => !l.isMissed).toList();
    lessonsToday = lessons
        .where((Lesson lesson) => (lesson.start.day == now.day))
        .toList();
    lessonsTomorrow = lessons
        .where((Lesson lesson) =>
            (lesson.start.day == now.add(Duration(days: 1)).day))
        .toList();

    try {
      if (lessonsToday.length > 0 && lessonsToday.last.end.isAfter(now)) {
        isLessonsToday = true;
        isLessonsTomorrow = false;
      } else if (lessonsTomorrow.first.start.day ==
          now.add(Duration(days: 1)).day) {
        isLessonsToday = false;
        isLessonsTomorrow = true;
      } else {
        isLessonsToday = false;
        isLessonsTomorrow = false;
      }

      if (isLessonsToday) feedCards.add(LessonCard(lessonsToday, context));
      if (isLessonsTomorrow)
        feedCards.add(TomorrowLessonCard(lessonsTomorrow, context, now));
    } catch (e) {
      print("[E] HomeScreen.feedItems() (1): " + e.toString());
    }

    try {
      feedCards.sort((Widget a, Widget b) {
        return b.key.toString().compareTo(a.key.toString());
      });
    } catch (e) {
      print("[E] HomeScreen.feedItems() (2): " + e.toString());
    }

    if (maximumFeedLength > feedCards.length)
      maximumFeedLength = feedCards.length;
    return feedCards.sublist(0, maximumFeedLength);
  }

  Future<bool> _onWillPop() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(I18n.of(context).closeTitle),
          content: Text(I18n.of(context).closeConfirm),
          actions: <Widget>[
            FlatButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(I18n.of(context).dialogNo.toUpperCase()),
            ),
            FlatButton(
              onPressed: () async {
                await SystemChannels.platform
                    .invokeMethod<void>('SystemNavigator.pop');
              },
              child: Text(I18n.of(context).dialogYes.toUpperCase()),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _addHomeworkToThisSubject() {
    return showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return ChooseLessonDialog(
              0, globals.currentLesson.subject, globals.currentLesson.teacher);
        });
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          drawer: GlobalDrawer(),
          appBar: AppBar(
            title: Text(globals.isSingle
                ? globals.selectedAccount.user.name
                : I18n.of(context).appTitle),
          ),
          body: hasOfflineLoaded &&
                  globals.isColor != null &&
                  HomeScreenCards != null
              ? Container(
                  child: Column(children: <Widget>[
                  !hasLoaded
                      ? Container(
                          child: LinearProgressIndicator(
                            value: null,
                          ),
                          height: 3,
                        )
                      : Container(
                          height: 3,
                        ),
                  Expanded(
                    child: RefreshIndicator(
                      child: ListView(
                        children: HomeScreenCards,
                      ),
                      onRefresh: () {
                        Completer<Null> completer = Completer<Null>();
                        _onRefresh(userInit: true).then((bool b) async {
                          HomeScreenCards = await feedItems();
                          setState(() {
                            completer.complete();
                          });
                        });
                        return completer.future;
                      },
                    ),
                  ),
                ]))
              : Center(child: CircularProgressIndicator()),
        ));
  }

  Future<Null> _onRefresh(
      {bool offline = false, bool showErrors = true, bool userInit = false}) async {
    List<Evaluation> tempEvaluations = List();
    Map<String, List<Absence>> tempAbsents = Map();
    List<Note> tempNotes = List();
    setState(() {
      if (offline)
        hasOfflineLoaded = false;
      else
        hasLoaded = false;
    });
    if (globals.isSingle) {
      try {
        await globals.selectedAccount.refreshStudentString(offline, showErrors, userInit: userInit, context: context);
        tempEvaluations.addAll(globals.selectedAccount.student.Evaluations);
        tempNotes.addAll(globals.selectedAccount.notes);
        tempAbsents.addAll(globals.selectedAccount.absents);
      } catch (exception) {
        print("[E] HomeScreen.onRefresh() (1): " + exception.toString());
      }
    } else {
      for (Account account in globals.accounts) {
        try {
          try {
            await account.refreshStudentString(offline, showErrors, userInit: userInit, context: context);
          } catch (e) {
            print("[E] HomeScreen.onRefresh() (2): " + e.toString());
          }
          tempEvaluations.addAll(account.student.Evaluations);
          tempNotes.addAll(account.notes);
          tempAbsents.addAll(account.absents);
        } catch (exception) {
          print("[E] HomeScreen.onRefresh() (3): " + exception.toString());
        }
      }
    }

    if (tempEvaluations.length > 0) evaluations = tempEvaluations;
    if (tempAbsents.length > 0) absents = tempAbsents;
    if (tempNotes.length > 0) notes = tempNotes;
    startDate = now;

    if (offline) {
      if (globals.lessons.length > 0) {
        lessons.addAll(globals.lessons);
      } else {
        try {
          lessons = await getLessonsOffline(startDate,
              startDate.add(Duration(days: 6)), globals.selectedUser);
        } catch (exception) {
          print("[E] HomeScreen.onRefresh() (4): " + exception.toString());
        }
        if (lessons.length > 0) globals.lessons.addAll(lessons);
      }
    } else {
      try {
        lessons = await getLessons(startDate, startDate.add(Duration(days: 6)),
            globals.selectedUser, showErrors);
      } catch (exception) {
        print("[E] HomeScreen.onRefresh() (5): " + exception.toString());
      }
    }
    try {
      lessons.sort((Lesson a, Lesson b) => a.start.compareTo(b.start));
      if (lessons.length > 0) globals.lessons = lessons;
    } catch (e) {
      print("[E] HomeScreen.onRefresh() (6): " + e.toString());
    }
    Completer<Null> completer = Completer<Null>();
    if (!offline) hasLoaded = true;
    hasOfflineLoaded = true;
    if (mounted) {
      setState(() {
        completer.complete();
      });
    }
    return completer.future;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showHomepageNotification() async {
    String websiteUrl = "http://filcnaplo.hu/kerdoiv";
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Küldj ötletet a Filc 2.0-hoz!"),
            content: SingleChildScrollView(
              child: Text("""A Filc Napló újraírása mellett döntöttünk.
Ennek egyik fő oka az, hogy a Kréta egy új, jelenleg zárt béta fázisban levő appon dolgozik, ami immár nem küzd a logikátlanság és lassúság gyerekbetegségével. Ezért a Filcet egy teljes körű iskolai asszisztenssé szeretnénk tenni, ami pl. megmondja, holnap mire kell készülnöd, amiben beoszthatod az idődet, stb.
Ehhez kérnénk segítségeteket, szeretnénk megtudni, milyen funkciókra van szükségetek.

Ötleteidet megoszthatod velünk a "Megnyitás" gombot választva, egy Google Forms kérdőíven."""),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text(I18n.of(context).dialogOpen),
                onPressed: () {
                  SettingsHelper().setHomepageNotificationRead(globals.homepageNotificationName);
                  globals.homepageNotificationRead = true;
                  _launchWebpage(websiteUrl);
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: Text(I18n.of(context).dialogLater),
                onPressed: () {
                  globals.homepageNotificationRead = true;
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: Text(I18n.of(context).dialogClose),
                onPressed: () {
                  SettingsHelper().setHomepageNotificationRead(globals.homepageNotificationName);
                  globals.homepageNotificationRead = true;
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }
  _launchWebpage(String url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw "Could not launch newsletter. $url";
  }
  }
}
