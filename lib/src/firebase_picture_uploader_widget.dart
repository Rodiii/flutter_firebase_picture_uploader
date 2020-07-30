import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'firebase_picture_upload_controller.dart';

/// Defines the source for image selection
enum ImageSourceExtended {
  /// gallery will be opened for image selection
  gallery,

  /// camera will be openend for image selection
  camera,

  /// user will be asked if camera or gallery shall be used
  askUser
}

class PictureUploadLocalization {
  /// Localization for PictureUploadWidget
  const PictureUploadLocalization(
      {this.camera = 'Camera', this.gallery = 'Gallery', this.abort = 'Abort'});

  /// Camera text for image input selection
  final String camera;

  /// Gallery text for image input selection
  final String gallery;

  /// Abort text for image input selection
  final String abort;
}

class PictureUploadSettings {
  /// Basic settings for PictureUploadWidget
  const PictureUploadSettings(
      {this.uploadDirectory = '/Uploads/',
      this.imageSource = ImageSourceExtended.gallery,
      this.customUploadFunction,
      this.customDeleteFunction,
      this.onErrorFunction,
      this.minImageCount = 0,
      this.maxImageCount = 5,
      this.imageManipulationSettings = const ImageManipulationSettings()});

  /// The directory where you want to upload to
  final String uploadDirectory;

  /// Defines which image source shall be used if user clicks button (options: ask_user, gallery, camera)
  final ImageSourceExtended imageSource;

  /// The function which shall be called to upload the image, if you don't want to use the default one
  final Function customUploadFunction;

  /// The function which shall be called to delete the image, if you don't want to use the default one
  final Function customDeleteFunction;

  /// The function which shall be called if an error occurs
  final Function onErrorFunction;

  /// The minimum images which shall be uploaded (controls the delete button)
  final int minImageCount;

  /// The maximum images which can be uploaded
  final int maxImageCount;

  /// The settings how the image shall be modified before upload
  final ImageManipulationSettings imageManipulationSettings;
}

class ImageManipulationSettings {
  /// The settings how the image shall be modified before upload
  const ImageManipulationSettings(
      {this.aspectRatio = const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
      this.maxWidth = 800,
      this.maxHeight = 800,
      this.compressQuality = 75});

  /// The requested aspect ratio for the image
  final CropAspectRatio aspectRatio;

  /// The requested maxWidth of the image
  final int maxWidth;

  /// The requested maxHeight of the image
  final int maxHeight;

  /// The requested compressQuality of the image [0..100]
  final int compressQuality;
}

class PictureUploadButtonStyle {
  /// Style options for PictureUploadWidget
  const PictureUploadButtonStyle({
    this.iconData = CupertinoIcons.photo_camera,
    this.iconSize = 40.0,
    this.backgroundColor = CupertinoColors.systemBlue,
    this.width = 80,
    this.height = 100,
    this.fontColor = CupertinoColors.white,
    this.fontSize = 14.0,
  });

  /// The icon which shall be displayed within the upload button
  final IconData iconData;

  /// The icon size of the icon
  final double iconSize;

  /// The background color of the upload button
  final Color backgroundColor;

  /// The width of the button
  final double width;

  /// The height of the button
  final double height;

  /// The font color of the text within the upload button
  final Color fontColor;

  /// The font size of the text within the upload button
  final double fontSize;
}

class PictureUploadWidget extends StatefulWidget {
  /// PictureUploadWidget displays a customizable button which opens a specified image source (see settings)
  /// which is used to select an image. The selected image can be manipulated and is uploaded afterwards.
  PictureUploadWidget(
      {@required this.onPicturesChange,
      this.settings = const PictureUploadSettings(),
      this.initialImages,
      this.buttonText = 'Upload Picture',
      this.buttonStyle = const PictureUploadButtonStyle(),
      this.localization = const PictureUploadLocalization(),
      this.enabled = true});

  /// Function is called after an image is uploaded, the the UploadJob as parameter
  final Function onPicturesChange;

  /// The images which shall be displayed initiall
  final List<UploadJob> initialImages;

  /// The text displayed within the upload button
  final String buttonText;

  /// Localization for widget texts
  final PictureUploadLocalization localization;

  /// If false, the widget won't react if clicked
  final bool enabled;

  /// All configuration settings for the upload
  final PictureUploadSettings settings;

  /// All ui customization settings for the upload button
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

    if (widget.initialImages != null) {
      _activeUploadedFiles = widget.initialImages;
    }

    if (_activeUploadedFiles.length < widget.settings.maxImageCount &&
        !activeJobsContainUploadWidget()) {
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
          _activeUploadedFiles.length < widget.settings.maxImageCount &&
          !activeJobsContainUploadWidget()) {
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

          if (_activeUploadedFiles.length ==
                  widget.settings.maxImageCount - 1 &&
              !activeJobsContainUploadWidget()) {
            _activeUploadedFiles.add(new UploadJob());
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

    /*
    final List<UploadJob> uploadedImages = [];
    for (var curJob in _activeUploadedFiles) {
      if (curJob.storageReference != null) {
        uploadedImages.add(curJob);
      }
    }
    */

    widget.onPicturesChange(
        uploadJobs: _activeUploadedFiles,
        pictureUploadProcessing: _uploadsProcessing != 0);
    setState(() {
      _activeUploadedFiles = _activeUploadedFiles;
    });
  }

  List<SingleProfilePictureUploadWidget> getCurrentlyUploadedFilesWidgets() {
    final List<SingleProfilePictureUploadWidget> uploadedImages = [];

    int cnt = 0;

    for (UploadJob uploadJob in _activeUploadedFiles) {
      int displayedImagesCount = _activeUploadedFiles.length;
      if (activeJobsContainUploadWidget())
        displayedImagesCount = displayedImagesCount - 1;

      uploadedImages.add(new SingleProfilePictureUploadWidget(
          initialValue: uploadJob,
          onPictureChange: onImageChange,
          position: cnt,
          enableDelete: displayedImagesCount > widget.settings.minImageCount,
          pictureUploadWidget: widget));
      cnt++;
    }

    return uploadedImages;
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUploadedFiles.isEmpty) {
      _activeUploadedFiles.add(new UploadJob());
    }

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
  SingleProfilePictureUploadWidget({
    @required this.initialValue,
    @required this.onPictureChange,
    this.position,
    this.enableDelete = false,
    this.pictureUploadWidget,
  }) : super(key: new Key(initialValue.id.toString()));

  final Function onPictureChange;
  final UploadJob initialValue;
  final bool enableDelete;
  final int position;
  final PictureUploadWidget pictureUploadWidget;

  @override
  _SingleProfilePictureUploadWidgetState createState() =>
      new _SingleProfilePictureUploadWidgetState();
}

/// State of the widget
class _SingleProfilePictureUploadWidgetState
    extends State<SingleProfilePictureUploadWidget> {
  UploadJob _uploadJob;
  final ImagePicker _imagePicker = ImagePicker();

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

  Future<ImageSource> _askUserForImageSource() async {
    return await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: Text(widget.pictureUploadWidget.localization.abort),
          onPressed: () {
            Navigator.pop(context, null);
          },
        ),
        actions: <Widget>[
          CupertinoActionSheetAction(
            child: Text(widget.pictureUploadWidget.localization.camera),
            onPressed: () {
              Navigator.pop(context, ImageSource.camera);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(widget.pictureUploadWidget.localization.gallery),
            onPressed: () {
              Navigator.pop(context, ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future _uploadImage() async {
    _uploadJob.action = UploadAction.actionUpload;

    ImageSource imageSource;
    switch (widget.pictureUploadWidget.settings.imageSource) {
      case ImageSourceExtended.camera:
        imageSource = ImageSource.camera;
        break;
      case ImageSourceExtended.gallery:
        imageSource = ImageSource.gallery;
        break;
      case ImageSourceExtended.askUser:
        imageSource = await _askUserForImageSource();
        break;
    }

    if (imageSource == null) {
      return;
    }

    // manipulate image as requested
    final image = await _imagePicker.getImage(
        source: imageSource,
        imageQuality: widget.pictureUploadWidget.settings
            .imageManipulationSettings.compressQuality);
    if (image == null) {
      return;
    }
    final imageCropped = await PictureUploadWidget.pictureUploadController
        .cropImage(File(image.path),
            widget.pictureUploadWidget.settings.imageManipulationSettings);
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
      if (widget.pictureUploadWidget.settings.customUploadFunction != null) {
        _uploadJob.storageReference = await widget.pictureUploadWidget.settings
            .customUploadFunction(imageCropped, _uploadJob.id);
      } else {
        // else use default one
        _uploadJob.storageReference = await PictureUploadWidget
            .pictureUploadController
            .uploadProfilePicture(
                imageCropped,
                widget.pictureUploadWidget.settings.uploadDirectory,
                _uploadJob.id,
                widget.pictureUploadWidget.settings.customUploadFunction);
      }
    } catch (error, stackTrace) {
      _uploadJob.image = null;
      _uploadJob.storageReference = null;

      if (widget.pictureUploadWidget.settings.onErrorFunction != null) {
        widget.pictureUploadWidget.settings.onErrorFunction(error, stackTrace);
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
      if (widget.pictureUploadWidget.settings.customDeleteFunction != null) {
        await widget.pictureUploadWidget.settings
            .customDeleteFunction(_uploadJob.storageReference);
      } else {
        // else use default one
        await PictureUploadWidget.pictureUploadController
            .deleteProfilePicture(_uploadJob.storageReference);
      }
    } on Exception catch (error, stackTrace) {
      setState(() {
        _uploadJob.image = imgBackup;
      });

      if (widget.pictureUploadWidget.settings.onErrorFunction != null) {
        widget.pictureUploadWidget.settings.onErrorFunction(error, stackTrace);
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
          Icon(widget.pictureUploadWidget.buttonStyle.iconData,
              color: widget.pictureUploadWidget.buttonStyle.fontColor,
              size: widget.pictureUploadWidget.buttonStyle.iconSize),
          const Padding(padding: const EdgeInsets.only(bottom: 5.0)),
          Text(widget.pictureUploadWidget.buttonText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: widget.pictureUploadWidget.buttonStyle.fontColor,
                  fontSize: widget.pictureUploadWidget.buttonStyle.fontSize)),
        ]);

    return new CupertinoButton(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        child: new Container(
            width: widget.pictureUploadWidget.buttonStyle.width,
            height: widget.pictureUploadWidget.buttonStyle.height,
            decoration: BoxDecoration(
                color: widget.pictureUploadWidget.buttonStyle.backgroundColor,
                border: Border.all(
                    color:
                        widget.pictureUploadWidget.buttonStyle.backgroundColor,
                    width: 0.0),
                borderRadius: new BorderRadius.circular(8.0)),
            child: buttonContent),
        onPressed: !widget.pictureUploadWidget.enabled ? null : _uploadImage);
  }

  Widget getExistingImageWidget() {
    final Container existingImageWidget = Container(
        padding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
        child: ClipRRect(
          borderRadius: new BorderRadius.circular(8.0),
          child: _uploadJob.imageProvider != null
              ? Image(
                  image: _uploadJob.imageProvider,
                  width: widget.pictureUploadWidget.buttonStyle.width,
                  height: widget.pictureUploadWidget.buttonStyle.height,
                  fit: BoxFit.fitHeight)
              : _uploadJob.image != null
                  ? Image.file(
                      _uploadJob.image,
                      width: widget.pictureUploadWidget.buttonStyle.width,
                      height: widget.pictureUploadWidget.buttonStyle.height,
                      fit: BoxFit.fitHeight,
                    )
                  : Container(),
        ));

    final Widget processingIndicator = Container(
        width: widget.pictureUploadWidget.buttonStyle.width,
        height: widget.pictureUploadWidget.buttonStyle.height + 10,
        child: const Center(child: const CircularProgressIndicator()));

    final Widget deleteButton = Container(
        width: widget.pictureUploadWidget.buttonStyle.width + 10,
        height: widget.pictureUploadWidget.buttonStyle.height,
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              onTap: !widget.pictureUploadWidget.enabled ? null : _deleteImage,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                      color: CupertinoColors.lightBackgroundGray, width: 1.0),
                ),
                height: 28.0, // height of the button
                width: 28.0, // width of the button
                child: const Icon(Icons.close,
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

      // The filename mist be like custom1_..._custom_x_id_customy.(jpg|png|...)
      final List<String> fileParts = fileName.split('_');
      final String id = fileParts[fileParts.length - 2];
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
