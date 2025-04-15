import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isCommitteeMember = false;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = userDoc.data()?['role'] ?? '';
    if (mounted) {
      setState(() {
        isCommitteeMember = role == 'Committee Member';
      });
    }
  }

  Future<void> _showEditDialog(BuildContext context, String docId, String currentTitle, String currentMessage) async {
    final titleController = TextEditingController(text: currentTitle);
    final messageController = TextEditingController(text: currentMessage);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Notification"),
        content: SizedBox(
          height: 200,
          child: Column(
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title")),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: messageController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(labelText: "Message"),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('notifications').doc(docId).update({
                'title': titleController.text.trim(),
                'message': messageController.text.trim(),
                'updatedAt': Timestamp.now(),
              });
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(String docId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['updatedAt'] ?? aData['timestamp']) as Timestamp;
            final bTime = (bData['updatedAt'] ?? bData['timestamp']) as Timestamp;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final timestamp = data['timestamp'] as Timestamp;
              final updatedAt = data['updatedAt'] as Timestamp?;
              final dateTime = (updatedAt ?? timestamp).toDate();

              final formattedDate = DateFormat('MMM dd').format(dateTime);
              final formattedTime = DateFormat('hh:mm a').format(dateTime);
              final timeLabel = updatedAt != null ? "Updated" : "Sent";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0),
                    child: Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Slidable(
                    key: ValueKey(doc.id),
                    closeOnScroll: true, // closes any open slidable on scroll
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(), // nice bounce effect
                      extentRatio: 0.4,
                      children: [
                        SlidableAction(
                          onPressed: (_) {}, // non-destructive
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black,
                          icon: Icons.access_time,
                          label: "$timeLabel: $formattedTime",
                          autoClose: true, // ensures it closes on interaction
                        ),
                      ],
                    ),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications, color: Colors.blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data['message'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            if (isCommitteeMember)
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(context, doc.id, data['title'], data['message']);
                                  } else if (value == 'delete') {
                                    _deleteNotification(doc.id);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'edit', child: Text("Edit")),
                                  PopupMenuItem(value: 'delete', child: Text("Delete")),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                ],
              );
            },
          );
        },
      ),
    );
  }
}
