import 'dart:ui' as ui;

import 'package:aves_video/aves_video.dart';

// Minimal fallback metadata fetcher for the ExoPlayer route.
//
// Video thumbnails in Aves are primarily produced by the platform (Android
// MediaStore) in `media_fetch_service`; this fetcher is only the secondary
// path for media without a platform thumbnail. Returning null / defaults here
// keeps the app running on the ExoPlayer engine while we validate the switch;
// a full ExoPlayer-based implementation (native frame extraction + slow-motion
// detection) can replace this later if needed.
class ExoVideoMetadataFetcher extends AvesVideoMetadataFetcher {
  @override
  void init() {}

  @override
  Future<Map<String, Object?>> getMetadata({required String uri, required String mimeType}) async => {};

  @override
  Future<(int, int?)> computeSlowMotionFactorAndDuration({required String uri, required String mimeType}) async => (1, null);

  @override
  Future<ui.ImageDescriptor?> getThumbnailDescriptor({required String uri, required String mimeType, required double targetExtentDip}) async => null;
}
