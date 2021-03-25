import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          centerTitle: true,
          title: Text("Sentry Sensor"),
          backgroundColor: Colors.blueGrey[900],
        ),
        body: Center(
          accelerometerEvents.listen((AccelerometerEvent event) {

          }
        ),
      ),
    ),
  );
}
