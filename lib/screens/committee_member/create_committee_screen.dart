import 'package:apartment/screens/committee_member/update_committee_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateCommitteeScreen extends StatefulWidget {
  const CreateCommitteeScreen({Key? key}) : super(key: key);

  @override
  _CreateCommitteeScreenState createState() => _CreateCommitteeScreenState();
}

class _CreateCommitteeScreenState extends State<CreateCommitteeScreen> {
  final TextEditingController flatIdController = TextEditingController();
  final TextEditingController apartmentNameController = TextEditingController();
  bool isLoading = false;
  bool isSaved = false;
  List<Map<String, dynamic>> flatMembers = [];
  String? currentUserRole;
  String? currentFlatId;
  String? currentApartmentName;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _saveFlatIdAndApartmentName() async {
    setState(() => isLoading = true);

    final flatId = flatIdController.text.trim();
    final apartmentName = apartmentNameController.text.trim();

    if (flatId.isEmpty || apartmentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Flat ID and Apartment Name are required.")),
      );
      setState(() => isLoading = false);
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Save Flat ID and Apartment Name in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'flatId': flatId,
        'apartmentName': apartmentName,
      }, SetOptions(merge: true));

      setState(() {
        isSaved = true; // Hide the button after saving
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Flat ID & Apartment Name saved!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCurrentUserData() async {
    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Get user document
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            currentUserRole = userDoc['role'];
            currentFlatId = userDoc['flatId'];
            currentApartmentName = userDoc['apartmentName'] ?? '';

            // Set controllers with existing data
            if (currentFlatId != null && currentFlatId!.isNotEmpty) {
              flatIdController.text = currentFlatId!;
            }
            if (currentApartmentName != null &&
                currentApartmentName!.isNotEmpty) {
              apartmentNameController.text = currentApartmentName!;
              isSaved = true;
            } else {
              _fetchApartmentNameForFlatId(currentFlatId!);
            }
          });

          // Load members if flat ID exists
          if (currentFlatId != null && currentFlatId!.isNotEmpty) {
            await _loadFlatMembers();
            await _loadCommitteeData();
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading user data: ${e.toString()}")),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchApartmentNameForFlatId(String flatId) async {
    if (flatId.isEmpty) return;

    try {
      final flatDoc = await FirebaseFirestore.instance
          .collection('committees')
          .doc(flatId)
          .get();

      if (flatDoc.exists) {
        final apartmentName = flatDoc['apartmentName'] ?? '';
        if (apartmentName.isNotEmpty) {
          setState(() {
            apartmentNameController.text = apartmentName;
            currentApartmentName = apartmentName;
          });

          // Update user's document with apartmentName
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set(
              {'apartmentName': apartmentName},
              SetOptions(merge: true),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error fetching apartment name: ${e.toString()}")),
      );
    }
  }

  Future<void> _loadCommitteeData() async {
    final flatId = flatIdController.text.trim();
    if (flatId.isEmpty) return;

    try {
      final committeeDoc = await FirebaseFirestore.instance
          .collection('committees')
          .doc(flatId)
          .get();

      if (committeeDoc.exists && committeeDoc.data() != null) {
        final data = committeeDoc.data()!;
        if (data['apartmentName'] != null &&
            apartmentNameController.text.isEmpty) {
          setState(() {
            apartmentNameController.text = data['apartmentName'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error loading committee data: ${e.toString()}")),
      );
    }
  }

  Future<void> _loadFlatMembers() async {
    final flatId = flatIdController.text.trim();
    if (flatId.isEmpty) {
      setState(() => flatMembers = []);
      return;
    }

    setState(() => isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('flatId', isEqualTo: flatId)
          .get();

      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

      List<Map<String, dynamic>> members = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'],
          'email': doc['email'],
          'role': doc['role'],
          'flatNumber': doc['flatNumber'],
          'wing': doc['wing'],
          'isCurrentUser': doc.id == currentUserId,
        };
      }).toList();

      // Extract current user
      Map<String, dynamic>? currentUser = members.firstWhere(
        (m) => m['isCurrentUser'],
        orElse: () => {},
      );

      // Separate committee and society members (excluding current user)
      List<Map<String, dynamic>> committeeMembers = members
          .where((m) => m['role'] == 'Committee Member' && !m['isCurrentUser'])
          .toList();

      List<Map<String, dynamic>> societyMembers = members
          .where((m) => m['role'] == 'Society Member' && !m['isCurrentUser'])
          .toList();

      // Sorting function for Flat Number (numerically) and Wing (alphabetically)
      int compareFlatNumbers(Map<String, dynamic> a, Map<String, dynamic> b) {
        int flatA = int.tryParse(a['flatNumber']) ?? 0;
        int flatB = int.tryParse(b['flatNumber']) ?? 0;
        int wingComparison = a['wing'].compareTo(b['wing']);
        return flatA == flatB ? wingComparison : flatA.compareTo(flatB);
      }

      committeeMembers.sort(compareFlatNumbers);
      societyMembers.sort(compareFlatNumbers);

      // Combine lists with current user at the top
      List<Map<String, dynamic>> sortedMembers = [
        if (currentUser.isNotEmpty) currentUser, // Add current user first
        ...committeeMembers,
        ...societyMembers
      ];

      setState(() => flatMembers = sortedMembers);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading members: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleMemberRole(String userId, String currentRole) async {
    if (currentUserRole != 'Committee Member') return;

    setState(() => isLoading = true);
    final newRole =
        currentRole == 'Society Member' ? 'Committee Member' : 'Society Member';

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
      });

      // Update local state
      setState(() {
        final memberIndex = flatMembers.indexWhere((m) => m['id'] == userId);
        if (memberIndex != -1) {
          flatMembers[memberIndex]['role'] = newRole;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Member role updated to $newRole")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating role: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> createCommittee() async {
    setState(() => isLoading = true);

    final flatId = flatIdController.text.trim();
    final apartmentName = apartmentNameController.text.trim();

    if (flatId.isEmpty || apartmentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Flat ID and Apartment Name are required.")),
      );
      setState(() => isLoading = false);
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // **Step 1: Fetch all users with the same Flat ID**
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('flatId', isEqualTo: flatId)
          .get();

      // **Step 2: Prepare Members List**
      List<Map<String, dynamic>> membersList = usersSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'] ?? '',
          'role': doc['role'] ?? 'Society Member', // Default to Society Member
        };
      }).toList();

      // **Step 3: Create or Update Committee Document**
      await FirebaseFirestore.instance
          .collection('committees')
          .doc(flatId)
          .set({
        'flatId': flatId,
        'apartmentName': apartmentName,
        'createdBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'members': membersList, // Store the members list here
      }, SetOptions(merge: true));

      print(
          "✅ Committee Created: Flat ID = $flatId, Apartment = $apartmentName");

      // **Step 4: Update Current User**
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'flatId': flatId,
        'apartmentName': apartmentName,
        'role': 'Committee Member',
      }, SetOptions(merge: true));

      print("✅ Current User Updated");

      // **Step 5: Update All Users with Apartment Name**
      for (var doc in usersSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .update({
          'apartmentName': apartmentName,
        });
      }

      print("✅ Updated all users with Apartment Name");

      // **Step 6: Reload User Data**
      await _loadCurrentUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Committee created successfully!")),
      );
    } catch (e) {
      print("❌ Error Creating Committee: ${e.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Committee Management",style: TextStyle(fontSize: 18),),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const UpdateCommitteeScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: flatIdController,
              decoration: const InputDecoration(
                labelText: "Flat ID",
                border: OutlineInputBorder(),
                hintText: "Your society's flat ID",
              ),
              readOnly: currentFlatId != null &&
                  currentFlatId!.isNotEmpty, // Only read-only if flatId exists
              style: TextStyle(
                color: (currentFlatId != null && currentFlatId!.isNotEmpty)
                    ? Colors.grey.shade700
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: apartmentNameController,
              decoration: const InputDecoration(
                labelText: "Apartment Name",
                border: OutlineInputBorder(),
                hintText: "Your society's Name",
              ),
              readOnly: currentApartmentName != null &&
                  currentApartmentName!.isNotEmpty &&
                  isSaved, // Only read-only if flatId exists
              style: TextStyle(
                color: (currentApartmentName != null &&
                        currentApartmentName!.isNotEmpty)
                    ? Colors.grey.shade700
                    : Colors.black,
              ),
            ),

            const SizedBox(height: 12),

            // Show Save Button if not saved yet
            if (!isSaved)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: isLoading ? null : _saveFlatIdAndApartmentName,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          "SAVE FLAT ID & APARTMENT NAME",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),

            const SizedBox(height: 24),

            // Members List Header
            Row(
              children: [
                const Text(
                  "Flat Members",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isLoading) const CircularProgressIndicator(),
              ],
            ),
            const SizedBox(height: 8),

            // Members List
            if (flatMembers.isEmpty && !isLoading)
              const Center(
                child: Text(
                  "No members found for this Flat ID",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadFlatMembers,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: flatMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = flatMembers[index];
                      final isCommittee = member['role'] == 'Committee Member';
                      final isCurrent = member['isCurrentUser'];

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.blue.shade50,
                                  child: Text(
                                    member['flatNumber'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member['email'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isCommittee
                                            ? Colors.green.shade100
                                            : Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        member['role'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isCommittee
                                              ? Colors.green.shade800
                                              : Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (currentUserRole == 'Committee Member' && !isCurrent)
                                IconButton(
                                  icon: Icon(
                                    member['role'] == 'Society Member'
                                        ? Icons.person_add_alt_1
                                        : Icons.person_remove_alt_1,
                                    color: Colors.blue,
                                  ),
                                  tooltip: member['role'] == 'Society Member'
                                      ? "Promote to Committee"
                                      : "Demote to Member",
                                  onPressed: () => _toggleMemberRole(
                                    member['id'],
                                    member['role'],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),


            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: apartmentNameController.text.isEmpty
                      ? Colors.grey.shade300
                      : Theme.of(context).primaryColor,
                ),
                onPressed: apartmentNameController.text.isEmpty || isLoading
                    ? null
                    : createCommittee,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "SAVE COMMITTEE",
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
