import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
void test(MapController c, LatLng p1, LatLng p2) {
  c.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([p1, p2]), padding: const EdgeInsets.all(50)));
}
