import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:know_your_expenses/features/home/model/group_model.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';

class SplitBalance {
  final String debtorId;
  final String debtorName;
  final String creditorId;
  final String creditorName;
  final double amount;

  SplitBalance({
    required this.debtorId,
    required this.debtorName,
    required this.creditorId,
    required this.creditorName,
    required this.amount,
  });
}

// ─── Group State Providers ───────────────────────────────────────────────────

final invitationDialogShownProvider = StateProvider<bool>((ref) => false);

final groupProvider = StreamProvider<GroupModel?>((ref) {
  final groupId = ref.watch(userGroupIdProvider);
  if (groupId == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .map((doc) => doc.exists ? GroupModel.fromMap(doc.data()!, doc.id) : null);
});

final groupByIdStreamProvider = StreamProvider.family<GroupModel?, String>((ref, groupId) {
  if (groupId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .map((doc) => doc.exists ? GroupModel.fromMap(doc.data()!, doc.id) : null);
});

final groupLogsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  if (groupId.isEmpty) return Stream.value([]);
  
  final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  final groupAsync = ref.watch(groupByIdStreamProvider(groupId));
  
  return groupAsync.when(
    data: (group) {
      if (group == null) return Stream.value(<Map<String, dynamic>>[]);
      
      var query = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('logs')
          .orderBy('timestamp', descending: true);
          

      
      return query.snapshots().map((snapshot) {
        final groupType = group.toMap()['type'] as String? ?? 'split';
        final adminId = group.toMap()['adminId'] as String? ?? '';
        final isAdmin = currentUserId == adminId;

        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).where((log) {
          if (groupType == 'business') {
            return log['userRole'] == 'admin';
          }
          return true;
        }).toList();
      });
    },
    loading: () => Stream.value(<Map<String, dynamic>>[]),
    error: (err, stack) => Stream.value(<Map<String, dynamic>>[]),
  );
});

final userGroupsStreamProvider = StreamProvider<List<GroupModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('groups')
      .where('members', arrayContains: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
          .toList());
});

final groupMembersDetailsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final group = ref.watch(groupProvider).value;
  if (group == null || group.members.isEmpty) return Stream.value([]);

  // Firestore whereIn is capped at 10, perfect for family/small groups.
  final chunkedMembers = group.members.take(10).toList();

  return FirebaseFirestore.instance
      .collection('users')
      .where(FieldPath.documentId, whereIn: chunkedMembers)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        }).toList();
      });
});

final groupMembersDetailsByIdProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  if (groupId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .asyncMap((doc) async {
        if (!doc.exists) return <Map<String, dynamic>>[];
        final members = List<String>.from(doc.data()?['members'] ?? []);
        if (members.isEmpty) return <Map<String, dynamic>>[];
        final chunked = members.take(10).toList();

        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunked)
            .get();

        return snapshot.docs.map((d) {
          final data = d.data();
          data['uid'] = d.id;
          return data;
        }).toList();
      });
});

final pendingInvitationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.email == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('invitations')
      .where('toEmail', isEqualTo: user.email!.toLowerCase())
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
});

final groupTransactionsStreamByIdProvider = StreamProvider.family<List<TransactionModel>, String>((ref, groupId) {
  if (groupId.isEmpty) return Stream.value([]);
  
  final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  final groupAsync = ref.watch(groupByIdStreamProvider(groupId));
  
  return groupAsync.when(
    data: (group) {
      if (group == null || currentUserId == null) return Stream.value(<TransactionModel>[]);
      
      var query = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('transactions')
          .orderBy('date', descending: true);
          

      
      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) {
              final data = doc.data();
              if (data['groupId'] == null) {
                data['groupId'] = groupId;
              }
              return TransactionModel.fromMap(data, doc.id);
            })
            .toList();
      });
    },
    loading: () => Stream.value(<TransactionModel>[]),
    error: (err, stack) => Stream.value(<TransactionModel>[]),
  );
});

final groupSplitBalancesProvider = Provider.family<List<SplitBalance>, String>((ref, groupId) {
  final group = ref.watch(groupByIdStreamProvider(groupId)).value;
  if (group == null || group.type == 'business') return [];

  final transactions = ref.watch(groupTransactionsStreamByIdProvider(groupId)).value ?? [];
  final members = ref.watch(groupMembersDetailsByIdProvider(groupId)).value ?? [];

  if (members.isEmpty) return [];

  final memberNames = {
    for (var m in members) m['uid'] as String: m['name'] as String? ?? 'Group Member'
  };

  Map<String, double> netBalances = {
    for (var m in members) m['uid'] as String: 0.0
  };

  for (var t in transactions) {
    if (!t.isShared || t.splitWith == null || t.splitWith!.isEmpty) continue;

    final activeSplits = t.splitWith!.where((uid) => netBalances.containsKey(uid)).toList();
    if (activeSplits.isEmpty) continue;

    if (netBalances.containsKey(t.userId)) {
      netBalances[t.userId] = netBalances[t.userId]! + t.amount;
    }

    for (var uid in activeSplits) {
      double share = 0.0;
      if (t.splitAmounts != null && t.splitAmounts!.containsKey(uid)) {
        share = t.splitAmounts![uid]!;
      } else {
        share = t.amount / activeSplits.length;
      }
      netBalances[uid] = netBalances[uid]! - share;
    }
  }

  final debtors = <_MemberBalance>[];
  final creditors = <_MemberBalance>[];

  netBalances.forEach((uid, balance) {
    if (balance.abs() < 0.01) return;

    final name = memberNames[uid] ?? 'Group Member';
    if (balance < 0) {
      debtors.add(_MemberBalance(uid, name, balance));
    } else {
      creditors.add(_MemberBalance(uid, name, balance));
    }
  });

  debtors.sort((a, b) => a.balance.compareTo(b.balance));
  creditors.sort((a, b) => b.balance.compareTo(a.balance));

  List<SplitBalance> settlements = [];
  int d = 0;
  int c = 0;

  while (d < debtors.length && c < creditors.length) {
    var debtor = debtors[d];
    var creditor = creditors[c];

    double debtAmount = debtor.balance.abs();
    double creditAmount = creditor.balance;

    double settleAmount = min(debtAmount, creditAmount);

    settlements.add(SplitBalance(
      debtorId: debtor.uid,
      debtorName: debtor.name,
      creditorId: creditor.uid,
      creditorName: creditor.name,
      amount: settleAmount,
    ));

    debtor.balance += settleAmount;
    creditor.balance -= settleAmount;

    if (debtor.balance.abs() < 0.01) {
      d++;
    }
    if (creditor.balance < 0.01) {
      c++;
    }
  }

  return settlements;
});

final allGroupsTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final groups = ref.watch(userGroupsStreamProvider).value ?? [];
  final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (groups.isEmpty || currentUserId == null) return Stream.value([]);

  final controllers = <StreamSubscription<List<TransactionModel>>>[];
  final controller = StreamController<List<TransactionModel>>();

  final groupLists = <String, List<TransactionModel>>{};

  void emitCombined() {
    final allTx = groupLists.values.expand((list) => list).toList();
    allTx.sort((a, b) => b.date.compareTo(a.date));
    if (!controller.isClosed) {
      controller.add(allTx);
    }
  }

  for (var group in groups) {
    var query = FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .collection('transactions')
        .orderBy('date', descending: true);



    final sub = query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                if (data['groupId'] == null) {
                  data['groupId'] = group.id;
                }
                return TransactionModel.fromMap(data, doc.id);
              })
              .toList();
        })
        .listen((list) {
          groupLists[group.id] = list;
          emitCombined();
        });
    controllers.add(sub);
  }

  ref.onDispose(() {
    for (var sub in controllers) {
      sub.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

final splitBalancesProvider = Provider<List<SplitBalance>>((ref) {
  final groupId = ref.watch(userGroupIdProvider);
  if (groupId == null) return [];
  return ref.watch(groupSplitBalancesProvider(groupId));
});

class _MemberBalance {
  final String uid;
  final String name;
  double balance;
  _MemberBalance(this.uid, this.name, this.balance);
}

// ─── Group Controller (StateNotifier) ────────────────────────────────────────

final groupControllerProvider = StateNotifierProvider<GroupController, AsyncValue<void>>((ref) {
  return GroupController(ref);
});

class GroupController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  GroupController(this.ref) : super(const AsyncValue.data(null));

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<bool> createGroup(String groupName, {String type = 'split'}) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final groupDocRef = _firestore.collection('groups').doc();

      final group = GroupModel(
        id: groupDocRef.id,
        name: groupName,
        adminId: user.uid,
        members: [user.uid],
        memberLimits: {},
        type: type,
      );

      // Create group document
      await groupDocRef.set({
        ...group.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await _firestore.collection('users').doc(user.uid).update({
        'groupId': groupDocRef.id,
        'groupRole': 'admin',
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> inviteMember(String email) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    final groupId = ref.read(userGroupIdProvider);
    final group = ref.read(groupProvider).value;

    if (user == null || groupId == null || group == null) return false;

    state = const AsyncValue.loading();
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Search if user exists
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      String? targetUserId;
      if (userQuery.docs.isNotEmpty) {
        targetUserId = userQuery.docs.first.id;
        if (group.members.contains(targetUserId)) {
          state = AsyncValue.error('User is already a member of this group', StackTrace.current);
          return false;
        }
      }

      // Create pending invitation doc
      await _firestore.collection('invitations').add({
        'fromGroupId': groupId,
        'fromGroupName': group.name,
        'toUserId': targetUserId,
        'toEmail': normalizedEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> acceptInvitation(String invitationId, String groupId) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      // 1. Accept invite
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'accepted',
      });

      // 2. Add member to group
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      // 3. Set groupId on user profile
      await _firestore.collection('users').doc(user.uid).update({
        'groupId': groupId,
        'groupRole': 'member',
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> declineInvitation(String invitationId) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'declined',
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> leaveGroup() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    final groupId = ref.read(userGroupIdProvider);
    final group = ref.read(groupProvider).value;

    if (user == null || groupId == null || group == null) return false;

    state = const AsyncValue.loading();
    try {
      // Remove from group members list
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([user.uid]),
      });

      // Find if user has another group they belong to
      final otherGroupsQuery = await _firestore
          .collection('groups')
          .where('members', arrayContains: user.uid)
          .get();

      String? nextGroupId;
      String? nextRole;

      // Filter out the group they just left
      final remainingGroups = otherGroupsQuery.docs
          .where((doc) => doc.id != groupId)
          .toList();

      if (remainingGroups.isNotEmpty) {
        final nextGroupDoc = remainingGroups.first;
        nextGroupId = nextGroupDoc.id;
        final nextGroupData = nextGroupDoc.data();
        nextRole = nextGroupData['adminId'] == user.uid ? 'admin' : 'member';
      }

      // Reset or switch user group settings
      await _firestore.collection('users').doc(user.uid).update({
        'groupId': nextGroupId,
        'groupRole': nextRole,
      });

      // If group becomes empty, delete it
      final updatedGroupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (updatedGroupDoc.exists) {
        final membersList = List<String>.from(updatedGroupDoc.data()?['members'] ?? []);
        if (membersList.isEmpty) {
          await _firestore.collection('groups').doc(groupId).delete();
        } else if (group.adminId == user.uid) {
          // Reassign admin role to the next member
          final newAdminId = membersList.first;
          await _firestore.collection('groups').doc(groupId).update({
            'adminId': newAdminId,
          });
          await _firestore.collection('users').doc(newAdminId).update({
            'groupRole': 'admin',
          });
        }
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> switchGroup(String groupId) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data()!;
      final membersList = List<String>.from(groupData['members'] ?? []);
      if (!membersList.contains(user.uid)) {
        state = AsyncValue.error('User is not a member of this group', StackTrace.current);
        return false;
      }

      final isAdmin = groupData['adminId'] == user.uid;

      await _firestore.collection('users').doc(user.uid).update({
        'groupId': groupId,
        'groupRole': isAdmin ? 'admin' : 'member',
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}
