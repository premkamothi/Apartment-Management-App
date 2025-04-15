import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UpdateCommitteeScreen extends StatefulWidget {
  const UpdateCommitteeScreen({Key? key}) : super(key: key);

  @override
  _UpdateCommitteeScreenState createState() => _UpdateCommitteeScreenState();
}

class _UpdateCommitteeScreenState extends State<UpdateCommitteeScreen> {
  final TextEditingController flatIdController = TextEditingController();
  final TextEditingController apartmentNameController = TextEditingController();
  bool isLoading = false;
  String oldFlatId = "";

  @override
  void initState() {
    super.initState();
    loadCommitteeDetails();
  }

  Future<void> loadCommitteeDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (userDoc.exists) {
      setState(() {
        oldFlatId = userDoc['flatId'] ?? "";
        flatIdController.text = oldFlatId;
        apartmentNameController.text = userDoc['apartmentName'] ?? "";
      });
    }
  }

  Future<void> updateCommitteeDetails() async {
    String newFlatId = flatIdController.text.trim();
    String newApartmentName = apartmentNameController.text.trim();

    if (newFlatId.isEmpty || newApartmentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Both Flat ID and Apartment Name are required.")),
      );
      return;
    }

    bool confirmUpdate = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Update"),
        content: const Text(
            "Are you sure you want to update the committee details?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Update")),
        ],
      ),
    );
    if (!confirmUpdate) return;

    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentReference oldCommitteeRef =
          firestore.collection('committees').doc(oldFlatId);
      DocumentReference newCommitteeRef =
          firestore.collection('committees').doc(newFlatId);

      if (newFlatId != oldFlatId) {
        // **Step 1: Migrate Users to New Flat ID**
        QuerySnapshot userSnapshots = await firestore
            .collection('users')
            .where('flatId', isEqualTo: oldFlatId)
            .get();

        for (var doc in userSnapshots.docs) {
          await doc.reference.update({
            'flatId': newFlatId,
            'apartmentName': newApartmentName,
          });
        }

        // **Step 2: Create New Committee Document**
        DocumentSnapshot oldCommitteeSnapshot = await oldCommitteeRef.get();
        if (oldCommitteeSnapshot.exists) {
          await newCommitteeRef.set(
              oldCommitteeSnapshot.data()!, SetOptions(merge: true));
        }

        // **Step 3: Delete Old Committee Document**
        await oldCommitteeRef.delete();
      } else {
        // If only apartmentName is changing, update the existing document
        await oldCommitteeRef.update({
          'apartmentName': newApartmentName,
          'updatedBy': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Committee details updated successfully.")),
      );
      Navigator.pop(context);
    } catch (e) {
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
      appBar: AppBar(title: const Text("Update Committee Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: flatIdController,
              decoration: const InputDecoration(labelText: "New Flat ID"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: apartmentNameController,
              decoration:
                  const InputDecoration(labelText: "New Apartment Name"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : updateCommitteeDetails,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Update Details"),
            ),
          ],
        ),
      ),
    );
  }
}
