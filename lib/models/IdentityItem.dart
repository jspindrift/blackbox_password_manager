import 'dart:convert';

///TODO: add this item in
class IdentityItem {
  String id;
  String firstName;
  String lastName;
  String dob;
  String sex;
  String address;
  String phoneNumber1;
  String phoneNumber2;
  String notes;
  List<String>? tags;
  String cdate;
  String mdate;

  IdentityItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.sex,
    required this.address,
    required this.phoneNumber1,
    required this.phoneNumber2,
    required this.notes,
    required this.tags,
    required this.cdate,
    required this.mdate,
  });

  factory IdentityItem.fromRawJson(String str) =>
      IdentityItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory IdentityItem.fromJson(Map<String, dynamic> json) {
    return IdentityItem(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      dob: json['dob'],
      sex: json['sex'],
      address: json['address'],
      phoneNumber1: json['phoneNumber1'],
      phoneNumber2: json['phoneNumber2'],
      notes: json['notes'],
      tags: json['tags'] == null ? null : List<String>.from(json["tags"]),
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "firstName": firstName,
      "lastName": lastName,
      "dob": dob,
      "sex": sex,
      "address": address,
      "phoneNumber1": phoneNumber1,
      "phoneNumber2": phoneNumber2,
      "notes": notes,
      "tags": tags,
      "cdate": cdate,
      "mdate": mdate,
    };
    return jsonMap;
  }
}
