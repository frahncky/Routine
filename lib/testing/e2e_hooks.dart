import 'package:flutter/foundation.dart';
import 'package:routine/models/user_profile.dart';

typedef ProfileImagePickerOverride = Future<String?> Function();

ProfileImagePickerOverride? profileImagePickerOverride;

final ValueNotifier<UserProfile> currentUserProfileNotifier =
    ValueNotifier<UserProfile>(
  const UserProfile(
    name: 'Visitante',
    avatarUrl: null,
    revision: 0,
  ),
);
