import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberDetail extends StatefulWidget {
  const MemberDetail({super.key});

  @override
  State<MemberDetail> createState() => _MemberDetailState();
}

class _MemberDetailState extends State<MemberDetail> {
  String? userFlatId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserFlatIdFromFirestore();
  }

  Future<void> _fetchUserFlatIdFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      final data = userDoc.data();
      setState(() {
        userFlatId = data?['flatId'];
        isLoading = false;
      });
      debugPrint("✅ Flat ID from Firestore: $userFlatId");
    } else {
      setState(() {
        isLoading = false;
      });
      debugPrint("❌ User document does not exist in Firestore.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userFlatId == null) {
      return const Scaffold(
        body: Center(child: Text("Flat ID not found. Please log in again.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Member Details"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('flatId', isEqualTo: userFlatId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No members found for your flat."));
          }

          final members = snapshot.data!.docs;

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final data = members[index].data() as Map<String, dynamic>;

              final name = data['name'] ?? 'No Name';
              final phone = data['phone'] ?? 'No Phone';
              final email = data['email'] ?? 'No Email';
              final role = data['role'] ?? 'No Role';
              final flatNumber = data['flatNumber'] ?? 'N/A';
              final wing = data['wing'] ?? 'N/A';
              final familyMembers = data['familyMembers'] ?? [];

              return Card(
                elevation: 6,
                shadowColor: Colors.black26,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Profile initials
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.blueAccent,
                            child: Text(
                              name.isNotEmpty
                                  ? flatNumber
                                  : '?',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Name and info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text("📞 $phone"),
                                Text("📧 $email"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTag("🏢 Wing: $wing",
                              Colors.blue.shade100, Colors.blue),
                          _buildTag("🎖️ $role",
                              Colors.tealAccent.shade100, Colors.tealAccent.shade700),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "👨‍👩‍👧‍👦 Family Members",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (familyMembers == null || familyMembers.isEmpty)
                        const Text("No family members added."),
                      if (familyMembers != null && familyMembers.isNotEmpty)
                        Column(
                          children:
                          (familyMembers as List).map((member) {
                            final fname = member['name'] ?? 'No Name';
                            final fphone = member['phone'] ?? 'No Phone';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: Text(fname),
                              subtitle: Text("📞 $fphone"),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
