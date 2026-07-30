import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderService {
  AudioRecorderService._();
  static final AudioRecorder _recorder = AudioRecorder();

  static Future<bool> tienPermiso() async {
    return await _recorder.hasPermission();
  }

  static Future<String?> iniciarGrabacion() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/nota_voz_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );
    return path;
  }

  static Future<String?> detenerGrabacion() async {
    return await _recorder.stop();
  }

  static Future<void> cancelarGrabacion() async {
    await _recorder.cancel();
  }

  static Future<bool> estaGrabando() async {
    return await _recorder.isRecording();
  }

  static void dispose() {
    _recorder.dispose();
  }
}
