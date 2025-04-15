import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VehicleRegistration extends StatefulWidget {
  const VehicleRegistration({super.key});

  @override
  State<VehicleRegistration> createState() => _VehicleRegistrationState();
}

class _VehicleRegistrationState extends State<VehicleRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  bool isLoading = true;
  String name = '';
  String flatNumber = '';
  String flatId = '';
  String vehicleType = '';
  final List<String> vehicleTypes = ['Car', 'Bike', 'Scooter', 'Other'];

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final data = userDoc.data();
    if (data != null && mounted) {
      setState(() {
        name = data['name'] ?? '';
        flatNumber = data['flatNumber'] ?? '';
        flatId = data['flatId'] ?? '';
        isLoading = false;
      });
    }
  }

  Future<void> registerVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final vehicleData = {
      'vehicleType': vehicleType,
      'vehicleName': _vehicleNameController.text.trim(),
      'vehicleNumber': _vehicleNumberController.text.trim(),
      'name': name,
      'flatNumber': flatNumber,
      'flatId': flatId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(user.uid)
        .collection('userVehicles')
        .add(vehicleData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Vehicle registered successfully')),
      );
      _formKey.currentState!.reset();
      _vehicleNameController.clear();
      _vehicleNumberController.clear();
      setState(() => vehicleType = '');
    }
  }

  Future<void> deleteVehicle(String docId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(userId)
        .collection('userVehicles')
        .doc(docId)
        .delete();
  }

  void showEditDialog(String docId, Map<String, dynamic> data) {
    final TextEditingController editName =
    TextEditingController(text: data['vehicleName']);
    final TextEditingController editNumber =
    TextEditingController(text: data['vehicleNumber']);
    String editType = data['vehicleType'];

    final _editFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Vehicle"),
        content: Form(
          key: _editFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: editType,
                items: vehicleTypes
                    .map((type) =>
                    DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (val) => editType = val!,
                validator: (val) =>
                val == null || val.isEmpty ? 'Select type' : null,
                decoration: const InputDecoration(labelText: 'Vehicle Type'),
              ),
              TextFormField(
                controller: editName,
                decoration: const InputDecoration(labelText: 'Vehicle Name'),
                validator: (val) =>
                val == null || val.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: editNumber,
                decoration:
                const InputDecoration(labelText: 'Vehicle Number'),
                validator: (val) =>
                val == null || val.isEmpty ? 'Enter number' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_editFormKey.currentState!.validate()) return;

              await FirebaseFirestore.instance
                  .collection('vehicles')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('userVehicles')
                  .doc(docId)
                  .update({
                'vehicleType': editType,
                'vehicleName': editName.text.trim(),
                'vehicleNumber': editNumber.text.trim(),
              });

              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Vehicle Registration")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: vehicleType.isNotEmpty ? vehicleType : null,
                      items: vehicleTypes
                          .map((type) => DropdownMenuItem(
                          value: type, child: Text(type)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => vehicleType = val!),
                      validator: (val) =>
                      val == null || val.isEmpty
                          ? 'Select vehicle type'
                          : null,
                      decoration: const InputDecoration(
                          labelText: 'Vehicle Type'),
                    ),
                    TextFormField(
                      controller: _vehicleNameController,
                      decoration: const InputDecoration(
                          labelText: 'Vehicle Name'),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter vehicle name'
                          : null,
                    ),
                    TextFormField(
                      controller: _vehicleNumberController,
                      decoration: const InputDecoration(
                          labelText: 'Vehicle Number'),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter vehicle number'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: registerVehicle,
                      child: const Text('Register Vehicle'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Your Vehicles",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (userId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('vehicles')
                      .doc(userId)
                      .collection('userVehicles')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    final vehicles = snapshot.data?.docs ?? [];

                    if (vehicles.isEmpty) {
                      return const Text("No vehicles registered.");
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final doc = vehicles[index];
                        final data =
                        doc.data() as Map<String, dynamic>;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              data['vehicleType'] == 'Car'
                                  ? Icons.directions_car
                                  : data['vehicleType'] == 'Bike'
                                  ? Icons.motorcycle
                                  : Icons.directions_transit,
                            ),
                            title: Text(
                                '${data['vehicleType']} - ${data['vehicleName']}'),
                            subtitle: Text(
                                'Number: ${data['vehicleNumber']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => showEditDialog(
                                      doc.id, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () =>
                                      deleteVehicle(doc.id),
                                ),
                              ],
                            ),
                          ),
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
