import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RaiseProblems extends StatefulWidget {
  const RaiseProblems({super.key});

  @override
  State<RaiseProblems> createState() => _RaiseProblemsState();
}

class _RaiseProblemsState extends State<RaiseProblems> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitProblem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final flatId = userDoc['flatId'] ?? '';
      final name = userDoc['name'] ?? '';

      await FirebaseFirestore.instance.collection('problems').add({
        'userId': user.uid,
        'flatId': flatId,
        'name': name,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Problem submitted successfully!')),
      );

      _titleController.clear();
      _descriptionController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  "Tell us what an issue you're facing",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "Problem Title",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.help_center),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Please enter a title" : null,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "Problem Description",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Please enter a description" : null,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitProblem,
                    label: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Submit Problem"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
