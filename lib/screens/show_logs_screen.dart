import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../screens/show_log_detail_screen.dart';
import '../managers/LogManager.dart';
import '../managers/FileManager.dart';
import '../managers/SettingsManager.dart';

class ShowLogsScreen extends StatefulWidget {
  const ShowLogsScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/show_logs_screen';

  @override
  State<ShowLogsScreen> createState() => _ShowLogsScreenState();
}

class _ShowLogsScreenState extends State<ShowLogsScreen> {
  List<Block> _blocks = [];

  Blockchain _blockchain = Blockchain(time: 'INIT TIME', blocks: []);

  List<String> timeLapses = [];

  List<int> sessionTimes = [];

  bool _isDarkModeEnabled = false;

  final fileManager = FileManager();
  final logManager = LogManager();
  final settingsManager = SettingsManager();

  @override
  void initState() {
    super.initState();
    logManager.log("ShowLogsScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _readLogs();
  }

  void _readLogs() async {
    final logData = await fileManager.readLogData();
    logManager.logger.wtf("_readLogs: $logData");
    if (logData != null) {
      if (logData.isNotEmpty) {
        setState(() {
          _blockchain = Blockchain.fromRawJson(logData);
          _blocks = _blockchain.blocks;

          _blocks.sort((a, b) {
            return b.time.compareTo(a.time);
          });

          sessionTimes = [];
          _blocks.forEach((element) {
            logManager.logger.wtf("${element.toJson()}");
            final a = DateTime.parse(element.logList.list.first.time);
            final b = DateTime.parse(element.logList.list.last.time);

            final dt = b.difference(a).inSeconds;
            sessionTimes.add(dt);
          });
        });

        await logManager.verifyLogFile().then((value) {

        });

        buildTimeLapse();
      }
    }
  }

  void buildTimeLapse() {
    int timeLapseIndex = 0;
    int blockIndex = 0;
    String currentTimeLapseString = '';
    timeLapses = [];
    List<int> timeIntervals = [];
    List<int> windowTimeIntervals = [];

    DateTime firstTime = DateTime.now();
    DateTime secondTime = DateTime.now();

    for (var iblock in _blocks) {
      // print('new block......................');
      windowTimeIntervals.add(999999999);
      blockIndex += 1;
      timeIntervals = [];
      for (var ilist in iblock.logList.list) {
        if (timeLapseIndex == 0) {
          firstTime = DateTime.parse(ilist.time);
          secondTime = DateTime.parse(ilist.time);
          timeIntervals.add(0);
        } else {
          secondTime = DateTime.parse(ilist.time);
          timeIntervals.add(secondTime.difference(firstTime).inMilliseconds);
        }

        if (timeLapseIndex > 0) {
          windowTimeIntervals.add(timeIntervals[timeLapseIndex] -
              timeIntervals[(timeLapseIndex - 1)]);
        }
        // else {
        // windowTimeIntervals.add(999999999);
        // }

        // print('t:${secondTime.difference(firstTime).inMilliseconds}');

        final msg = ilist.message;
        // final line = '${ilist.callingFunction}:\n$msg';

        // final hasFailure = msg.contains("failure");
        final validPinCode = msg.contains("Valid Pin Code");
        final invalidPinCode = msg.contains("Invalid Pin Code");

        final validBiometrics = msg.contains("Authenticated Biometrics: true");
        // final validBiometrics = msg.contains("Authenticated Biometrics: true");

        final validPassword = msg.contains("deriveKeyCheck: true");
        final invalidPassword = msg.contains("deriveKeyCheck: false");
        // final screenChange = msg.contains("initState");
        // final appLifecycleState = msg.contains("AppLifecycleState");
        // final savedItem = line.contains("KeychainManager.saveItem:🧬");

        if (validBiometrics) {
          currentTimeLapseString += "🧬";
        } else if (validPassword) {
          currentTimeLapseString += "🔑";
        } else if (validPinCode) {
          currentTimeLapseString += "🅿️";
        } else if (invalidPinCode) {
          currentTimeLapseString += "❌";
        } else if (invalidPassword) {
          currentTimeLapseString += "❌";
        }

        timeLapseIndex += 1;
      }
      timeLapses.add(currentTimeLapseString);
      currentTimeLapseString = '';
      timeLapseIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        // title: Text(
        //     'Logs: \$$_lifeTimeInSeconds\nsize: ${(_lifeTimeInSeconds / (logManager.latestLogSizeInBytes / 1024)).toStringAsFixed(2)} \$/KB'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView.separated(
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemCount: _blocks.length,
        itemBuilder: (context, index) {
          return ListTile(
            isThreeLine: true,
            title: Text(
              '${DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.parse(_blocks[index].time))}\nsession #: ${_blocks[index].blockNumber + 1} | ${sessionTimes[index]} seconds',
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
              ),
            ),
            subtitle: Text(
              timeLapses.length > 0 ? timeLapses[index] : "",
              // 'session #: ${_blocks[index].blockNumber + 1}',
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShowLogDetailScreen(
                    block: _blockchain.blocks[index],
                  ),
                  fullscreenDialog: true,
                ),
              ).then((value) {
                _readLogs();
              });
            },
          );
        },
      ),
    );
  }
}
