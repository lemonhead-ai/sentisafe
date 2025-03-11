class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });

  // Convert EmergencyContact to a Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }

  // Create EmergencyContact from a Map
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
    );
  }
}

class SafetyPlan {
  final List<EmergencyContact> contacts;
  final String safeWord;

  SafetyPlan({
    required this.contacts,
    required this.safeWord,
  });

  // Convert SafetyPlan to a Map
  Map<String, dynamic> toJson() {
    return {
      'contacts': contacts.map((contact) => contact.toJson()).toList(),
      'safeWord': safeWord,
    };
  }

  // Create SafetyPlan from a Map
  factory SafetyPlan.fromJson(Map<String, dynamic> json) {
    return SafetyPlan(
      contacts: (json['contacts'] as List)
          .map((contact) => EmergencyContact.fromJson(contact))
          .toList(),
      safeWord: json['safeWord'],
    );
  }
}