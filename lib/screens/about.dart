// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, non_constant_identifier_names
import 'package:flutter/material.dart';

class About extends StatelessWidget {
  const About({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(240,240,235,1.0),
      appBar: AppBar(
        title: Text('About Us'),
        backgroundColor: Color.fromRGBO(4, 98, 126, 1.0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: 10.0),
            Center(
              child: Image(
                image: AssetImage('assets/img.png'),
                height: 200,
                fit: BoxFit.fitHeight,
              ),
            ),
            SizedBox(height: 30.0),
            Text(
              "Designed to aid rehabilitation efforts, the 'Meaning' app is  to be used by patients and therapists of the Meaning Drug Rehab Centre.",
              style: TextStyle(
                fontSize: 18,
              ),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15.0),
            Text(
              "The app aims to encourage the recovery of rehabilitation patients and for them to find their meaning of life, hence the name of our app and rehab centre.",
              style: TextStyle(
                fontSize: 18,
              ),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 15.0),
            Text(
              "To 'put one foot infront of the other' means to walk continuously and carefully even in difficult times. Therefore, the shoe logo represents the goal of our app to support our patients in getting back on their feet, one step at a time.",
              style: TextStyle(
                fontSize: 18,
              ),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }
}