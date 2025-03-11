import 'package:flutter/material.dart';

const textInputDecoration = InputDecoration(
  fillColor: Colors.white,
  filled: true,
  enabledBorder: OutlineInputBorder(  // border style for enabled input fields
    borderSide: BorderSide(color:Colors.white, width:2.0),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color:Color.fromRGBO(134,148,133,1), width:2.0),
  )
);