import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Rule extends StatefulWidget {
  const Rule({super.key});

  @override
  State<Rule> createState() => _RuleState();
}

class _RuleState extends State<Rule> {
  bool isCommitteeMember = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        isCommitteeMember = userDoc['role'] == 'Committee Member';
        isLoading = false;
      });
    }
  }

  Future<void> _showRuleDialog({String? docId, String? currentText}) async {
    TextEditingController controller = TextEditingController(text: currentText ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(docId == null ? "Add Rule" : "Update Rule"),
        content: SizedBox(
          width: 300,
          height: 120,
          child: Column(
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Enter rule...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                if (docId == null) {
                  await FirebaseFirestore.instance.collection('rules').add({
                    'text': text,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                } else {
                  await FirebaseFirestore.instance.collection('rules').doc(docId).update({
                    'text': text,
                  });
                }
              }
              Navigator.pop(context);
            },
            child: Text(docId == null ? "Add" : "Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRule(String docId) async {
    await FirebaseFirestore.instance.collection('rules').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Rules & Regulations"),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rules')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: Text("No rules found."));
          final rules = snapshot.data!.docs;

          return ListView.builder(
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final doc = rules[index];
              final ruleText = doc['text'];

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
                child: ListTile(
                  leading: Icon(Icons.circle, size: 10, color: Colors.black54), // Bullet icon
                  title: Text(ruleText),
                  trailing: isCommitteeMember
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showRuleDialog(docId: doc.id, currentText: ruleText),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRule(doc.id),
                      ),
                    ],
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isCommitteeMember
          ? FloatingActionButton(
        onPressed: () => _showRuleDialog(),
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      )
          : null,
    );
  }
}
