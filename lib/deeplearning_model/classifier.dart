import 'package:flutter/widgets.dart';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;
import 'dart:io' as io;
import 'package:image/image.dart' as img;

class Classifier {
  Classifier();
  classifyImage(PickedFile image) async {
    var _file = io.File(image.path);
    img.Image imageTemp = img.decodeImage(_file.readAsBytesSync());
    img.Image resizedImg = img.copyResize(imageTemp, height: 40, width: 40);
    var imgBytes = resizedImg.getBytes();
    var imgAsList = imgBytes.buffer.asUint8List();

    return getPred(imgAsList);
  }

  classifyDrawing(List<Offset> points) async {
    final picture = toPicture(points);
    final image = await picture.toImage(40, 40);
    ByteData imgBytes = await image.toByteData();
    var imgAsList = imgBytes.buffer.asUint8List();

    // Everything "important" is done in getPred
    return getPred(imgAsList);
  }

  Future<int> getPred(Uint8List imgAsList) async {
    final resultBytes = List(40 * 40);

    int index = 0;
    for (int i = 0; i < imgAsList.lengthInBytes; i += 4) {
      final r = imgAsList[i];
      final g = imgAsList[i + 1];
      final b = imgAsList[i + 2];

      resultBytes[index] = ((r + g + b) / 3.0) / 255.0;
      index++;
    }

    var input = resultBytes.reshape([1, 28, 28, 1]);
    var output = List(1 * 10).reshape([1, 10]);

    InterpreterOptions interpreterOptions = InterpreterOptions();

    int startTime = new DateTime.now().millisecondsSinceEpoch;

    try {
      Interpreter interpreter = await Interpreter.fromAsset("model.tflite",
          options: interpreterOptions);
      interpreter.run(input, output);
    } catch (e) {
      print('Error loading or running model: ' + e.toString());
    }

    int endTime = new DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime} ms");

    double highestProb = 0;
    int digitPred;

    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > highestProb) {
        highestProb = output[0][i];
        digitPred = i;
      }
    }
    return digitPred;
  }
}

ui.Picture toPicture(List<Offset> points) {
  final _whitePaint = Paint()
    ..strokeCap = StrokeCap.round
    ..color = Colors.white
    ..strokeWidth = 20;

  final _bgPaint = Paint()..color = Colors.black;
  final _canvasCullRect =
      Rect.fromPoints(Offset(0, 0), Offset(40.toDouble(), 40.toDouble()));
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, _canvasCullRect)..scale(40 / 20);

  canvas.drawRect(Rect.fromLTWH(0, 0, 28, 28), _bgPaint);

  for (int i = 0; i < points.length - 1; i++) {
    if (points[i] != null && points[i + 1] != null) {
      canvas.drawLine(points[i], points[i + 1], _whitePaint);
    }
  }

  return recorder.endRecording();
}
