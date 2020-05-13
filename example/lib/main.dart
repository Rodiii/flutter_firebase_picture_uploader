import 'package:firebase_picture_uploader/firebase_picture_uploader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void main() => runApp(ExampleApp());

class ExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHome(),
    );
  }
}

class MyHome extends StatefulWidget {
  @override
  _MyHomeState createState() => new _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  List<UploadJob> _profilePictures = [];

  @override
  Widget build(BuildContext context) {
    final profilePictureTile = new Material(
      color: Colors.transparent,
      child: new Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Profile Picture',
              style: TextStyle(
                color: CupertinoColors.systemBlue,
                fontSize: 15.0,
              )),
          const Padding(
            padding: EdgeInsets.only(bottom: 5.0),
          ),
          new PictureUploadWidget(
            onPicturesChange: profilePictureCallback,
            initialImages: _profilePictures,
            settings: PictureUploadSettings(onErrorFunction: onErrorCallback),
            buttonStyle: const PictureUploadButtonStyle(),
            buttonText: 'Upload Picture',
            enabled: true,
          ),
        ],
      ),
    );

    return new Scaffold(
      body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 50),
          child: Column(children: <Widget>[profilePictureTile])),
    );
  }

  void onErrorCallback(error, stackTrace) {
    print(error);
    print(stackTrace);
  }

  void profilePictureCallback(
      {List<UploadJob> uploadJobs, bool pictureUploadProcessing}) {
    _profilePictures = uploadJobs;
  }
}
