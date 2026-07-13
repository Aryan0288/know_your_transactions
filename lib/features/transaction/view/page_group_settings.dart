import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:know_your_expenses/features/home/model/group_model.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/transaction/view/widgets/widget_create_group_bottom_sheet.dart';
import 'package:know_your_expenses/features/common_widgets/closable_banner_ad.dart';

class GroupSettingsPage extends ConsumerStatefulWidget {
  const GroupSettingsPage({super.key});

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  final _groupNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedGroupType = 'split';

  @override
  void dispose() {
    _groupNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onCreateGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      Utils.showErrorToast(context, title: "Group Name Required", description: "Please enter a group name.");
      return;
    }

    final success = await ref.read(groupControllerProvider.notifier).createGroup(name, type: _selectedGroupType);
    if (success && mounted) {
      Utils.showSuccessToast(context, title: "Group Created!", description: "You are now the Admin of '$name'.");
      _groupNameController.clear();
      setState(() => _selectedGroupType = 'split');
    }
  }

  void _showCreateGroupBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => CreateGroupBottomSheet(
        controller: _groupNameController,
        selectedType: _selectedGroupType,
        onTypeChanged: (type) {
          setState(() => _selectedGroupType = type);
        },
        onCreate: _onCreateGroup,
      ),
    );
  }

  void _onInviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      Utils.showErrorToast(context, title: "Email Required", description: "Please enter a valid email.");
      return;
    }

    final success = await ref.read(groupControllerProvider.notifier).inviteMember(email);
    if (success) {
      if (mounted) {
        Utils.showSuccessToast(context, title: "Invitation Sent", description: "Invitation reserved for $email.");
        _emailController.clear();
      }
    } else {
      // If invitation fails because user is not registered, trigger url_launcher email
      final state = ref.read(groupControllerProvider);
      final error = state.error?.toString();

      // If it's not a registered user, the controller leaves toUserId as null and returns true
      // So if it returned false with a specific message, it means they are already in a group or it was a real error
      if (error != null) {
        Utils.showErrorToast(context, title: "Invite Failed", description: error);
      } else {
        // Trigger mail client for unregistered user
        final group = ref.read(groupProvider).value;
        final groupName = group?.name ?? 'our group';
        
        final subject = Uri.encodeComponent("Join my group '$groupName' on Finance Tracker");
        final body = Uri.encodeComponent(
          "Hey! I would love to invite you to join my group '$groupName' on Finance Tracker to track our shared expenses.\n\n"
          "Please download the app and register using this email address: $email.\n\n"
          "Download Link: https://finance-tracker-app-download-link.com"
        );
        
        final mailtoUri = Uri.parse("mailto:$email?subject=$subject&body=$body");
        
        try {
          if (await canLaunchUrl(mailtoUri)) {
            await launchUrl(mailtoUri);
          } else {
            Utils.showErrorToast(context, title: "Error", description: "Could not open mail app. Please share the link manually.");
          }
        } catch (e) {
          Utils.showErrorToast(context, title: "Error", description: "Could not launch email app.");
        }
      }
    }
  }


  void _onLeaveGroup() {
    CustomDialogs.showLeaveGroupDialog(
      context,
      onConfirm: () async {
        final success = await ref.read(groupControllerProvider.notifier).leaveGroup();
        if (success && mounted) {
          Utils.showSuccessToast(context, title: "Left Group", description: "You are no longer in the group.");
        }
      },
    );
  }

  Widget _buildGroupSwitcher(String? activeGroupId, AsyncValue<List<GroupModel>> userGroupsAsync) {
    return userGroupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Active Group',
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E232A)),
            ),
            const SizedBox(height: 2),
            Text(
              'This group will be used for your split ledger calculations and selected by default when adding expenses.',
              style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeGroupId,
                  isExpanded: true,
                  hint: Text('Select a group', style: GoogleFonts.manrope()),
                  items: groups.map((g) {
                    return DropdownMenuItem<String>(
                      value: g.id,
                      child: Text(g.name, style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (newGroupId) async {
                    if (newGroupId != null && newGroupId != activeGroupId) {
                      await ref.read(groupControllerProvider.notifier).switchGroup(newGroupId);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildCreateGroupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create a Group',
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E232A)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _groupNameController,
                style: GoogleFonts.manrope(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter Group Name (e.g. Roommates)',
                  hintStyle: GoogleFonts.manrope(color: Colors.grey, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF3F8F5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Type',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E232A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Material(
                color: Colors.transparent,
                child: RadioListTile<String>(
                  title: Text('Split Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Members split expenses between each other.', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600])),
                  value: 'split',
                  groupValue: _selectedGroupType,
                  activeColor: const Color(0xFF2E8B57),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGroupType = val);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: RadioListTile<String>(
                  title: Text('Business Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Only Admin can edit/delete. Members only see their own logs.', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600])),
                  value: 'business',
                  groupValue: _selectedGroupType,
                  activeColor: const Color(0xFF2E8B57),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGroupType = val);
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: RadioListTile<String>(
                  title: Text('Wages / Salary Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Admins record salary payments. Members only see their own wages.', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600])),
                  value: 'wages',
                  groupValue: _selectedGroupType,
                  activeColor: const Color(0xFF2E8B57),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGroupType = val);
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onCreateGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E8B57),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Create Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationsSection(AsyncValue<List<Map<String, dynamic>>> invitationsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Invitations',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E232A)),
        ),
        const SizedBox(height: 12),
        invitationsAsync.when(
          data: (invites) {
            if (invites.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.mail_outline_rounded, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'No pending invitations',
                      style: GoogleFonts.manrope(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invites.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final invite = invites[index];
                final inviteId = invite['id'] as String;
                final groupId = invite['fromGroupId'] as String;
                final groupName = invite['fromGroupName'] as String? ?? 'Shared Group';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupName,
                              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Invited you to join their expense ledger.',
                              style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => ref.read(groupControllerProvider.notifier).declineInvitation(inviteId),
                        icon: const Icon(Icons.close_rounded, color: Colors.red),
                      ),
                      IconButton(
                        onPressed: () => ref.read(groupControllerProvider.notifier).acceptInvitation(inviteId, groupId),
                        icon: const Icon(Icons.check_rounded, color: Colors.green),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57))),
          error: (err, stack) => Text('Error loading invites: $err'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userGroupId = ref.watch(userGroupIdProvider);
    final groupAsync = ref.watch(groupProvider);
    final userGroupsAsync = ref.watch(userGroupsStreamProvider);
    final groupMembersAsync = ref.watch(groupMembersDetailsProvider);
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    final isLoading = ref.watch(groupControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      bottomNavigationBar: const ClosableBannerAd(),
      appBar: AppBar(
        title: Text(
          'Group Settings',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E8B57),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Create Group',
            onPressed: () => _showCreateGroupBottomSheet(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userGroupId != null) ...[
                    _buildGroupSwitcher(userGroupId, userGroupsAsync),
                    groupAsync.when(
                      data: (group) {
                        if (group == null) return const SizedBox();
                            final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
                            final groupAdmins = List<String>.from(group.toMap()['admins'] ?? []);
                            final isUserAdmin = groupAdmins.contains(currentUserId) || group.adminId == currentUserId;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGroupHeaderCard(group),
                                const SizedBox(height: 28),
                                _buildMembersSection(group, groupMembersAsync),
                                if (isUserAdmin) ...[
                                  const SizedBox(height: 28),
                                  _buildInviteSection(),
                                ],
                              ],
                            );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57))),
                      error: (err, stack) => Text('Error loading group: $err'),
                    ),
                  ] else ...[
                    // Empty Group state: Welcome card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E8B57), Color(0xFF429690)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E8B57).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NO ACTIVE GROUP',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Get Started!',
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You are not currently tracking any shared expenses. Create a group or accept a pending invitation below to start splitting bills!',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildCreateGroupSection(),
                  ],

                  invitationsAsync.when(
                    data: (invites) {
                      if (userGroupId == null || invites.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 28.0),
                          child: _buildInvitationsSection(invitationsAsync),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),

                  groupAsync.when(
                    data: (group) {
                      if (group == null) return const SizedBox.shrink();
                      final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
                      final groupAdmins = List<String>.from(group.toMap()['admins'] ?? []);
                      final isUserAdmin = groupAdmins.contains(currentUserId) || group.adminId == currentUserId;
                      if (isUserAdmin) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 40.0),
                          child: _buildDangerZone(),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupHeaderCard(GroupModel group) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E8B57), Color(0xFF429690)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E8B57).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE GROUP',
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            group.name,
            style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'This group is currently active for split ledger and group expense tracking.',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(GroupModel group, AsyncValue<List<Map<String, dynamic>>> membersAsync) {
    final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group Members',
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E232A)),
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, child) {
            final invitesAsync = ref.watch(groupSentPendingInvitationsProvider(group.id));

            return membersAsync.when(
              data: (members) {
                return invitesAsync.when(
                  data: (invites) {
                    final totalCount = members.length + invites.length;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalCount,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          if (index < members.length) {
                            final member = members[index];
                            final uid = member['uid'] as String;
                            final name = member['name'] as String? ?? 'Group Member';
                            final email = member['email'] as String? ?? '';
                            final groupAdmins = List<String>.from(group.toMap()['admins'] ?? []);
                            final isAdmin = groupAdmins.contains(uid) || group.adminId == uid;
                            final isMe = currentUserId == uid;

                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Row(
                                  children: [
                                    Text(
                                      isMe ? '$name (You)' : name,
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6F3F2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Admin',
                                          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF2E7D79)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(email, style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[600])),
                                trailing: (groupAdmins.contains(currentUserId) || group.adminId == currentUserId) && !isMe
                                    ? PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (value) async {
                                          if (value == 'promote') {
                                            final success = await ref
                                                .read(groupControllerProvider.notifier)
                                                .promoteToAdmin(uid);
                                            if (success && context.mounted) {
                                              Utils.showSuccessToast(context, title: "Promoted to Admin!");
                                            }
                                          } else if (value == 'demote') {
                                            if (uid == group.adminId) {
                                              Utils.showErrorToast(context,
                                                  title: "Action Not Allowed",
                                                  description: "Cannot demote the primary group creator.");
                                              return;
                                            }
                                            final success = await ref
                                                .read(groupControllerProvider.notifier)
                                                .demoteFromAdmin(uid);
                                            if (success && context.mounted) {
                                              Utils.showSuccessToast(context, title: "Demoted to Member!");
                                            }
                                          } else if (value == 'remove_member') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('Remove Member', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                                                content: Text('Are you sure you want to remove $name from the group?', style: GoogleFonts.manrope()),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: Text('Remove', style: GoogleFonts.manrope(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true && context.mounted) {
                                              final success = await ref
                                                  .read(groupControllerProvider.notifier)
                                                  .removeMemberFromGroup(uid);
                                              if (success && context.mounted) {
                                                Utils.showSuccessToast(context, title: "Member Removed");
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (!groupAdmins.contains(uid) && uid != group.adminId) ...[
                                            const PopupMenuItem(
                                              value: 'promote',
                                              child: Text('Make Admin'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'remove_member',
                                              child: Text('Remove from Group', style: TextStyle(color: Colors.red)),
                                            ),
                                          ] else if (uid != group.adminId) ...[
                                            const PopupMenuItem(
                                              value: 'demote',
                                              child: Text('Remove Admin Role'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'remove_member',
                                              child: Text('Remove from Group', style: TextStyle(color: Colors.red)),
                                            ),
                                          ]
                                        ],
                                      )
                                    : null,
                              ),
                            );
                          } else {
                            final inviteIndex = index - members.length;
                            final invite = invites[inviteIndex];
                            final inviteId = invite['id'] as String;
                            final toEmail = invite['toEmail'] as String? ?? '';
                            final groupAdmins = List<String>.from(group.toMap()['admins'] ?? []);
                            final isCurrentUserAdmin = groupAdmins.contains(currentUserId) || group.adminId == currentUserId;

                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        toEmail,
                                        style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Text(
                                        'Pending',
                                        style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text('Invitation sent', style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[500])),
                                trailing: isCurrentUserAdmin
                                    ? PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (value) async {
                                          if (value == 'revoke') {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('Revoke Invitation', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                                                content: Text('Are you sure you want to revoke invitation for $toEmail?', style: GoogleFonts.manrope()),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: Text('Revoke', style: GoogleFonts.manrope(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true && context.mounted) {
                                              final success = await ref
                                                  .read(groupControllerProvider.notifier)
                                                  .cancelInvitation(inviteId);
                                              if (success && context.mounted) {
                                                Utils.showSuccessToast(context, title: "Invitation Revoked");
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'revoke',
                                            child: Text('Revoke Invite', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF2E8B57)))),
                  error: (e, s) => Text('Error loading invites: $e'),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF2E8B57)))),
              error: (e, s) => Text('Error: $e'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInviteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Member',
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E232A)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.manrope(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Member Email Address',
                  hintStyle: GoogleFonts.manrope(color: Colors.grey, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF3F8F5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onInviteMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E8B57),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Send Invitation', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[900]),
          ),
          const SizedBox(height: 8),
          Text(
            'Leaving the group will remove your access to the shared transaction ledger.',
            style: GoogleFonts.manrope(fontSize: 13, color: Colors.red[800]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onLeaveGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Leave Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
