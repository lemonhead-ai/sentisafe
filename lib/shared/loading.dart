// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Loading extends StatelessWidget {
  const Loading({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromRGBO(240,240,235,1.0),
      child: Center(
        child: SpinKitDoubleBounce(
          color: Color.fromRGBO(4, 98, 126,1.0),
          size: 50.0,
        ),
      ),
    );
  }
}