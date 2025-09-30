import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.location,
    required this.community,
    required this.isAdmin,
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String location;
  final String community;
  final bool isAdmin;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoUrl;

  String get displayName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'location': location,
      'community': community,
      'isAdmin': isAdmin,
      'emailVerified': emailVerified,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? location,
    String? community,
    bool? isAdmin,
    bool? emailVerified,
    String? photoUrl,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      community: community ?? this.community,
      isAdmin: isAdmin ?? this.isAdmin,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  static AppUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User document ${doc.id} is missing');
    }

    return AppUser(
      uid: doc.id,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      location: data['location'] as String? ?? '',
      community: data['community'] as String? ?? '',
      isAdmin: data['isAdmin'] as bool? ?? false,
      emailVerified: data['emailVerified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: data['photoUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        firstName,
        lastName,
        email,
        phoneNumber,
        location,
        community,
        isAdmin,
        emailVerified,
        createdAt,
        updatedAt,
        photoUrl,
      ];
}
