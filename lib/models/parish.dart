class Parish {
  final String name;
  final String address;
  final String city;
  final String zipCode;
  final List<String> massTimes;
  final String? contactInfo;
  final double? latitude;
  final double? longitude;

  Parish({
    required this.name,
    required this.address,
    required this.city,
    required this.zipCode,
    required this.massTimes,
    this.contactInfo,
    this.latitude,
    this.longitude,
  });

  factory Parish.fromJson(Map<String, dynamic> json) {
    // Handle zipCode as either int or String
    String zipCodeString;
    if (json['zip_code'] != null) {
      zipCodeString = json['zip_code'].toString();
    } else {
      zipCodeString = '';
    }

    return Parish(
      name: json['name'] ?? 'Unknown',
      address: json['address'] ?? 'No address provided',
      city: json['city'] ?? 'Unknown city',
      zipCode: zipCodeString,
      massTimes: json['mass_times'] != null
          ? List<String>.from(json['mass_times'])
          : [],
      contactInfo: json['contact_info'],
      latitude: json['latitude'] != null
          ? json['latitude'].toDouble()
          : null,
      longitude: json['longitude'] != null
          ? json['longitude'].toDouble()
          : null,
    );
  }
}
