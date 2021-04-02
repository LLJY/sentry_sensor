import 'package:flutter/material.dart';

class Overlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Column(
          children: [
            Icon(
              Icons.camera,
              color: Colors.red,
              size: 300.0,
            ),
            Text(
              "Smile! You are being recorded!",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
                fontFamily: 'Roboto',
                letterSpacing: 0.5,
                fontSize: 25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
