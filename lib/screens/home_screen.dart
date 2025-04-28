import 'package:apartment/screens/committee_member/allot_parking.dart';
import 'package:apartment/screens/member_detail.dart';
import 'package:apartment/screens/raise_problems.dart';
import 'package:apartment/screens/rule.dart';
import 'package:apartment/screens/committee_member/send_notification.dart';
import 'package:apartment/screens/vehicle_registration.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'committee_member/election_center.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'committee_member/create_committee_screen.dart';
import 'notification_screen.dart';
import 'vote_screen.dart';
import 'committee_member/election_result.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String name = "",
      role = "",
      flatId = "",
      currentApartmentName = "",
      email = "",
      flatNumber = "";
  int _selectedIndex = 0;
  bool isElectionActive = false;
  bool showResultTile = false;
  List<Map<String, dynamic>> _problems = [];
  List<String> _dismissedProblemIds = [];
  final ScrollController _scrollController = ScrollController();

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    _listenToUserData();
    _loadDismissedProblemIds();
  }

  Widget _buildHomeTile(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.blue.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.blue),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile() {
    return Slidable(
      key: const ValueKey('result_tile'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        dismissible: DismissiblePane(onDismissed: _hideResultTileForUser),
        children: [
          SlidableAction(
            onPressed: (_) => _hideResultTileForUser(),
            backgroundColor: Colors.red.shade300,
            icon: Icons.delete,
            label: 'Dismiss',
          ),
        ],
      ),
      child: Card(
        color: Colors.orange.shade100,
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: const Icon(Icons.emoji_events, color: Colors.deepOrange),
          title: const Text("Election results are available!",
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Check out who won the election."),
          onTap: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => ElectionResult()));
          },
        ),
      ),
    );
  }

  Widget _buildElectionActiveTile() {
    return Card(
      color: Colors.blue.shade100,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.how_to_vote, color: Colors.blue),
        title: const Text("Election is active now!"),
        subtitle: const Text("Give your vote to your preferred candidate."),
        trailing: TextButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => VoteScreen())),
          child: const Text("Vote", style: TextStyle(color: Colors.blue)),
        ),
      ),
    );
  }

  Widget _buildProblemCard(Map<String, dynamic> problem) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(problem['title'] ?? 'No Title'),
            content: Text(problem['description'] ?? 'No Description'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.report_problem_outlined,
                      color: Colors.blue, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      problem['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      setState(() {
                        _problems.removeWhere((p) => p['id'] == problem['id']);
                      });
                      await _dismissProblemTile(problem['id']);
                    },
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Raised by: ${problem['name'] ?? 'Unknown'}",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                problem['description'] ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fetchUserProblems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    // Listen for dismissed problems in real-time too, in case they change
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((userSnapshot) {
      if (!userSnapshot.exists) return;

      List<String> dismissedProblemIds =
          List<String>.from(userSnapshot.data()?['dismissedProblems'] ?? []);

      FirebaseFirestore.instance
          .collection('problems')
          .where('flatId', isEqualTo: flatId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;

        final allProblems = snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            })
            .where((problem) => !dismissedProblemIds.contains(problem['id']))
            .toList();

        setState(() {
          for (var problem in allProblems) {
            final index = _problems.indexWhere((p) => p['id'] == problem['id']);
            if (index == -1) {
              _problems.add(problem); // New problem
            } else {
              _problems[index] = problem; // Updated problem
            }
          }

          // Remove problems that no longer exist in Firestore or were dismissed
          _problems.removeWhere(
              (problem) => !allProblems.any((p) => p['id'] == problem['id']));
        });
      });
    });
  }

  void _loadDismissedProblemIds() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'dismissed_problems_${FirebaseAuth.instance.currentUser?.uid ?? ""}';
    final ids = prefs.getStringList(key) ?? [];
    setState(() => _dismissedProblemIds = ids);
  }

  Future<void> _dismissProblemTile(String problemId) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'dismissed_problems_${FirebaseAuth.instance.currentUser?.uid ?? ""}';

    _dismissedProblemIds.add(problemId);
    await prefs.setStringList(key, _dismissedProblemIds);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'dismissedProblems': FieldValue.arrayUnion([problemId]),
        });
      } catch (e) {
        print("Error dismissing problem: $e");
      }
    }
  }

  void _listenToUserData() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userDoc) {
      if (!userDoc.exists || !mounted) return;

      final newFlatId = userDoc['flatId'] ?? "";

      final shouldFetchProblems = flatId != newFlatId;

      setState(() {
        name = userDoc['name'] ?? "";
        role = userDoc['role'] ?? "";
        flatId = newFlatId;
        email = userDoc['email'] ?? "";
        flatNumber = userDoc['flatNumber'] ?? "";
      });

      if (newFlatId.isNotEmpty) {
        _apartmentNameData(newFlatId);
        _listenToElectionStatus();
        if (shouldFetchProblems) {
          _fetchUserProblems();
        }
      }
    });
  }

  void _apartmentNameData(String flatId) {
    FirebaseFirestore.instance
        .collection('committees')
        .doc(flatId)
        .snapshots()
        .listen((userDoc) {
      if (!mounted || !userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          currentApartmentName = data['apartmentName'] ?? "Not Assigned";
        });
      }
    });
  }

  void _listenToElectionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('elections')
        .doc(flatId)
        .snapshots()
        .listen((electionDoc) async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final dismissKey = 'hide_result_${flatId}_${user.uid}';
      final isDismissed = prefs.getBool(dismissKey) ?? false;

      if (!electionDoc.exists) {
        final wasResultDeclared =
            prefs.getBool('result_declared_$flatId') ?? false;
        setState(() {
          isElectionActive = false;
          showResultTile = wasResultDeclared && !isDismissed;
        });
        return;
      }

      final data = electionDoc.data();
      bool electionStarted = data?['isElectionStarted'] ?? false;
      bool resultDeclared = data?['resultDeclared'] ?? false;

      await prefs.setBool('result_declared_$flatId', resultDeclared);

      setState(() {
        isElectionActive = electionStarted;
        showResultTile = resultDeclared && !isDismissed;
      });
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) {
      try {
        return LoginScreen();
      } catch (e) {
        print("Error navigating to HomeScreen: $e");
        return Scaffold(body: Center(child: Text('Error loading HomeScreen')));
      }
    }));
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _hideResultTileForUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_result_${flatId}_${user.uid}', true);
    setState(() {
      showResultTile = false;
    });
  }

  final List<Widget> _pages = [
    Center(
        child: Text("Welcome to the Society App!",
            style: TextStyle(fontSize: 20))),
    NotificationScreen(),
    Center(
        child: Text("Maintenance Payments (Coming Soon)",
            style: TextStyle(fontSize: 20))),
    NotificationScreen(), // Optional duplicate
    RaiseProblems(),
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_getTitle(_selectedIndex)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(flatId, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(currentApartmentName, style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: UserAccountsDrawerHeader(
                accountName: Text(name),
                accountEmail: Text(email),
                currentAccountPicture: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 35,
                      child: Text(flatNumber, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    Positioned(
                      top: -4,
                      right: -1,
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen())),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.edit, size: 14, color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text("Home"),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: ScrollConfiguration(
        behavior: NoGlowScrollBehavior(), // disable scroll glow + bar
        child: SafeArea(
          child: _selectedIndex == 0
              ? SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   SizedBox(height: 6),
                  // Main Grid for all users
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0, // Perfect Square
                    children: [
                      _buildHomeTile(Icons.rule_rounded, "Rules & Regulations", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => Rule()));
                      }),
                      _buildHomeTile(Icons.motorcycle_outlined, "Vehicle Registration", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleManager()));
                      }),
                      _buildHomeTile(Icons.family_restroom, "Member Details", () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => MemberDetail()));
                      }),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Committee Member Exclusive Grid
                  if (role == "Committee Member") ...[
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      children: [
                        _buildHomeTile(Icons.group_add, "Create Committee", () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CreateCommitteeScreen()));
                        }),
                        _buildHomeTile(Icons.how_to_vote_rounded, "Election Center", () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ElectionCenter()));
                        }),
                        _buildHomeTile(Icons.local_parking, "Parking Allotment", () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AllotParking()));
                        }),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],

                  // Raised Problems Section
                  Text("Raised Problems", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _problems.reversed.length,
                      itemBuilder: (context, index) {
                        final reversedProblems = _problems.reversed.toList();
                        final problem = reversedProblems[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: SizedBox(
                            width: 280,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _buildProblemCard(problem),
                                Positioned(
                                  top: -10,
                                  right: 10,
                                  child: Text(
                                    DateFormat('hh:mm a').format(
                                      problem['timestamp']?.toDate() ?? DateTime.now(),
                                    ),
                                    style: TextStyle(fontSize: 11, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 20),

                  // Election Updates Section
                  Text("Election Updates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  if (!showResultTile && !isElectionActive)
                    Center(child: Text("No election updates.", style: TextStyle(color: Colors.grey))),
                  if (showResultTile) _buildResultTile(),
                  if (isElectionActive) _buildElectionActiveTile(),

                ],
              ),
            ),
          )
              : _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notice"),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: "Pay Maintenance"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notice"),
          BottomNavigationBarItem(icon: Icon(Icons.front_hand_rounded), label: "Raise Problem"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

String _getTitle(int index) {
  return [
    "Home",
    "Notification",
    "Pay Maintenance",
    "Notice",
    "Raise Problem"
  ][index];
}