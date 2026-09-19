import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

/// A single simulated CCTV feed: which physical asset backs it and how
/// it should be labelled on the responder's monitor wall.
class _CctvCamera {
  const _CctvCamera({required this.number, required this.location, required this.assetPath});

  final String number;
  final String location;
  final String assetPath;
}

/// Camera → location → asset mapping for the four simulated demo feeds
/// shipped under assets/icon/cctv/ (mixed .jpg/.webp, one with an
/// uppercase .JPG extension — paths below match the files on disk
/// exactly, since asset lookups are case-sensitive on Android/iOS).
const _cctvCameras = [
  _CctvCamera(
    number: '01',
    location: 'Missionvale',
    assetPath: 'assets/icon/cctv/Missionvale.JPG',
  ),
  _CctvCamera(
    number: '02',
    location: 'Sports Field',
    assetPath: 'assets/icon/cctv/Field.jpg',
  ),
  _CctvCamera(
    number: '03',
    location: 'Library North Campus',
    assetPath: 'assets/icon/cctv/North.webp',
  ),
  _CctvCamera(
    number: '04',
    location: 'Letaba Residence',
    assetPath: 'assets/icon/cctv/Residence.webp',
  ),
];

/// Dashboard entry point: a labelled card (matching the admin overview's
/// stat-card style) that a responder taps to open the CCTV Monitor.
class CctvMonitorEntryCard extends StatelessWidget {
  const CctvMonitorEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CctvMonitorScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.seed.withValues(alpha: 0.15),
              child: const Icon(Icons.videocam_outlined, color: AppColors.seed),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CCTV Monitor', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'View simulated campus camera feeds',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// CCTV Monitor: a 2x2 grid of simulated campus camera feeds for the
/// responder side. Prototype only — no real streaming/RTSP/WebRTC or
/// university CCTV integration; every feed is a static demo image
/// clearly labelled SIMULATED FEED.
class CctvMonitorScreen extends StatefulWidget {
  const CctvMonitorScreen({super.key});

  @override
  State<CctvMonitorScreen> createState() => _CctvMonitorScreenState();
}

class _CctvMonitorScreenState extends State<CctvMonitorScreen> {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat('HH:mm:ss').format(_now);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('CCTV Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simulated demonstration feeds for prototype purposes only — '
              'not live university CCTV streams.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 420 ? 1 : 2;
                  return GridView.builder(
                    itemCount: _cctvCameras.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: crossAxisCount == 1 ? 1.6 : 1.05,
                    ),
                    itemBuilder: (context, index) {
                      final camera = _cctvCameras[index];
                      return _CameraTile(camera: camera, timestamp: timestamp);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.camera, required this.timestamp});

  final _CctvCamera camera;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _CameraFullScreenViewer(camera: camera)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _CameraFeed(camera: camera, timestamp: timestamp),
      ),
    );
  }
}

/// Full-screen version of a tile, opened when a responder taps a camera
/// to get a closer look at its simulated feed.
class _CameraFullScreenViewer extends StatefulWidget {
  const _CameraFullScreenViewer({required this.camera});

  final _CctvCamera camera;

  @override
  State<_CameraFullScreenViewer> createState() => _CameraFullScreenViewerState();
}

class _CameraFullScreenViewerState extends State<_CameraFullScreenViewer> {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Camera ${widget.camera.number} — ${widget.camera.location}'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _CameraFeed(
                camera: widget.camera,
                timestamp: DateFormat('HH:mm:ss').format(_now),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared feed rendering: the simulated background image plus the
/// LIVE / camera-number / location / timestamp / SIMULATED FEED overlay,
/// used by both the grid tile and the full-screen viewer.
class _CameraFeed extends StatelessWidget {
  const _CameraFeed({required this.camera, required this.timestamp});

  final _CctvCamera camera;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(camera.assetPath, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.safe, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 10,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'SIMULATED FEED',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CAM ${camera.number}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                camera.location.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timestamp,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
