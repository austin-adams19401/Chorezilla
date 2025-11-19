part of 'chorezilla_repo.dart';

extension ProfileRepo on ChorezillaRepo {
  // ---------------------------
  // Bootstrap / Profiles
  // ---------------------------
  Future<UserProfile> checkForUserProfile(String userID, {String? displayName, String? email}) async {
    final uRef = userDoc(firebaseDB, userID);
    var snap = await uRef.get();
    var profile = UserProfile.fromDoc(snap);

    final updates = <String, dynamic>{};
    final isNewProfile = profile.email == null || profile.email!.isEmpty;   

if (isNewProfile) {
      updates['uid'] = userID;
      if (displayName != null && displayName.isNotEmpty) {
        updates['displayName'] = displayName;
      }
      if (email != null && email.isNotEmpty) {
        updates['email'] = email;
      }
      updates['createdAt'] = FieldValue.serverTimestamp();
    } else {
      if ((profile.displayName == null || profile.displayName!.isEmpty) &&
          displayName != null &&
          displayName.isNotEmpty) {
        updates['displayName'] = displayName;
      }
      if ((profile.email == null || profile.email!.isEmpty) &&
          email != null &&
          email.isNotEmpty) {
        updates['email'] = email;
      }
    }

    updates['lastSignInAt'] = FieldValue.serverTimestamp();

    if (updates.isNotEmpty) {
      await uRef.set(updates, SetOptions(merge: true));
      snap = await uRef.get();
      profile = UserProfile.fromDoc(snap);
    }

    // Ensure they have a default family + owner membership
    if (profile.defaultFamilyId == null || profile.defaultFamilyId!.isEmpty) {
      profile = await _getOrCreateFamilyWithOwner(
        userID,
        displayName,
        email: email,
      );
    }

    return profile;
  }

  Future<UserProfile> _getOrCreateFamilyWithOwner(
    String ownerUId,
    String? displayName, {
    String? email,
  }) async {
    final topLevel = FirebaseFirestore.instance;
    final authName = FirebaseAuth.instance.currentUser?.displayName;
    final uRef = topLevel.collection('users').doc(ownerUId);

    await topLevel.runTransaction((tx) async {
      final userSnap = await tx.get(uRef);
      final userData = userSnap.data() ?? {};
      final currentFamId = (userData['defaultFamilyId'] as String?)?.trim();
      final storedName = (userData['displayName'] as String?)?.trim();

      // Decide on the best display name to use
      final explicitName = displayName?.trim();
      final effectiveName = (explicitName != null && explicitName.isNotEmpty)
          ? explicitName
          : (authName != null && authName.trim().isNotEmpty)
          ? authName.trim()
          : (storedName != null && storedName.isNotEmpty)
          ? storedName
          : 'Parent';

      final ownerFirstName = effectiveName.split(' ').first;
      final familyName = "$ownerFirstName's Family";

      if (currentFamId != null && currentFamId.isNotEmpty) {
        // Family already exists; ensure owner member & memberships entry exist
        final famDoc = topLevel.collection('families').doc(currentFamId);
        final ownerMemberDoc = famDoc.collection('members').doc(ownerUId);

        final ownerMemberSnap = await tx.get(ownerMemberDoc);
        if (!ownerMemberSnap.exists) {
          tx.set(ownerMemberDoc, {
            'userUid': ownerUId,
            'displayName': effectiveName,
            'role': 'parent',
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Heal name/role on existing owner member
          tx.set(ownerMemberDoc, {
            'displayName': effectiveName,
            'role': 'parent',
          }, SetOptions(merge: true));
        }

        // Heal memberships entry + profile name/email
        tx.set(uRef, {
          'displayName': effectiveName,
          if (email != null && email.isNotEmpty) 'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
          'memberships.$currentFamId': {
            'memberId': ownerMemberDoc.id,
            'role': 'parent',
          },
        }, SetOptions(merge: true));

        return;
      }

      // No family yet → create one
      final famDoc = topLevel.collection('families').doc(ownerUId);
      final memberDoc = famDoc.collection('members').doc(ownerUId);

      tx.set(famDoc, {
        'name': familyName,
        'ownerUid': ownerUId,
        'active': true,
        'onboardingComplete' : false,
        'settings': {
          'pointsPerDifficulty': {'1': 10, '2': 20, '3': 35, '4': 55, '5': 80},
        },
      }, SetOptions(merge: true));

      tx.set(memberDoc, {
        'userUid': ownerUId,
        'displayName': effectiveName,
        'role': 'parent',
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(uRef, {
        'defaultFamilyId': famDoc.id,
        'displayName': effectiveName,
        if (email != null && email.isNotEmpty) 'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
        'memberships.${famDoc.id}': {
          'memberId': memberDoc.id,
          'role': 'parent',
        },
      }, SetOptions(merge: true));
    });

    final snap = await uRef.get();
    return UserProfile.fromDoc(snap);
  }
}
