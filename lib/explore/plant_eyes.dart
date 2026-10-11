import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

/// One candidate species with its similarity score.
class PlantGuess {
  PlantGuess(this.id, this.score);

  final String id;
  final double score;
}

class PlantResult {
  PlantResult(this.guesses);

  /// Best first.
  final List<PlantGuess> guesses;

  /// How far the best answer is ahead of the second one.
  double get margin =>
      guesses.length < 2 ? 1 : guesses[0].score - guesses[1].score;

  /// Measured on 106 iNaturalist photos from Argentina, through this exact
  /// Dart code: with a margin of at least 0.05 the first answer was right 40
  /// times out of 42. Below it, the child chooses among the top three.
  bool get confident => margin >= 0.05;
}

/// BioCLIP 2.5 Mobile: a 24 MB open model (MIT) that turns a photo into a
/// point in BioCLIP's space of species. We compare it only with the plants
/// that grow in Buenos Aires: the place narrows the choice.
class PlantEyes {
  PlantEyes._(this._session, this._ids, this._table);

  final OrtSession _session;
  final List<String> _ids;

  /// Row-major [ids.length × 1024], L2-normalized text embeddings.
  final Float32List _table;
  static const _dim = 1024;

  static Future<PlantEyes> load() async {
    final session = await OnnxRuntime().createSessionFromAsset(
      'assets/plants/bioclip_mobile_fp16.onnx',
    );
    final ids = (await rootBundle.loadString('assets/plants/table_ids.txt'))
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final bytes = await rootBundle.load('assets/plants/table_f32.bin');
    final table = bytes.buffer.asFloat32List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 4,
    );
    assert(table.length == ids.length * _dim);
    return PlantEyes._(session, ids, table);
  }

  Future<PlantResult> identify(String photoPath) async {
    final input = await compute(_preprocess, photoPath);
    final tensor = await OrtValue.fromList(input, [1, 3, 224, 224]);
    final out = await _session.run({_session.inputNames.first: tensor});
    final emb = (await out.values.first.asFlattenedList()).cast<num>();
    await tensor.dispose();
    for (final v in out.values) {
      await v.dispose();
    }

    var norm = 0.0;
    for (final v in emb) {
      norm += v * v;
    }
    norm = sqrt(norm);
    // A plant can have several rows (alternative scientific names): keep
    // its best one.
    final best = <String, double>{};
    for (var r = 0; r < _ids.length; r++) {
      var dot = 0.0;
      for (var c = 0; c < _dim; c++) {
        dot += _table[r * _dim + c] * emb[c];
      }
      final score = dot / norm;
      if (score > (best[_ids[r]] ?? -2)) best[_ids[r]] = score;
    }
    final scores = [for (final e in best.entries) PlantGuess(e.key, e.value)];
    scores.sort((a, b) => b.score.compareTo(a.score));
    return PlantResult(scores.take(3).toList());
  }
}

/// Center square crop, 224×224 area-averaged, RGB 0..1, NCHW. The model folds its
/// own mean/std normalization into the graph.
Float32List _preprocess(String path) {
  var image = img.decodeImage(File(path).readAsBytesSync())!;
  image = img.bakeOrientation(image);
  final side = min(image.width, image.height);
  image = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );
  // Approximates PIL's antialiased bicubic (used to build and evaluate the
  // model): average down to twice the size, then bicubic to 224.
  if (image.width > 448) {
    image = img.copyResize(
      image,
      width: 448,
      height: 448,
      interpolation: img.Interpolation.average,
    );
  }
  image = img.copyResize(
    image,
    width: 224,
    height: 224,
    interpolation: img.Interpolation.cubic,
  );
  final out = Float32List(3 * 224 * 224);
  const plane = 224 * 224;
  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final p = image.getPixel(x, y);
      final i = y * 224 + x;
      out[i] = p.r / 255.0;
      out[plane + i] = p.g / 255.0;
      out[2 * plane + i] = p.b / 255.0;
    }
  }
  return out;
}
