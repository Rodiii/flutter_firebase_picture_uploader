import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'firebase_picture_upload_controller.dart';

class PictureUploadSettings {
  const PictureUploadSettings(
      {this.uploadDirectory = '/Uploads/',
      this.customUploadFunction,
      this.customDeleteFunction,
      this.onErrorFunction,
      this.minImageCount = 0,
      this.maxImageCount = 5,
      this.imageManipulationSettings = const ImageManipulationSettings()});

  final String uploadDirectory;
  final Function customUploadFunction;
  final Function customDeleteFunction;
  final Function onErrorFunction;
  final int minImageCount;
  final int maxImageCount;

  final ImageManipulationSettings imageManipulationSettings;
}

class ImageManipulationSettings {
  const ImageManipulationSettings(
      {this.aspectRatio = const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
      this.maxWidth = 800,
      this.maxHeight = 800,
      this.compressQuality = 75});
  final CropAspectRatio aspectRatio;
  final int maxWidth;
  final int maxHeight;
  final int compressQuality;
}

class PictureUploadButtonStyle {
  const PictureUploadButtonStyle({
    this.iconData = CupertinoIcons.photo_camera,
    this.iconSize = 40.0,
    this.backgroundColor = CupertinoColors.systemBlue,
    this.fontColor = CupertinoColors.white,
    this.fontSize = 14.0,
  });

  final IconData iconData;
  final double iconSize;
  final Color backgroundColor;
  final Color fontColor;
  final double fontSize;
}

class PictureUploadWidget extends StatefulWidget {
  PictureUploadWidget(
      {@required this.onPicturesChange,
      this.settings = const PictureUploadSettings(),
      this.initialImages,
      this.buttonText = 'Upload Picture',
      this.buttonStyle = const PictureUploadButtonStyle(),
      this.enabled = true});

  final Function onPicturesChange;
  final List<UploadJob> initialImages;
  final String buttonText;
  final bool enabled;

  final PictureUploadSettings settings;
  final PictureUploadButtonStyle buttonStyle;

  static final FirebasePictureUploadController pictureUploadController =
      new FirebasePictureUploadController();

  @override
  _PictureUploadWidgetState createState() => new _PictureUploadWidgetState();
}

/// State of the widget
class _PictureUploadWidgetState extends State<PictureUploadWidget> {
  int _uploadsProcessing = 0;
  List<UploadJob> _activeUploadedFiles = [];

  @override
  void initState() {
    super.initState();

    if (widget.initialImages != null && widget.initialImages.isNotEmpty) {
      _activeUploadedFiles.addAll(widget.initialImages);
    }

    if (_activeUploadedFiles.length < widget.settings.maxImageCount) {
      _activeUploadedFiles.add(new UploadJob());
    }
  }

  bool activeJobsContainUploadWidget() {
    for (var job in _activeUploadedFiles) {
      if (job.storageReference == null &&
          job.image == null &&
          job.imageProvider == null &&
          job.oldImage == null &&
          job.oldStorageReference == null) {
        return true;
      }
    }
    return false;
  }

  void onImageChange(UploadJob uploadJob) {
    // update Uploadjobs list
    for (int i = _activeUploadedFiles.length - 1; i >= 0; i--) {
      if (_activeUploadedFiles[i].id == uploadJob.id) {
        _activeUploadedFiles[i] = uploadJob;
        break;
      }
    }

    // add / remove from processing list
    if (uploadJob.uploadProcessing) {
      _uploadsProcessing++;

      // add most recent object
      if (uploadJob.action == UploadAction.actionUpload &&
          _activeUploadedFiles.length < widget.settings.maxImageCount) {
        _activeUploadedFiles.add(new UploadJob());
      }
    } else {
      _uploadsProcessing--;

      if (uploadJob.action == UploadAction.actionUpload) {
        // issue occured? => remove
        if (uploadJob.storageReference == null) {
          // remove from active uploaded files
          for (int i = _activeUploadedFiles.length - 1; i >= 0; i--) {
            if (_activeUploadedFiles[i].id == uploadJob.id) {
              _activeUploadedFiles.removeAt(i);
              break;
            }
          }
        }
      } else if (uploadJob.action == UploadAction.actionDelete &&
          uploadJob.image == null) {
        // remove from active uploaded files
        for (int i = _activeUploadedFiles.length - 1; i >= 0; i--) {
          if (_activeUploadedFiles[i].id == uploadJob.id) {
            _activeUploadedFiles.removeAt(i);
            break;
          }
        }

        if (_activeUploadedFiles.length == widget.settings.maxImageCount - 1 &&
            !activeJobsContainUploadWidget()) {
          _activeUploadedFiles.add(new UploadJob());
        }
      }
    }

    final List<UploadJob> uploadedImages = [];
    for (var curJob in _activeUploadedFiles) {
      if (curJob.storageReference != null) {
        uploadedImages.add(curJob);
      }
    }
    widget.onPicturesChange(
        uploadJobs: uploadedImages,
        pictureUploadProcessing: _uploadsProcessing != 0);
    setState(() {
      _activeUploadedFiles = _activeUploadedFiles;
    });
  }

  List<SingleProfilePictureUploadWidget> getCurrentlyUploadedFilesWidgets() {
    final List<SingleProfilePictureUploadWidget> uploadedImages = [];

    int cnt = 0;

    for (UploadJob uploadJob in _activeUploadedFiles) {
      uploadedImages.add(new SingleProfilePictureUploadWidget(
        initialValue: uploadJob,
        onPictureChange: onImageChange,
        position: cnt,
        enabled: widget.enabled,
        enableDelete:
            _activeUploadedFiles.length >= widget.settings.minImageCount,
        settings: widget.settings,
        buttonText: widget.buttonText,
        buttonStyle: widget.buttonStyle,
      ));
      cnt++;
    }

    return uploadedImages;
  }

  @override
  Widget build(BuildContext context) {
    final List<SingleProfilePictureUploadWidget> pictureUploadWidgets =
        getCurrentlyUploadedFilesWidgets();
    return new Wrap(
        spacing: 0.0, // gap between adjacent chips
        runSpacing: 0.0, // gap between lines
        direction: Axis.horizontal, // main axis (rows or columns)
        runAlignment: WrapAlignment.start,
        children: pictureUploadWidgets);
  }
}

class SingleProfilePictureUploadWidget extends StatefulWidget {
  SingleProfilePictureUploadWidget(
      {@required this.initialValue,
      @required this.onPictureChange,
      this.settings,
      this.position,
      this.enableDelete = false,
      this.enabled = true,
      this.buttonText,
      this.buttonStyle})
      : super(key: new Key(initialValue.id.toString()));

  final Function onPictureChange;
  final UploadJob initialValue;
  final bool enableDelete;
  final PictureUploadSettings settings;
  final int position;
  final String buttonText;
  final PictureUploadButtonStyle buttonStyle;
  final bool enabled;

  @override
  _SingleProfilePictureUploadWidgetState createState() =>
      new _SingleProfilePictureUploadWidgetState();
}

/// State of the widget
class _SingleProfilePictureUploadWidgetState
    extends State<SingleProfilePictureUploadWidget> {
  UploadJob _uploadJob;

  @override
  void initState() {
    super.initState();

    _uploadJob = widget.initialValue;

    if (_uploadJob.image == null && _uploadJob.storageReference != null) {
      _uploadJob.uploadProcessing = true;
      PictureUploadWidget.pictureUploadController
          .receiveURL(_uploadJob.storageReference.path)
          .then(onProfileImageURLReceived);
    }
  }

  void onProfileImageURLReceived(String downloadURL) {
    setState(() {
      _uploadJob.imageProvider = CachedNetworkImageProvider(downloadURL);
      _uploadJob.uploadProcessing = false;
    });
  }

  Future _uploadImage() async {
    _uploadJob.action = UploadAction.actionUpload;

    // manipulate image as requested
    final image = await ImagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality:
            widget.settings.imageManipulationSettings.compressQuality);
    if (image == null) {
      return;
    }
    final imageCropped = await PictureUploadWidget.pictureUploadController
        .cropImage(image, widget.settings.imageManipulationSettings);
    if (imageCropped == null) {
      return;
    }

    // update display state
    setState(() {
      _uploadJob.image = imageCropped;
      _uploadJob.uploadProcessing = true;
    });
    widget.onPictureChange(_uploadJob);

    // upload image
    try {
      // in case of custom upload function, use it
      if (widget.settings.customUploadFunction != null) {
        _uploadJob.storageReference =
            widget.settings.customUploadFunction(imageCropped, _uploadJob.id);
      } else {
        // else use default one
        _uploadJob.storageReference = await PictureUploadWidget
            .pictureUploadController
            .uploadProfilePicture(imageCropped, widget.settings.uploadDirectory,
                _uploadJob.id, widget.settings.customUploadFunction);
      }
    } on Exception catch (error, stackTrace) {
      _uploadJob.image = null;
      _uploadJob.storageReference = null;

      if (widget.settings.onErrorFunction != null) {
        widget.settings.onErrorFunction(error, stackTrace);
      } else {
        print(error);
        print(stackTrace);
      }
    }

    setState(() {
      _uploadJob.uploadProcessing = false;
    });
    widget.onPictureChange(_uploadJob);
  }

  Future _deleteImage() async {
    _uploadJob.action = UploadAction.actionDelete;

    setState(() {
      _uploadJob.uploadProcessing = true;
    });

    widget.onPictureChange(_uploadJob);

    final imgBackup = _uploadJob.image;
    setState(() {
      _uploadJob.image = null;
    });

    // delete image
    try {
      // in case of custom delete function, use it
      if (widget.settings.customDeleteFunction != null) {
        await widget.settings.customDeleteFunction(_uploadJob.storageReference);
      } else {
        // else use default one
        await PictureUploadWidget.pictureUploadController
            .deleteProfilePicture(_uploadJob.storageReference);
      }
    } on Exception catch (error, stackTrace) {
      setState(() {
        _uploadJob.image = imgBackup;
      });

      if (widget.settings.onErrorFunction != null) {
        widget.settings.onErrorFunction(error, stackTrace);
      } else {
        print(error);
        print(stackTrace);
      }
    }

    setState(() {
      _uploadJob.uploadProcessing = false;
    });
    widget.onPictureChange(_uploadJob);
  }

  Widget getNewImageButton() {
    final Widget buttonContent = new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(widget.buttonStyle.iconData,
              color: widget.buttonStyle.fontColor,
              size: widget.buttonStyle.iconSize),
          const Padding(padding: const EdgeInsets.only(bottom: 5.0)),
          Text(widget.buttonText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: widget.buttonStyle.fontColor,
                  fontSize: widget.buttonStyle.fontSize)),
        ]);

    return new CupertinoButton(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        child: new Container(
            width: 80.0,
            height: 100.0,
            decoration: BoxDecoration(
                color: widget.buttonStyle.backgroundColor,
                border: Border.all(
                    color: widget.buttonStyle.backgroundColor, width: 0.0),
                borderRadius: new BorderRadius.circular(8.0)),
            child: buttonContent),
        onPressed: !widget.enabled ? null : _uploadImage);
  }

  Widget getExistingImageWidget() {
    final Container existingImageWidget = Container(
        padding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
        child: ClipRRect(
          borderRadius: new BorderRadius.circular(8.0),
          child: _uploadJob.imageProvider != null
              ? Image(
                  image: _uploadJob.imageProvider,
                  width: 80.0,
                  height: 100.0,
                  fit: BoxFit.fitHeight)
              : _uploadJob.image != null
                  ? Image.file(
                      _uploadJob.image,
                      width: 80.0,
                      height: 100.0,
                      fit: BoxFit.fitHeight,
                    )
                  : Container(),
        ));

    final Widget processingIndicator = Container(
        height: 110,
        width: 80,
        child: const Center(child: const CupertinoActivityIndicator()));

    final Widget deleteButton = Container(
        height: 100,
        width: 90,
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              onTap: !widget.enabled ? null : _deleteImage,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                      color: CupertinoColors.lightBackgroundGray, width: 1.0),
                ),
                height: 28.0, // height of the button
                width: 28.0, // width of the button
                child: Icon(Icons.close,
                    color: CupertinoColors.systemBlue, size: 17.0),
              ),
            ),
          ],
        ));

    return new Stack(
      children: [
        existingImageWidget,
        _uploadJob.uploadProcessing
            ? processingIndicator
            : widget.enableDelete ? deleteButton : Container(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uploadJob.image == null &&
        _uploadJob.imageProvider == null &&
        _uploadJob.storageReference == null) {
      return getNewImageButton();
    } else {
      return new Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        getExistingImageWidget(),
      ]);
    }
  }
}

enum UploadAction { actionDelete, actionUpload, actionChange }

class UploadJob {
  UploadJob({this.action});

  UploadAction action;
  int id = DateTime.now().millisecondsSinceEpoch;
  bool uploadProcessing = false;
  File image;
  File oldImage;
  StorageReference oldStorageReference;
  ImageProvider imageProvider; // for existing images

  StorageReference _storageReference;
  StorageReference get storageReference => _storageReference;
  set storageReference(StorageReference storageReference) {
    _storageReference = storageReference;
    if (_storageReference != null &&
        _storageReference.path != null &&
        _storageReference.path != '') {
      final String fileName = _storageReference.path.split('/').last;
      final String id = fileName.split('_')[0];
      this.id = int.parse(id);
    }
  }

  bool compareTo(UploadJob other) {
    if (storageReference != null && other.storageReference != null)
      return storageReference.path == other.storageReference.path;
    else if (image != null && other.image != null)
      return image.path == other.image.path;
    else
      return false;
  }

  @override
  bool operator ==(Object other) {
    if (other is! UploadJob) {
      return false;
    }
    final UploadJob otherUploadJob = other;
    return id == otherUploadJob.id;
  }

  int _hashCode;
  @override
  int get hashCode {
    return _hashCode ??= id.hashCode;
  }
}
