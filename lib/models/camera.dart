/// An IP camera connected to the CVAI device.
class CameraModel {
  const CameraModel({
    required this.id,
    required this.name,
    required this.location,
    required this.rtspUrl,
    required this.online,
    this.resolution = '1080p',
    this.frameRate = 15,
    this.username,
    this.password,
    this.enabled = true,
    this.detectedFaces = 0,
    this.fps = 0,
  });

  final String id;
  final String name;
  final String location;
  final String rtspUrl;
  final bool online;
  final String resolution;
  final int frameRate;
  final String? username;
  final String? password;
  final bool enabled;
  final int detectedFaces;
  final int fps;
}
