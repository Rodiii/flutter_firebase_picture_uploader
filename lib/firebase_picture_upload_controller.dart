library firebase_picture_uploader;

import 'dart:async';
import 'dart:io';

import 'package:firebase_picture_uploader/firebase_picture_uploader.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:shared_preferences/shared_preferences.dart';

class FirebasePictureUploadController {
  FirebasePictureUploadController() {
    SharedPreferences.getInstance()
        .then((sharedPref) => persistentKeyValueStore = sharedPref);
  }

  SharedPreferences persistentKeyValueStore;

  Future<String> receiveURL(String storageURL, {bool useCaching = true}) async {
    // try getting the download link from persistency
    if (useCaching) {
      try {
        persistentKeyValueStore ??= await SharedPreferences.getInstance();
        return persistentKeyValueStore.getString(storageURL);
      } on Exception catch (error, stackTrace) {
        print(error);
        print(stackTrace);
      }
    }

    // if downloadLink is null get it from the storage
    try {
      final String downloadLink = await FirebaseStorage.instance
          .ref()
          .child(storageURL)
          .getDownloadURL();

      // cache link
      if (useCaching) {
        await persistentKeyValueStore.setString(storageURL, downloadLink);
      }

      // give url to caller
      return downloadLink;
    } on Exception catch (error, stackTrace) {
      print(error);
      print(stackTrace);
    }
    return null;
  }

  Future<File> cropImage(
      File imageFile, ImageManipulationSettings cropSettings) async {
    final File croppedFile = await ImageCropper.cropImage(
      sourcePath: imageFile.path,
      aspectRatio: cropSettings.aspectRatio,
      maxWidth: cropSettings.maxWidth,
      maxHeight: cropSettings.maxHeight,
    );
    return croppedFile;
  }

  Future<StorageReference> uploadProfilePicture(
      File image,
      String uploadDirectory,
      int id,
      Function imagePostProcessingFuction) async {
    final String uploadPath = uploadDirectory + id.toString() + '_800.jpg';
    final StorageReference imgRef =
        FirebaseStorage.instance.ref().child(uploadPath);

    // start upload
    final StorageUploadTask uploadTask =
        imgRef.putFile(image, new StorageMetadata(contentType: 'image/jpg'));

    // wait until upload is complete
    StorageTaskSnapshot snapShot = await uploadTask.onComplete;
    if (snapShot.error != null)
      throw Exception("Upload failed, Firebase Error Code: ${snapShot.error}");

    return imgRef;
  }

  Future<void> deleteProfilePicture(StorageReference oldUpload) async {
    // ask backend to transform images
    await oldUpload.delete();
  }
}
