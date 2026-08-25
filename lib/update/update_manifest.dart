class UpdateManifest {
  final String version;
  final int versionCode;
  final int minimumSupportedVersionCode;
  final Uri apkUrl;
  final String sha256;
  final int? apkSize;
  final String title;
  final String message;
  final List<String> changelog;
  final DateTime? publishedAt;

  const UpdateManifest({
    required this.version,
    required this.versionCode,
    required this.minimumSupportedVersionCode,
    required this.apkUrl,
    required this.sha256,
    required this.apkSize,
    required this.title,
    required this.message,
    required this.changelog,
    required this.publishedAt,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException("Update manifest field '$key' is invalid.");
      }
      return value.trim();
    }

    int requiredInt(String key) {
      final value = json[key];
      final parsed = value is int
          ? value
          : int.tryParse(value?.toString() ?? '');
      if (parsed == null) {
        throw FormatException("Update manifest field '$key' is invalid.");
      }
      return parsed;
    }

    final version = requiredString('version');
    final versionCode = requiredInt('versionCode');
    final minimumCode = requiredInt('minimumSupportedVersionCode');
    final apkUrl = Uri.tryParse(requiredString('apkUrl'));
    final hash = requiredString('sha256').toLowerCase();
    final rawSize = json['apkSize'];
    final apkSize = rawSize == null
        ? null
        : (rawSize is int ? rawSize : int.tryParse(rawSize.toString()));
    final rawChangelog = json['changelog'];
    final published = json['publishedAt']?.toString().trim();

    if (versionCode <= 0) {
      throw const FormatException('versionCode must be greater than zero.');
    }
    if (minimumCode < 0 || minimumCode > versionCode) {
      throw const FormatException(
        'minimumSupportedVersionCode must be between zero and versionCode.',
      );
    }
    if (apkUrl == null || apkUrl.scheme != 'https' || apkUrl.host.isEmpty) {
      throw const FormatException('apkUrl must be a valid HTTPS URL.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('sha256 must be a 64-character hex digest.');
    }
    if (apkSize != null && apkSize <= 0) {
      throw const FormatException('apkSize must be greater than zero.');
    }
    if (json['mandatory'] != true) {
      throw const FormatException(
        'Luffy TV accepts compulsory update manifests only.',
      );
    }

    return UpdateManifest(
      version: version,
      versionCode: versionCode,
      minimumSupportedVersionCode: minimumCode,
      apkUrl: apkUrl,
      sha256: hash,
      apkSize: apkSize,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Luffy TV needs an update',
      message: (json['message'] as String?)?.trim().isNotEmpty == true
          ? (json['message'] as String).trim()
          : 'Install the latest release to continue streaming.',
      changelog: rawChangelog is List
          ? rawChangelog
                .whereType<String>()
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .take(20)
                .toList(growable: false)
          : const [],
      publishedAt: published == null || published.isEmpty
          ? null
          : DateTime.tryParse(published)?.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'versionCode': versionCode,
    'minimumSupportedVersionCode': minimumSupportedVersionCode,
    'apkUrl': apkUrl.toString(),
    'sha256': sha256,
    if (apkSize != null) 'apkSize': apkSize,
    'mandatory': true,
    'title': title,
    'message': message,
    'changelog': changelog,
    if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
  };
}
