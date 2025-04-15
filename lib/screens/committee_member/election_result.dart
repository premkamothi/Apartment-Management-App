import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ElectionResult extends StatefulWidget {
  const ElectionResult({super.key});

  @override
  State<ElectionResult> createState() => _ElectionResultState();
}

class _ElectionResultState extends State<ElectionResult> {
  List<Map<String, dynamic>> candidates = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchElectionResults();
  }

  Future<void> _fetchElectionResults() async {
    setState(() => isLoading = true);

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

    if (electionDoc.exists) {
      Map<String, dynamic> data = electionDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> votes = data['votes'] ?? {};

      List<Map<String, dynamic>> loadedCandidates = [];

      for (String candidateId in votes.keys) {
        DocumentSnapshot userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(candidateId)
            .get();
        if (userSnap.exists) {
          loadedCandidates.add({
            'id': candidateId,
            'name': userSnap['name'],
            'voteCount': votes[candidateId] ?? 0,
          });
        }
      }

      // Sort candidates by vote count descending
      loadedCandidates.sort((a, b) => b['voteCount'].compareTo(a['voteCount']));

      // Find the highest vote count
      int maxVote =
          loadedCandidates.isNotEmpty ? loadedCandidates.first['voteCount'] : 0;

      // Mark all winners (for ties)
      for (var candidate in loadedCandidates) {
        candidate['isWinner'] = candidate['voteCount'] == maxVote;
      }

      //  Update role to "Committee Member" for the winners
      for (var winner in loadedCandidates.where((c) => c['isWinner'] == true)) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(winner['id'])
            .update({'role': 'Committee Member'});
      }

      setState(() {
        candidates = loadedCandidates;
        isLoading = false;
      });
    } else {
      setState(() {
        candidates = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Election Result"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : candidates.isEmpty
              ? const Center(
                  child: Text(
                    "No election results available.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: candidates.length,
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final isWinner = candidate['isWinner'] ?? false;
                            final voteCount = candidate['voteCount'] ?? 0;

                            return Card(
                              color: isWinner ? Colors.green.shade100 : null,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                child: Row(
                                  children: [
                                    // Name on the left
                                    Expanded(
                                      child: Text(
                                        candidate['name'],
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),

                                    // Center Trophy Icon (only for winners)
                                    if (isWinner)
                                      const Icon(Icons.emoji_events,
                                          color: Colors.orange, size: 28)
                                    else
                                      const SizedBox(width: 28),

                                    const SizedBox(width: 10),

                                    // Vote count on the right
                                    Text(
                                      "$voteCount ${voteCount == 1 ? "Vote" : "Votes"}",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
