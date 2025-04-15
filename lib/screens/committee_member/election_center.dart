import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ElectionCenter extends StatefulWidget {
  const ElectionCenter({super.key});

  @override
  State<ElectionCenter> createState() => _ElectionCenterState();
}

class _ElectionCenterState extends State<ElectionCenter> {
  bool isElectionStarted = false;
  bool hasElectionEnded = false;
  bool hasResultDeclared = false;
  List<Map<String, dynamic>> members = [];
  List<String> candidates = [];
  String flatId = "";

  @override
  void initState() {
    super.initState();
    _checkElectionStatus();
  }

  Future<void> _checkElectionStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!userDoc.exists) return;

    flatId = userDoc['flatId'] ?? "";
    DocumentSnapshot electionDoc = await FirebaseFirestore.instance
        .collection('elections')
        .doc(flatId)
        .get();

    if (electionDoc.exists) {
      setState(() {
        isElectionStarted = electionDoc['isElectionStarted'] ?? false;
        hasElectionEnded =
            electionDoc.exists && !(electionDoc['isElectionStarted'] ?? false);
        candidates = List<String>.from(electionDoc['candidates'] ?? []);
      });
    }
  }

  Future<void> _loadMembers() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!userDoc.exists) return;

    flatId = userDoc['flatId'] ?? "";
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('flatId', isEqualTo: flatId)
        .get();

    List<Map<String, dynamic>> loadedMembers = querySnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'],
        'flatNumber': doc['flatNumber'], // Ensure format: "102-A"
        'wing': doc['wing'],
      };
    }).toList();

    // Sorting: First by Wing (A → B → C), then by Flat Number (Ascending)
    loadedMembers.sort((a, b) {
      // Extract Wing character
      String wingA = a['flatNumber'].split('-').last; // A, B, C...
      String wingB = b['flatNumber'].split('-').last;

      // Compare by Wing first (A before B before C)
      int wingCompare = wingA.compareTo(wingB);
      if (wingCompare != 0) return wingCompare;

      // Extract numeric part of flat number
      int flatA = int.tryParse(a['flatNumber'].split('-').first) ?? 0;
      int flatB = int.tryParse(b['flatNumber'].split('-').first) ?? 0;

      // If the Wings are the same, sort by Flat Number (Ascending)
      return flatA.compareTo(flatB);
    });

    setState(() {
      members = loadedMembers;
    });
  }

  Future<void> _confirmCandidates() async {
    if (candidates.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Select at least 2 candidates to start the election!")),
      );
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    flatId = (await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get())['flatId'] ??
        "";
    if (flatId.isEmpty) return;

    await FirebaseFirestore.instance.collection('elections').doc(flatId).set({
      'isElectionStarted': true,
      'candidates': candidates,
      'electionId': flatId,
      'votedUsers': {},
      'resultDeclared': false,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hide_result_${flatId}_${user.uid}');

    setState(() {
      isElectionStarted = true;
      hasElectionEnded = false;
      hasResultDeclared = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Candidates Confirmed! Election Started!")));
  }

  Future<void> _endElection() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    flatId = (await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get())['flatId'] ??
        "";
    if (flatId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('elections')
        .doc(flatId)
        .update({
      'isElectionStarted': false,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    setState(() {
      isElectionStarted = false;
      hasElectionEnded = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Voting Ended!")));
  }

  Future<void> _declareResult() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    flatId = userDoc['flatId'] ?? "";
    if (flatId.isEmpty) return;

    final electionRef =
        FirebaseFirestore.instance.collection('elections').doc(flatId);
    final electionSnapshot = await electionRef.get();

    if (!electionSnapshot.exists) {
      // No election data exists — treat this as a reset/restart
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("No active election found.")));
      return;
    }

    final electionData = electionSnapshot.data() ?? {};
    final prefs = await SharedPreferences.getInstance();

    if (electionData['resultDeclared'] != true) {
      // ✅ Case: Declare result (even if election is already ended)
      await electionRef.update({
        'isElectionStarted': false,
        'resultDeclared': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await prefs.setBool('result_declared_$flatId', true);
      await prefs
          .remove('hide_result_${flatId}_${user.uid}'); // reset dismissal flag

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Result Declared!")));
    } else {
      // ✅ Case: Delete and reset election
      await electionRef.delete();
      await prefs.remove('result_declared_$flatId');
      await prefs.remove('hide_result_${flatId}_${user.uid}');

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Election Cycle Restarted!")));
    }

    setState(() {
      isElectionStarted = false;
      hasElectionEnded = false;
      hasResultDeclared = true;
      members.clear();
      candidates.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Election Center"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!isElectionStarted &&
                      (!hasElectionEnded || hasResultDeclared))
                    _electionButton("Select Candidates", Icons.how_to_vote,
                        Colors.blue, _loadMembers),
                  if (isElectionStarted)
                    _electionButton(
                        "End Voting", Icons.lock, Colors.red, _endElection),
                  if (hasElectionEnded && !hasResultDeclared)
                    _electionButton("Declare Result", Icons.emoji_events,
                        Colors.orange, _declareResult),
                ],
              ),
            ),
            SizedBox(height: 15),
            Expanded(
              child: members.isNotEmpty
                  ? ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        bool isSelected = candidates.contains(member['id']);
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(10),
                            title: Text(
                              member['name'],
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                "Flat: ${member['flatNumber']} - Wing: ${member['wing']}"),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.green : Colors.grey,
                              size: 28,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  candidates.remove(member['id']);
                                } else {
                                  candidates.add(member['id']);
                                }
                              });
                            },
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        "No members found",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
            ),
            if (members.isNotEmpty &&
                candidates.isNotEmpty &&
                !isElectionStarted)
              Padding(
                padding: const EdgeInsets.all(12),
                child: _electionButton("Confirm Candidates & Start Election",
                    Icons.check, Colors.green, _confirmCandidates),
              ),
          ],
        ),
      ),
    );
  }

  Widget _electionButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
