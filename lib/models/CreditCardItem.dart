import 'dart:convert';

///TODO: add this item in
class CreditCardItem {
  String id;
  String cardholderName;
  String type;
  String number;
  String verificationNumber;
  String expiryDate;
  String pin;
  String notes;
  List<String>? tags;
  String cdate;
  String mdate;

  CreditCardItem({
    required this.id,
    required this.cardholderName,
    required this.type,
    required this.number,
    required this.verificationNumber,
    required this.expiryDate,
    required this.pin,
    required this.notes,
    required this.tags,
    required this.cdate,
    required this.mdate,
  });

  factory CreditCardItem.fromRawJson(String str) =>
      CreditCardItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory CreditCardItem.fromJson(Map<String, dynamic> json) {
    return CreditCardItem(
      id: json['id'],
      cardholderName: json['cardholderName'],
      type: json['type'],
      number: json['number'],
      verificationNumber: json['verificationNumber'],
      expiryDate: json['expiryDate'],
      pin: json['pin'],
      notes: json['notes'],
      tags: json['tags'] == null ? null : List<String>.from(json["tags"]),
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "cardholderName": cardholderName,
      "type": type,
      "number": number,
      "verificationNumber": verificationNumber,
      "expiryDate": expiryDate,
      "pin": pin,
      "notes": notes,
      "tags": tags,
      "cdate": cdate,
      "mdate": mdate,
    };
    return jsonMap;
  }
}
