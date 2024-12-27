class Parish {
  final String name;
  final String address;
  final String city;
  final String zipCode;
  final String phone;
  final String website;
  final List<String> massTimes;
  final String? contactInfo;
  final double? latitude;
  final double? longitude;

  Parish({
    required this.name,
    required this.address,
    required this.city,
    required this.zipCode,
    required this.phone,
    required this.website,
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
      //Phone and website
      phone: json['phone'] ?? 'No Phone Listed',
      website: json['www'] ?? 'No Website',
      contactInfo: json['contact_info'] ?? 'See parish website',
      massTimes: json['mass_times'] != null
          ? List<String>.from(json['mass_times'])
          : [],
      latitude: json['latitude'] != null
          ? json['latitude'].toDouble()
          : null,
      longitude: json['longitude'] != null
          ? json['longitude'].toDouble()
          : null,
    );
  }
}
