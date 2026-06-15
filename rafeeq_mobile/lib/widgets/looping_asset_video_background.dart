import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Bundled hospital clip used as a looping background across landing/auth screens.
const String kHospitalBackgroundVideoAsset = 'assets/videos/hospital.mp4';

typedef LoopingVideoErrorBuilder = Widget Function(
  BuildContext context,
  Object? initError,
  String? playerError,
);

/// Full-bleed looping asset video with correct init, error handling, and dispose.
class LoopingAssetVideoBackground extends StatefulWidget {
  const LoopingAssetVideoBackground({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.cover,
    this.muted = true,
    this.backgroundColor = Colors.black,
    this.loading,
    this.errorBuilder,
  });

  final String assetPath;
  final BoxFit fit;
  final bool muted;
  final Color backgroundColor;
  final Widget? loading;
  final LoopingVideoErrorBuilder? errorBuilder;

  @override
  State<LoopingAssetVideoBackground> createState() =>
      _LoopingAssetVideoBackgroundState();
}

class _LoopingAssetVideoBackgroundState
    extends State<LoopingAssetVideoBackground> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initFuture = _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(
      widget.assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      if (widget.muted) {
        await controller.setVolume(0);
      }

      controller.addListener(_onControllerUpdate);
      await controller.play();

      if (!mounted) {
        controller.removeListener(_onControllerUpdate);
        await controller.dispose();
        return;
      }

      _controller = controller;
      setState(() {});
    } catch (e, stack) {
      await controller.dispose();
      _initError = e;
      if (mounted) {
        setState(() {});
      }
      Error.throwWithStackTrace(e, stack);
    }
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller != null && controller.value.hasError && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.removeListener(_onControllerUpdate);
    controller?.dispose();
    super.dispose();
  }

  Widget _buildVideo(VideoPlayerController controller) {
    return SizedBox.expand(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return ColoredBox(
      color: widget.backgroundColor,
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (controller != null &&
              controller.value.isInitialized &&
              !controller.value.hasError) {
            return _buildVideo(controller);
          }

          final playerError = controller?.value.hasError == true
              ? controller!.value.errorDescription
              : null;
          final initFailed = snapshot.hasError || _initError != null;

          if (initFailed || playerError != null) {
            return widget.errorBuilder?.call(
                  context,
                  _initError ?? snapshot.error,
                  playerError,
                ) ??
                const SizedBox.shrink();
          }

          return widget.loading ??
              const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
