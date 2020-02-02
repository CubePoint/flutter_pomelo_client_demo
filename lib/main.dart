import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:flutter_pomelo_client_demo/pages/main.dart';
final mainPage = MainPage();


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
 
  @override
  Widget build(BuildContext context) {
    ScreenUtil.instance = ScreenUtil(width: 750, height: 1334)..init(context);
    SystemChrome.setEnabledSystemUIOverlays([]);
    return Scaffold(
      body: mainPage,
    );
  }
}
