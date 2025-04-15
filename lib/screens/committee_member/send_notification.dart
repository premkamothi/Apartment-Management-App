import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SendNotification extends StatefulWidget {
  const SendNotification({super.key});

  @override
  State<SendNotification> createState() => _SendNotificationState();
}

class _SendNotificationState extends State<SendNotification> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventMessageController = TextEditingController();

  Future<void> _showNotificationDialog() async {
    _titleController.clear();
    _messageController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Notification"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 250,
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  maxLength: 300,
                  expands: true,
                  decoration: const InputDecoration(
                    labelText: "Message",
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Send"),
            onPressed: () async {
              final title = _titleController.text.trim();
              final message = _messageController.text.trim();

              if (title.isEmpty || message.isEmpty) return;

              await FirebaseFirestore.instance.collection('notifications').add({
                'title': title,
                'message': message,
                'timestamp': Timestamp.now(),
                'type': 'general',
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Notification sent")),
              );

              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEventDialog() async {
    _eventTitleController.clear();
    _eventMessageController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Event Notification"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 320,
          child: Column(
            children: [
              TextField(
                controller: _eventTitleController,
                decoration: const InputDecoration(
                  labelText: "Event Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _eventMessageController,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: "Event Details",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Send Event"),
            onPressed: () async {
              final title = _eventTitleController.text.trim();
              final message = _eventMessageController.text.trim();

              if (title.isEmpty || message.isEmpty) return;

              await FirebaseFirestore.instance.collection('notifications').add({
                'title': title,
                'message': message,
                'timestamp': Timestamp.now(),
                'type': 'event',
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Event notification sent")),
              );

              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showExpenseDialog() async {
    _eventTitleController.clear();
    _eventMessageController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Expense Report"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 320,
          child: Column(
            children: [
              TextField(
                controller: _eventTitleController,
                decoration: const InputDecoration(
                  labelText: "Expense Report Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _eventMessageController,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: "Expense Report",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Send Report"),
            onPressed: () async {
              final title = _eventTitleController.text.trim();
              final message = _eventMessageController.text.trim();

              if (title.isEmpty || message.isEmpty) return;

              await FirebaseFirestore.instance.collection('notifications').add({
                'title': title,
                'message': message,
                'timestamp': Timestamp.now(),
                'type': 'event',
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Expense Report sent")),
              );

              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Send Notifications"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.campaign, color: Colors.blue),
              title: const Text("Send a Message", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Tap here to send a notification to all members."),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showNotificationDialog,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.event, color: Colors.deepOrange),
              title: const Text("Send an Event Information", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Tap here to send details about an upcoming event."),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showEventDialog,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.currency_rupee, color: Colors.green),
              title: const Text("Send an Expense Report", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Tap here to send Expense Report."),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showExpenseDialog,
            ),
          ),
        ],
      ),
    );
  }
}
