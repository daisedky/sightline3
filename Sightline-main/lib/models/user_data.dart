import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String email;
  final DateTime createdAt;
  final DateTime lastLogin;
  final Map<String, dynamic> preferences;

  UserData({
    required this.uid,
    required this.email,
    required this.createdAt,
    required this.lastLogin,
    required this.preferences,
  });

  factory UserData.fromMap(Map<String, dynamic> map, String uid) {
    return UserData(
      uid: uid,
      email: map['email'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastLogin: (map['lastLogin'] as Timestamp).toDate(),
      preferences: Map<String, dynamic>.from(map['preferences'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': Timestamp.fromDate(lastLogin),
      'preferences': preferences,
    };
  }

  UserData copyWith({
    String? uid,
    String? email,
    DateTime? createdAt,
    DateTime? lastLogin,
    Map<String, dynamic>? preferences,
  }) {
    return UserData(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  String toString() {
    return 'UserData(uid: $uid, email: $email, createdAt: $createdAt, preferences: $preferences)';
  }
}
