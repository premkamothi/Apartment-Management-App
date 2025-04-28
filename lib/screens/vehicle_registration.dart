import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VehicleManager extends StatefulWidget {
  const VehicleManager({super.key});

  @override
  State<VehicleManager> createState() => _VehicleManagerState();
}

class _VehicleManagerState extends State<VehicleManager> {
  final TextEditingController _vehicleNameController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();

  bool _isLoading = false;
  String? _editingDocId;

  Future<String?> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc['name'];
  }

  Future<void> _submitVehicle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in!')),
      );
      return;
    }

    final vehicleName = _vehicleNameController.text.trim();
    final vehicleNumber = _vehicleNumberController.text.trim();

    if (vehicleName.isEmpty || vehicleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final flatId = userDoc['flatId'] ?? '';
      final flatNumber = userDoc['flatNumber'] ?? '';
      final userName = userDoc['name'] ?? '';

      final vehicleData = {
        'vehicleName': vehicleName,
        'vehicleNumber': vehicleNumber,
        'userName': userName,
        'flatId': flatId,
        'flatNumber': flatNumber,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_editingDocId != null) {
        // Update existing document
        await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(userName)
            .collection('vehicles')
            .doc(_editingDocId)
            .update(vehicleData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated successfully!')),
        );
      } else {
        // Add new document
        await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(userName)
            .collection('vehicles')
            .add(vehicleData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle saved successfully!')),
        );
      }

      _vehicleNameController.clear();
      _vehicleNumberController.clear();
      _editingDocId = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteVehicle(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc['name'] ?? '';

      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(userName)
          .collection('vehicles')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _editVehicle(Map<String, dynamic> data, String docId) {
    _vehicleNameController.text = data['vehicleName'] ?? '';
    _vehicleNumberController.text = data['vehicleNumber'] ?? '';
    setState(() {
      _editingDocId = docId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Vehicle Manager")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _vehicleNameController,
                decoration: const InputDecoration(
                  labelText: "Vehicle Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(
                  labelText: "Vehicle Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Icon(_editingDocId == null ? Icons.save : Icons.update),
                  label: Text(
                    _isLoading
                        ? "Processing..."
                        : _editingDocId == null
                        ? "Submit"
                        : "Update Vehicle",
                  ),
                  onPressed: _isLoading ? null : _submitVehicle,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Your Vehicles",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (user != null)
                FutureBuilder<String?>(
                  future: _fetchUserName(),
                  builder: (context, nameSnapshot) {
                    if (nameSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!nameSnapshot.hasData || nameSnapshot.data == null) {
                      return const Text('No vehicles registered yet.');
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('vehicles')
                          .doc(nameSnapshot.data)
                          .collection('vehicles')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text("No vehicles registered.");
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.directions_car, color: Colors.blueAccent),
                                title: Text(
                                  data['vehicleName'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Number: ${data['vehicleNumber'] ?? ''}"),
                                    Text("Flat: ${data['flatNumber'] ?? ''}"),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.green),
                                      onPressed: () => _editVehicle(data, doc.id),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteVehicle(doc.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
