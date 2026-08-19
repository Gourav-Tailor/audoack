class Device {
  final String id;
  final String name;

  Device({
    required this.id,
    required this.name,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unnamed Device',
    );
  }
}
