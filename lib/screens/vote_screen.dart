import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VoteScreen extends StatefulWidget {
  const VoteScreen({super.key});

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  List<Map<String, dynamic>> candidates = [];
  String? selectedCandidate;
  bool hasVoted = false;
  String? electionId;
  bool isLoading = true; // Loading state

  @override
  void initState() {
    super.initState();
    _fetchElectionData();
  }

  Future<void> _fetchElectionData() async {
    setState(() => isLoading = true); // Start loading
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    String flatId = userDoc['flatId'] ?? "";

    DocumentSnapshot electionDoc = await FirebaseFirestore.instance
        .collection('elections')
        .doc(flatId)
        .get();
    print("Election Data: ${electionDoc.data()}");

    if (electionDoc.exists) {
      Map<String, dynamic>? data = electionDoc.data() as Map<String, dynamic>?;

      if (data == null || !(data['isElectionStarted'] ?? false)) {
        setState(() {
          candidates = [];
          isLoading = false;
        });
        return;
      }

      electionId = data['electionId']; // Ensure election ID is retrieved

      List<String> candidateIds = List<String>.from(data['candidates'] ?? []);
      List<Map<String, dynamic>> loadedCandidates = [];

      for (String id in candidateIds) {
        DocumentSnapshot userSnap =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (userSnap.exists) {
          loadedCandidates.add({'id': id, 'name': userSnap['name']});
        }
      }

      if (mounted) {
        setState(() {
          candidates = loadedCandidates;
          isLoading = false;
        });
      }

      _checkIfVoted(flatId);
    } else {
      setState(() {
        candidates = [];
        isLoading = false; // Stop loading
      });
    }
  }

  Future<void> _checkIfVoted(String flatId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || electionId == null) return;

    DocumentSnapshot electionDoc = await FirebaseFirestore.instance
        .collection('elections')
        .doc(flatId)
        .get();

    if (electionDoc.exists) {
      Map<String, dynamic>? votedUsers =
          electionDoc['votedUsers'] as Map<String, dynamic>? ?? {};

      if (votedUsers.containsKey(user.uid) &&
          votedUsers[user.uid] == electionId) {
        setState(() {
          hasVoted = true;
        });
      }
    }
  }

  Future<void> _submitVote() async {
    if (selectedCandidate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a candidate before voting!")),
      );
      return;
    }

    bool confirm = await _showConfirmationDialog();
    if (!confirm) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || electionId == null) return;

    String flatId = (await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get())['flatId'] ??
        "";
    DocumentReference electionRef =
        FirebaseFirestore.instance.collection('elections').doc(flatId);

    await electionRef.update({
      'votes.$selectedCandidate': FieldValue.increment(1),
      'votedUsers.${user.uid}':
          electionId, // Mark user as voted in this election
    });

    setState(() {
      hasVoted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Vote submitted successfully!")),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Confirm Vote"),
            content: Text("Are you sure you want to vote for this candidate?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("Cancel")),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Confirm"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Vote"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchElectionData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (candidates.isNotEmpty)
              Text("Select a candidate to vote:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            // if (isLoading)
            //   Center(child: CircularProgressIndicator()) // Show loading indicator
            if (candidates.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 180.0),
                  child: Text(
                    "No election is currently active.",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                      child: RadioListTile<String>(
                        title: Text(candidate['name'],
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        value: candidate['id'],
                        groupValue: selectedCandidate,
                        onChanged: hasVoted
                            ? null
                            : (value) =>
                                setState(() => selectedCandidate = value),
                        activeColor: Colors.green,
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 20),
            if (candidates.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: hasVoted ? null : _submitVote,
                  icon: Icon(Icons.how_to_vote),
                  label: Text(hasVoted ? "Already Voted" : "Submit Vote"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasVoted ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
