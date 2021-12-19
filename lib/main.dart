import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:async/async.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Система распознавания эмоций пользователя.',
      home: MyHomePage(title: 'Система распознавания эмоций.'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  XFile? _imageFile;
  String? _imageUrl;

  dynamic _pickImageError;
  String? _retrieveDataError;

  final ImagePicker _picker = ImagePicker();

  bool _detectError = false;

  void _onImageButtonPressed(ImageSource source,
      {BuildContext? context}) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      setState(() {
        _imageFile = pickedFile;
        _detectError = false;
      });
    } catch (e) {
      setState(() {
        _pickImageError = e;
      });
    }
  }

  Widget _previewImages(BuildContext context) {
    final Text? retrieveError = _getRetrieveErrorWidget();
    if (retrieveError != null) {
      return retrieveError;
    }
    if (_detectError) {
      return Text("Не удается определить лицо на изображении.",
          style: TextStyle(color: Colors.red));
    }
    if (_imageUrl != null) {
      return Semantics(
        label: 'image_picker_example_picked_image',
        child: Image.network(_imageUrl!,
            width: (MediaQuery.of(context).size.width * 80) / 100),
      );
    }
    if (_imageFile != null) {
      return Semantics(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Semantics(
                  label: 'image_picker_example_picked_image',
                  child: kIsWeb
                      ? Image.network(_imageFile!.path,
                          width: (MediaQuery.of(context).size.width * 80) / 100)
                      : Image.file(File(_imageFile!.path),
                          width:
                              (MediaQuery.of(context).size.width * 80) / 100),
                ),
                Padding(
                    padding: EdgeInsets.all(20),
                    child: ElevatedButton(
                        child: Text('Получить результат'),
                        onPressed: () async {
                          var imageFile = File(_imageFile!.path);
                          var stream = new http.ByteStream(
                              DelegatingStream.typed(imageFile.openRead()));
                          var length = await imageFile.length();

                          var uri = Uri.parse("http://10.0.2.2:8000/uploads");
                          var request = new http.MultipartRequest("POST", uri);

                          var multipartFile = new http.MultipartFile(
                              'image', stream, length,
                              filename: basename(imageFile.path));

                          request.files.add(multipartFile);

                          var response = await request.send();
                          if (response.statusCode != 200)
                            setState(() => _detectError = true);

                          response.stream
                              .transform(utf8.decoder)
                              .listen((value) async {
                            var imageName = json.decode(value)["image_name"];
                            setState(() => _imageUrl =
                                "http://10.0.2.2:8000/images/detected/download/$imageName");
                          });
                        }))
              ]),
          label: 'image_picker_example_picked_images');
    } else if (_pickImageError != null) {
      return Text(
        'Ошибка выбора изображения: $_pickImageError',
        textAlign: TextAlign.center,
      );
    } else {
      return const Text(
        'Вы еще не выбрали изображение.',
        textAlign: TextAlign.center,
      );
    }
  }

  Future<void> retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      return;
    }
    if (response.file != null) {
      setState(() {
        _imageFile = response.file;
      });
    } else {
      _retrieveDataError = response.exception!.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: Center(
        child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? FutureBuilder<void>(
                future: retrieveLostData(),
                builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return const Text(
                        'Пожалуйста, выберите свое изображение из галереи или возьмите новое.',
                        textAlign: TextAlign.center,
                      );
                    case ConnectionState.done:
                      return _previewImages(context);
                    default:
                      if (snapshot.hasError) {
                        return Text(
                          'Ошибка выбора изображения: ${snapshot.error}}',
                          textAlign: TextAlign.center,
                        );
                      } else {
                        return const Text(
                          'Вы еще не выбрали изображение.',
                          textAlign: TextAlign.center,
                        );
                      }
                  }
                },
              )
            : _previewImages(context),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Semantics(
            label: 'image_picker_example_from_gallery',
            child: FloatingActionButton(
              onPressed: () {
                _onImageButtonPressed(ImageSource.gallery, context: context);
              },
              heroTag: 'image0',
              tooltip: 'Выбрать изображение из галереи',
              child: const Icon(Icons.photo),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: () {
                _onImageButtonPressed(ImageSource.camera, context: context);
              },
              heroTag: 'image2',
              tooltip: 'Сфотографировать',
              child: const Icon(Icons.camera_alt),
            ),
          ),
        ],
      ),
    );
  }

  Text? _getRetrieveErrorWidget() {
    if (_retrieveDataError != null) {
      final Text result = Text(_retrieveDataError!);
      _retrieveDataError = null;
      return result;
    }
    return null;
  }
}
