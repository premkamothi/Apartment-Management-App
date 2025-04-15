import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'committee_member/create_committee_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController flatIdController = TextEditingController();

  String selectedRole = "Society Member";
  bool isLoading = false;

  void signUp() async {
    setState(() => isLoading = true);

    try {
      if (emailController.text.isEmpty ||
          passwordController.text.isEmpty ||
          nameController.text.isEmpty ||
          phoneController.text.isEmpty ||
          (selectedRole == "Society Member" && flatIdController.text.isEmpty)) {
        throw "All required fields must be filled.";
      }

      if (selectedRole == "Society Member") {
        QuerySnapshot flatQuery = await _firestore
            .collection("users")
            .where("flatId", isEqualTo: flatIdController.text.trim())
            .where("role", isEqualTo: "Committee Member")
            .get();

        if (flatQuery.docs.isEmpty) {
          throw "Invalid Flat ID! Only enter a Flat ID created by a Committee Member.";
        }
      }

      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String apartmentName = "";

      if (selectedRole == "Society Member") {
        final committeeDoc = await _firestore
            .collection("committees")
            .doc(flatIdController.text.trim())
            .get();

        if (committeeDoc.exists) {
          final data = committeeDoc.data();
          apartmentName = data?['apartmentName'] ?? "";
        }
      }

      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(),
        "role": selectedRole,
        "flatId":
        selectedRole == "Society Member" ? flatIdController.text.trim() : "",
        "flatNumber": "",
        "apartmentName": apartmentName,
        "wing": "",
        "familyMembers": [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup Successful!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      cursorColor: Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 500;

    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(controller: nameController, label: "Name"),
                const SizedBox(height: 12),
                _buildTextField(controller: emailController, label: "Email"),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: phoneController,
                  label: "Phone Number",
                  inputType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: passwordController,
                  label: "Password",
                  obscure: true,
                ),
                const SizedBox(height: 12),

                /// Role Dropdown
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: ["Society Member", "Committee Member"]
                      .map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRole = value);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: "Select Role",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),

                if (selectedRole == "Society Member") ...[
                  const SizedBox(height: 12),
                  _buildTextField(controller: flatIdController, label: "Flat ID"),
                ],
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: isLoading ? null : signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign Up", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
