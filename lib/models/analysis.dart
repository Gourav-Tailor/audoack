class Analysis {
  final int? id;
  final int? batchId;
  final String? filename;
  final String status;
  final DateTime? createdAt;

  final String? emotionalTone;
  final String? emotionalIntensity;
  final bool backgroundNoisePresent;
  final String? backgroundNoiseType;
  final String? backgroundNoiseSeverity;
  final String? audioQuality;
  final bool speakerOverlapPresent;
  final bool longSilencePresent;
  final double? confidence;

  Analysis({
    this.id,
    this.batchId,
    this.filename,
    required this.status,
    this.createdAt,
    this.emotionalTone,
    this.emotionalIntensity,
    this.backgroundNoisePresent = false,
    this.backgroundNoiseType,
    this.backgroundNoiseSeverity,
    this.audioQuality,
    this.speakerOverlapPresent = false,
    this.longSilencePresent = false,
    this.confidence,
  });

  factory Analysis.fromJson(Map<String, dynamic> json) {
    return Analysis(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      batchId: json['batch_id'] is int ? json['batch_id'] : int.tryParse(json['batch_id']?.toString() ?? ''),
      filename: json['filename']?.toString(),
      status: json['status']?.toString() ?? 'unknown',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      emotionalTone: json['emotional_tone']?.toString(),
      emotionalIntensity: json['emotional_intensity']?.toString(),
      backgroundNoisePresent: json['background_noise_present'] == true,
      backgroundNoiseType: json['background_noise_type']?.toString(),
      backgroundNoiseSeverity: json['background_noise_severity']?.toString(),
      audioQuality: json['audio_quality']?.toString(),
      speakerOverlapPresent: json['speaker_overlap_present'] == true,
      longSilencePresent: json['long_silence_present'] == true,
      confidence: json['confidence'] != null ? double.tryParse(json['confidence'].toString()) : null,
    );
  }
}
