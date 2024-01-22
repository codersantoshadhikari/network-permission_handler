import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiFi Attendance App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final String userId =
      'user123'; // This should be dynamically set or retrieved.

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  void requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.locationAlways,
      Permission.locationWhenInUse,
    ].request();
    print(statuses[Permission.location]);
  }

  void toggleWiFi(bool turnOn) async {
    await WiFiForIoTPlugin.setEnabled(turnOn);
  }

  Future<String?> getCurrentSSID() async {
    try {
      String? ssid = await WiFiForIoTPlugin.getSSID();
      return ssid;
    } catch (e) {
      print(e);
      return null;
    }
  }

  void markAttendance(String userId) async {
    String? currentSSID = await getCurrentSSID();
    if (currentSSID != null) {
      final prefs = await SharedPreferences.getInstance();
      final attendanceKey = 'attendance_$userId';
      List<String> attendanceRecords = prefs.getStringList(attendanceKey) ?? [];

      final newRecord = json.encode({
        'networkId': currentSSID,
        'timestamp': DateTime.now().toIso8601String(),
      });

      attendanceRecords.add(newRecord);
      await prefs.setStringList(attendanceKey, attendanceRecords);

      if (kDebugMode) {
        print('Attendance marked successfully for network: $currentSSID');
      }
    } else {
      print('Failed to get current SSID');
    }
  }

  Future<List> getAttendanceRecords(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final attendanceKey = 'attendance_$userId';
    List<String> attendanceRecords = prefs.getStringList(attendanceKey) ?? [];

    return attendanceRecords.map((record) => json.decode(record)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Attendance App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => toggleWiFi(true),
              child: const Text('Turn WiFi On'),
            ),
            ElevatedButton(
              onPressed: () => toggleWiFi(false),
              child: const Text('Turn WiFi Off'),
            ),
            ElevatedButton(
              onPressed: () => markAttendance(userId),
              child: const Text('Mark Attendance'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        AttendanceRecordsScreen(userId: userId)),
              ),
              child: const Text('View Attendance Records'),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceRecordsScreen extends StatelessWidget {
  final String userId;

  AttendanceRecordsScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Records'),
      ),
      body: FutureBuilder(
        future: _MyHomePageState().getAttendanceRecords(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final records = snapshot.data;
            return ListView.builder(
              itemCount: records?.length,
              itemBuilder: (context, index) {
                final record = records?[index];
                return ListTile(
                  title: Text('Network: ${record['networkId']}'),
                  subtitle: Text('Timestamp: ${record['timestamp']}'),
                );
              },
            );
          }
        },
      ),
    );
  }
}
