import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Catatan: Fungsi main() dihapus agar tidak bentrok dengan main.dart utama proyek.

class KameraPage extends StatefulWidget {
  const KameraPage({super.key});

  @override
  State<KameraPage> createState() => _KameraPageState();
}

class _KameraPageState extends State<KameraPage> {
  Interpreter? _interpreter;

  File? _image;

  List<Detection> detections = [];

  List<String> labels = [];

  // ============================================================
  // MODEL CONFIGURATION
  // ============================================================

  static const int inputSize = 640;

  // Sesuai graph:
  // 3 class + 4 bbox = 7
  static const int numClasses = 3;

  // Jumlah candidate:
  // 80x80 + 40x40 + 20x20
  // = 6400 + 1600 + 400
  // = 8400
  static const int numCandidates = 8400;

  static const double confThreshold = 0.40;
  static const double iouThreshold = 0.50;

  int originalWidth = 0;
  int originalHeight = 0;

  @override
  void initState() {
    super.initState();

    loadModel();
    loadLabels();
  }

  // ============================================================
  // LOAD MODEL
  // ============================================================

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/best.tflite',
      );

      debugPrint("=================================");
      debugPrint("MODEL LOADED");
      debugPrint("Input : ${_interpreter!.getInputTensor(0).shape}");
      debugPrint("Output: ${_interpreter!.getOutputTensor(0).shape}");
      debugPrint("=================================");
    } catch (e) {
      debugPrint("ERROR LOAD MODEL: $e");
    }
  }

  // ============================================================
  // LOAD LABELS
  // ============================================================

  Future<void> loadLabels() async {
    try {
      final data = await DefaultAssetBundle.of(context)
          .loadString("assets/labels.txt");

      labels = data
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      debugPrint("Labels: $labels");
    } catch (e) {
      debugPrint("ERROR LOAD LABELS: $e");
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();

    final XFile? picked = await picker.pickImage(
      source: source,
    );

    if (picked == null) return;

    final file = File(picked.path);

    final bytes = await file.readAsBytes();

    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      debugPrint("Gagal decode image");
      return;
    }

    originalWidth = decoded.width;
    originalHeight = decoded.height;

    setState(() {
      _image = file;
      detections = [];
    });

    await runModel(file);
  }

  // ============================================================
  // PREPROCESS
  // ============================================================

  Float32List preprocess(File imageFile) {
    final bytes = imageFile.readAsBytesSync();

    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception("Tidak dapat membaca gambar");
    }

    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    final input = Float32List(
      1 * inputSize * inputSize * 3,
    );

    int index = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);

        input[index++] = pixel.r / 255.0;
        input[index++] = pixel.g / 255.0;
        input[index++] = pixel.b / 255.0;
      }
    }

    return input;
  }

  // ============================================================
  // RUN MODEL
  // ============================================================

  Future<void> runModel(File imageFile) async {
    if (_interpreter == null) {
      debugPrint("Interpreter belum siap");
      return;
    }

    final input = preprocess(imageFile);

    final output = List.generate(
      1,
      (_) => List.generate(
        7,
        (_) => List<double>.filled(
          numCandidates,
          0.0,
        ),
      ),
    );

    _interpreter!.run(
      input.reshape([
        1,
        inputSize,
        inputSize,
        3,
      ]),
      output,
    );

    final List<Detection> results = [];

    for (int i = 0; i < numCandidates; i++) {
      double x = output[0][0][i];
      double y = output[0][1][i];
      double w = output[0][2][i];
      double h = output[0][3][i];

      double maxScore = 0.0;
      int classIndex = -1;

      for (int c = 0; c < numClasses; c++) {
        final score = output[0][4 + c][i];

        if (score > maxScore) {
          maxScore = score;
          classIndex = c;
        }
      }

      if (maxScore < confThreshold) {
        continue;
      }

      if (classIndex < 0) {
        continue;
      }

      if (x.abs() <= 1.5 &&
          y.abs() <= 1.5 &&
          w.abs() <= 1.5 &&
          h.abs() <= 1.5) {
        x *= originalWidth;
        y *= originalHeight;
        w *= originalWidth;
        h *= originalHeight;
      } else {
        x *= originalWidth / inputSize;
        y *= originalHeight / inputSize;
        w *= originalWidth / inputSize;
        h *= originalHeight / inputSize;
      }

      w = max(0, w);
      h = max(0, h);

      if (w <= 1 || h <= 1) {
        continue;
      }

      results.add(
        Detection(
          x: x,
          y: y,
          w: w,
          h: h,
          confidence: maxScore,
          classIndex: classIndex,
        ),
      );
    }

    final finalDetections = nonMaxSuppression(results);

    if (!mounted) return;

    setState(() {
      detections = finalDetections;
    });
  }

  // ============================================================
  // NMS
  // ============================================================

  List<Detection> nonMaxSuppression(
    List<Detection> boxes,
  ) {
    if (boxes.isEmpty) {
      return [];
    }

    boxes.sort(
      (a, b) => b.confidence.compareTo(a.confidence),
    );

    final List<Detection> selected = [];

    for (final box in boxes) {
      bool keep = true;

      for (final existing in selected) {
        if (box.classIndex != existing.classIndex) {
          continue;
        }

        if (iou(box, existing) > iouThreshold) {
          keep = false;
          break;
        }
      }

      if (keep) {
        selected.add(box);
      }
    }

    return selected;
  }

  // ============================================================
  // IOU
  // ============================================================

  double iou(
    Detection a,
    Detection b,
  ) {
    final double x1 = max(
      a.left,
      b.left,
    );

    final double y1 = max(
      a.top,
      b.top,
    );

    final double x2 = min(
      a.right,
      b.right,
    );

    final double y2 = min(
      a.bottom,
      b.bottom,
    );

    final double intersectionWidth =
        max(0.0, x2 - x1);

    final double intersectionHeight =
        max(0.0, y2 - y1);

    final double intersection =
        intersectionWidth * intersectionHeight;

    final double union =
        a.area + b.area - intersection;

    if (union <= 0) {
      return 0.0;
    }

    return intersection / union;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Tanpa MaterialApp, langsung mengembalikan Scaffold agar aman dalam BottomNavigationBar
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "YOLOv11 Detection",
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    pickImage(
                      ImageSource.gallery,
                    );
                  },
                  child: const Text(
                    "Gallery",
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    pickImage(
                      ImageSource.camera,
                    );
                  },
                  child: const Text(
                    "Camera",
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _image == null
                ? const Center(
                    child: Text(
                      "No Image",
                    ),
                  )
                : LayoutBuilder(
                    builder: (
                      context,
                      constraints,
                    ) {
                      final double widgetWidth =
                          constraints.maxWidth;

                      final double widgetHeight =
                          constraints.maxHeight;

                      final double imageAspect =
                          originalWidth /
                              originalHeight;

                      final double widgetAspect =
                          widgetWidth /
                              widgetHeight;

                      double displayWidth;
                      double displayHeight;

                      double offsetX = 0;
                      double offsetY = 0;

                      if (imageAspect >
                          widgetAspect) {
                        displayWidth =
                            widgetWidth;

                        displayHeight =
                            widgetWidth /
                                imageAspect;

                        offsetY =
                            (widgetHeight -
                                    displayHeight) /
                                2;
                      } else {
                        displayHeight =
                            widgetHeight;

                        displayWidth =
                            widgetHeight *
                                imageAspect;

                        offsetX =
                            (widgetWidth -
                                    displayWidth) /
                                2;
                      }

                      final double scaleX =
                          displayWidth /
                              originalWidth;

                      final double scaleY =
                          displayHeight /
                              originalHeight;

                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            width: widgetWidth,
                            height: widgetHeight,
                            child: Image.file(
                              _image!,
                              fit: BoxFit.contain,
                            ),
                          ),
                          ...detections.map(
                            (d) {
                              final String label =
                                  d.classIndex <
                                          labels.length
                                      ? labels[
                                          d.classIndex]
                                      : "class_${d.classIndex}";

                              return Positioned(
                                left: d.left *
                                        scaleX +
                                    offsetX,
                                top: d.top *
                                        scaleY +
                                    offsetY,
                                width: d.w *
                                    scaleX,
                                height: d.h *
                                    scaleY,
                                child: Container(
                                  decoration:
                                      BoxDecoration(
                                    border:
                                        Border.all(
                                      color:
                                          Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  child: Align(
                                    alignment:
                                        Alignment
                                            .topLeft,
                                    child:
                                        Container(
                                      color:
                                          Colors.red,
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        "$label "
                                        "${(d.confidence * 100).toStringAsFixed(1)}%",
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white,
                                          fontSize:
                                              12,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// DETECTION
// ================================================================

class Detection {
  final double x;
  final double y;
  final double w;
  final double h;

  final double confidence;

  final int classIndex;

  Detection({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.confidence,
    required this.classIndex,
  });

  double get left =>
      x - (w / 2);

  double get top =>
      y - (h / 2);

  double get right =>
      x + (w / 2);

  double get bottom =>
      y + (h / 2);

  double get area =>
      max(0, w) * max(0, h);
}