class AddressModel {
  const AddressModel({
    required this.id,
    required this.address1,
    required this.city,
    this.alias,
    this.firstname,
    this.lastname,
    this.company,
    this.address2,
    this.postcode,
    this.country,
    this.countryId,
    this.stateId,
    this.phone,
    this.phoneMobile,
  });

  final int id;
  final String? alias;
  final String? firstname;
  final String? lastname;
  final String? company;
  final String address1;
  final String? address2;
  final String? postcode;
  final String city;
  final String? country;
  final int? countryId;
  final int? stateId;
  final String? phone;
  final String? phoneMobile;

  String get fullName {
    return [firstname, lastname]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: (json['id'] as num).toInt(),
      alias: json['alias']?.toString(),
      firstname: json['firstname']?.toString(),
      lastname: json['lastname']?.toString(),
      company: json['company']?.toString(),
      address1: (json['address1'] ?? '').toString(),
      address2: json['address2']?.toString(),
      postcode: json['postcode']?.toString(),
      city: (json['city'] ?? '').toString(),
      country: json['country']?.toString(),
      countryId: (json['country_id'] as num?)?.toInt(),
      stateId: (json['state_id'] as num?)?.toInt(),
      phone: json['phone']?.toString(),
      phoneMobile: json['phone_mobile']?.toString(),
    );
  }
}
