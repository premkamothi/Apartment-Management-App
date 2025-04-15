import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController wingController = TextEditingController();
  final TextEditingController flatNumberController = TextEditingController();
  List<Map<String, dynamic>> familyMembers = [];
  List<TextEditingController> familyNameControllers = [];
  List<TextEditingController> familyPhoneControllers = [];
  bool isLoading = false;
  String flatNumber = "";
  String wing = "";
  String userId = "";
  int familyCount = 1;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  void fetchUserProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      if (userDoc.exists) {
        setState(() {
          nameController.text = userDoc['name'] ?? "";
          phoneController.text = userDoc['phone'] ?? "";
          flatNumberController.text = userDoc['flatNumber'] ?? "";
          wingController.text = userDoc['wing'] ?? "";
          flatNumber = userDoc['flatNumber'] ?? "N/A";
          wing = userDoc['wing'] ?? "N/A";

          // Convert Firestore dynamic list to List<Map<String, String>>
          List<dynamic> rawFamilyMembers = userDoc['familyMembers'] ?? [];
          familyMembers = rawFamilyMembers.map((member) {
            return {
              'name': member['name'].toString(), // Ensure String type
              'phone': member['phone'].toString(),
            };
          }).toList();

          // Initialize controllers for family members
          familyNameControllers = familyMembers
              .map((m) => TextEditingController(text: m['name']))
              .toList();
          familyPhoneControllers = familyMembers
              .map((m) => TextEditingController(text: m['phone']))
              .toList();

          familyCount = familyMembers.length + 1;
        });
      }
    }
  }

  void updateProfile() async {
    setState(() {
      isLoading = true;
    });

    String newName = nameController.text.trim();
    String newPhone = phoneController.text.trim();
    String newFlatNumber = flatNumberController.text.trim();
    String newWing = wingController.text.trim();

    if (newFlatNumber.isEmpty || newWing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Flat Number and Wing are required.")),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      /// Ensure family members are formatted correctly before saving
      List<Map<String, String>> updatedFamilyMembers = [];
      for (int i = 0; i < familyNameControllers.length; i++) {
        String name = familyNameControllers[i].text.trim();
        String phone = familyPhoneControllers[i].text.trim();

        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Family Member name cannot be empty.")),
          );
          setState(() {
            isLoading = false;
          });
          return;
        }

        updatedFamilyMembers.add({'name': name, 'phone': phone});
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'name': newName,
        'phone': newPhone,
        'flatNumber': newFlatNumber,
        'wing': newWing, // This ensures wing is updated
        'familyMembers': updatedFamilyMembers,
        'familyCount': updatedFamilyMembers.length + 1,
      });

      // Update local state to reflect changes immediately
      setState(() {
        flatNumber = newFlatNumber;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: ${e.toString()}")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void addFamilyMember() {
    setState(() {
      Map<String, String> newMember = {
        'name': '',
        'phone': ''
      }; // Ensure correct type
      familyMembers.add(newMember);
      familyNameControllers.add(TextEditingController());
      familyPhoneControllers.add(TextEditingController());
      familyCount = familyMembers.length + 1;
    });
  }

  void removeFamilyMember(int index) {
    setState(() {
      familyMembers.removeAt(index);
      familyNameControllers.removeAt(index);
      familyPhoneControllers.removeAt(index);
      familyCount = familyMembers.length + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        actions: [
          IconButton(
              onPressed: isLoading ? null : updateProfile,
              icon: Icon(Icons.done))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue,
                child: Text(
                  flatNumber,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
                enabled: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                enabled: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: flatNumberController,
                decoration: const InputDecoration(labelText: "Flat Number"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: wingController,
                decoration: const InputDecoration(labelText: "Wing"),
              ),
              const SizedBox(height: 25),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Family Members: $familyCount",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12), // Add spacing for better UI
                  ElevatedButton.icon(
                    onPressed: addFamilyMember,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Family Member"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: List.generate(familyMembers.length, (index) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: familyNameControllers[index],
                          decoration:
                              const InputDecoration(labelText: "Member Name"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: familyPhoneControllers[index],
                          decoration:
                              const InputDecoration(labelText: "Phone Number"),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => removeFamilyMember(index),
                      ),
                    ],
                  );
                }),
              ),
              // const SizedBox(height: 20),
              // Text("Total Family Members: $familyCount",
              //     style: const TextStyle(
              //         fontSize: 16, fontWeight: FontWeight.bold)),
              // const SizedBox(height: 10),
              // ElevatedButton(
              //   onPressed: isLoading ? null : updateProfile,
              //   child: isLoading
              //       ? const CircularProgressIndicator()
              //       : const Text("Save Changes"),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
