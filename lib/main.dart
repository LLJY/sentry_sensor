import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:sensors/sensors.dart';
import 'package:sentry_sensor/lat_lng.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/uuid_util.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_geofence/geofence.dart';

List<CameraDescription>? cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await Firebase.initializeApp();
  Geofence.initialize();
  runApp(MaterialApp(home: HomePage()));
}

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _HomePageState();
}
enum AppState{
  STATE_LISTENING,
  STATE_UNLOCKED,
  STATE_RECORDING,
  STATE_STOLEN
}
class _HomePageState extends State {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  CameraController? controller;
  FirebaseStorage _storage = FirebaseStorage.instance;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Coordinate? geoFenceLatLng;
  AppState _appState = AppState.STATE_LISTENING;
  LatLng? curLocation;
  LatLng? prevLocation;

  void setAppState(AppState state){
    if(geoFenceLatLng != null) {
      switch (state) {
        case AppState.STATE_LISTENING:
          if (controller!.value.isRecordingVideo) {
            controller!.stopVideoRecording();
          }
          break;
        case AppState.STATE_UNLOCKED:
          if (controller!.value.isRecordingVideo) {
            controller!.stopVideoRecording();
          }
          break;
        case AppState.STATE_RECORDING:
          recordAndUploadVideo();
          break;
        case AppState.STATE_STOLEN:
          if (controller!.value.isRecordingVideo) {
            controller!.stopVideoRecording();
          }
          break;
      }
      setState(() {
        _appState = state;
      });
    }
  }

  void recordAndUploadVideo() async {
    await controller!.startVideoRecording();
    await Future.delayed(Duration(seconds: 10));
    try {
      var recording = await controller!.stopVideoRecording();
      // get the file
      var recordingFile = File(recording.path);
      // upload the file to firebase with a unique uuid
      var finishedTask = await _storage.ref(Uuid().v4()).putFile(recordingFile);
      var downloadUrl = await finishedTask.ref.getDownloadURL();
      print(downloadUrl);
      await uploadSentryEvent(downloadUrl);
      setAppState(AppState.STATE_LISTENING);
    }catch(ex){

    }
  }

  Future<void> uploadSentryEvent(String downloadUrl) async {
    await _firestore.collection("sentry_activities").add({
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "type": 0,
      "videoUrl": downloadUrl
    });
  }

  void setGeoFence() async {
    // request permission
    var permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      showDialog(
              context: context,
              builder: (builder) {
                return Text("Location required, exiting app...");
              },
              barrierDismissible: false)
          .then((stuff) {
        // exit the app until permission accepted
        SystemNavigator.pop();
      });
    }
    // remove all geolocation so that we do not trigger previous set locations
    var location = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    print("Location $location");
    Geolocator.getPositionStream(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: true)
        .listen((event) {
      print("location event $event");
      prevLocation = curLocation;
      curLocation = LatLng(event.latitude, event.longitude);
      // if not stolen, evaluate if stolen
      if(_appState != AppState.STATE_STOLEN){
        if(Geolocator.distanceBetween(geoFenceLatLng!.latitude, geoFenceLatLng!.longitude, curLocation!.latitude, curLocation!.longitude) > 300 ){
          _firestore.collection("sentry_activities").add({
            "timestamp": DateTime.now().millisecondsSinceEpoch,
            "type": 1,
            "videoUrl": ""
          });
          setAppState(AppState.STATE_STOLEN);
        }
        // if stolen, stream location
      }else{
          _firestore.collection("bike_location").doc("default").set({
            "location": GeoPoint(event.latitude, event.longitude)
          });
          setAppState(AppState.STATE_STOLEN);
      }



    });

    setState(() {
      geoFenceLatLng = Coordinate(location.latitude, location.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    // set the body depending on warning or not
    switch(_appState){
      case AppState.STATE_LISTENING:
        body = controller!.value.isInitialized && geoFenceLatLng != null
            ? Center(
          child: Text("Recording events to keep your bike safe!"),
        )
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(
                height: 10,
              ),
              Text(
                "Loading...",
                textAlign: TextAlign.center,
              )
            ],
          ),
        );
        break;
      case AppState.STATE_UNLOCKED:
        body = controller!.value.isInitialized
            ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Unlocked! Have a safe ride!"),
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        setAppState(AppState.STATE_LISTENING);
                        setGeoFence();
                      });
                    },
                    child: Text("Lock"))
              ],
            ))
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(
                height: 10,
              ),
              Text(
                "Loading...",
                textAlign: TextAlign.center,
              )
            ],
          ),
        );
        break;
      case AppState.STATE_RECORDING:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: Expanded(
                    child: Icon(
                      Icons.camera,
                      size: 150,
                      color: Colors.red,
                    )),
              ),
              SizedBox(
                height: 20,
              ),
              Text(
                "Smile ! You're being recorded!",
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              )
            ],
          ),
        );
        break;
      case AppState.STATE_STOLEN:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: Expanded(
                    child: Icon(
                      Icons.warning_amber_outlined,
                      size: 150,
                      color: Colors.amber,
                    )),
              ),
              SizedBox(
                height: 20,
              ),
              Text(
                "Warning! Your location is being tracked!",
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              )
            ],
          ),
        );
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Sentry Sensor"),
      ),
      body: body,
    );
  }

  @override
  void initState() {
    super.initState();
    // initialize the camera controller and then asynchronously setstate
    controller = CameraController(cameras![1], ResolutionPreset.high);
    // initialize the controller and then prepare for video rec (to reduce latency)
    controller!.initialize().then((value) {
      controller!.prepareForVideoRecording().then((value) {
        setState(() {});
      });
    });
    setGeoFence();
    startFlutterBlue();

    userAccelerometerEvents.listen((event) {
      if (_appState != AppState.STATE_UNLOCKED || _appState != AppState.STATE_STOLEN) {
        // measure the total magnitude of forces acting on the accelerometer
        var accMag = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
        // if total acceleration more than 2.1m/s^2, report it!
        // note: 2.1 is an arbitrary number!
        if (accMag > 1 && !controller!.value.isRecordingVideo) {
          print("recording!");
          setAppState(AppState.STATE_RECORDING);
        }
      }
    });
  }

  void startFlutterBlue() async {
    while (true) {
      // scan every 2 seconds
      await Future.delayed(Duration(seconds: 2));
      // do not scan when bike is unlocked, recording or whatver as it can really break
      if (_appState != AppState.STATE_RECORDING && _appState != AppState.STATE_UNLOCKED) {
        var devices = await flutterBlue.connectedDevices;
        // unlock if any devices are paired
        if (devices.length > 0) {
          print("unlocked! $devices");
          setAppState(AppState.STATE_UNLOCKED);
        }
      }
    }
  }
}
