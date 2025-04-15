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
  String name = "", role = "", flatId = "", currentApartmentName = "", email = "", flatNumber = "";
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

  void _fetchUserProblems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('problems')
        .where('flatId', isEqualTo: flatId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final allProblems = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).where((problem) => !_dismissedProblemIds.contains(problem['id'])).toList();

      setState(() => _problems = allProblems);
    });
  }

  void _loadDismissedProblemIds() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'dismissed_problems_${FirebaseAuth.instance.currentUser?.uid ?? ""}';
    final ids = prefs.getStringList(key) ?? [];
    setState(() => _dismissedProblemIds = ids);
  }

  Future<void> _dismissProblemTile(String problemId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'dismissed_problems_${FirebaseAuth.instance.currentUser?.uid ?? ""}';
    _dismissedProblemIds.add(problemId);
    await prefs.setStringList(key, _dismissedProblemIds);
    _fetchUserProblems(); // Refresh UI
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
        final wasResultDeclared = prefs.getBool('result_declared_$flatId') ?? false;
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
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) {
          try {
            return HomeScreen();
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
    Center(child: Text("Welcome to the Society App!", style: TextStyle(fontSize: 20))),
    NotificationScreen(),
    Center(child: Text("Maintenance Payments (Coming Soon)", style: TextStyle(fontSize: 20))),
    NotificationScreen(), // Optional duplicate
    RaiseProblems(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.rule_rounded),
              title: const Text("Rules & Regulations"),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Rule())),
            ),
            ListTile(
              leading: const Icon(Icons.motorcycle_outlined),
              title: const Text("Vehicle Registration"),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VehicleRegistration())),
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom),
              title: const Text("Member Details"),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MemberDetail())),
            ),
            if (role == "Committee Member") const Divider(),
            if (role == "Committee Member")
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text("Create Committee"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreateCommitteeScreen())),
              ),
            if (role == "Committee Member")
              ListTile(
                leading: const Icon(Icons.how_to_vote_rounded),
                title: const Text("Election Center"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ElectionCenter())),
              ),
            if (role == "Committee Member")
              ListTile(
                leading: const Icon(Icons.campaign),
                title: const Text("Send Notification"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SendNotification())),
              ),
            if (role == "Committee Member")
              ListTile(
                leading: const Icon(Icons.local_parking),
                title: const Text("Parking Allotment"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AllotParking())),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedIndex == 0 && showResultTile)
            Slidable(
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
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: const Icon(Icons.emoji_events, color: Colors.deepOrange),
                  title: const Text(
                    "Election results are available!",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Check out who won the election."),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ElectionResult()),
                    );
                  },
                ),
              ),
            )


          else if (_selectedIndex == 0 && isElectionActive)
            Card(
              color: Colors.blue.shade100,
              margin: EdgeInsets.all(10),
              child: ListTile(
                leading: Icon(Icons.how_to_vote, color: Colors.blue),
                title: Text("Election is active now!"),
                subtitle: Text("Give your vote to your preferred candidate."),
                trailing: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VoteScreen())),
                  child: Text("Vote", style: TextStyle(color: Colors.blue)),
                ),
              ),
            ),
          Expanded(
            child: _selectedIndex == 0
                ? ListView.builder(
              itemCount: _problems.length,
              itemBuilder: (context, index) {
                final problem = _problems[index];
                Widget _buildProblemCard(Map<String, dynamic> problem) {
                  final DateTime problemDateTime = problem['timestamp']?.toDate() ?? DateTime.now();
                  final formattedDate = DateFormat('MMM dd').format(problemDateTime);
                  final formattedTime = DateFormat('hh:mm a').format(problemDateTime);

                  return Slidable(
                    key: ValueKey(problem['id']),
                    startActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.3,
                      children: [
                        SlidableAction(
                          onPressed: (_) {},
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.black87,
                          label: "$formattedDate\n$formattedTime",
                          autoClose: true,
                          flex: 1,
                        ),
                      ],
                    ),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      dismissible: DismissiblePane(
                        onDismissed: () => _dismissProblemTile(problem['id']),
                      ),
                      children: [
                        SlidableAction(
                          onPressed: (_) => _dismissProblemTile(problem['id']),
                          backgroundColor: Colors.red.shade300,
                          icon: Icons.delete,
                          label: 'Dismiss',
                        ),
                      ],
                    ),
                    child: InkWell(
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
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// First Row: Icon + Title + Raised By (all in a line)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.report_problem_outlined, color: Colors.blue, size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
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
                                        const SizedBox(width: 10),
                                        Text(
                                          "Raised by: ${problem['name'] ?? 'Unknown'}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              /// Second Row: Description preview (only one line)
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
                    )


                  );
                }

                return _buildProblemCard(problem);
              },
            )
                : _pages[_selectedIndex],
          ),


        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
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

  String _getTitle(int index) {
    return [
      "Home",
      "Notifications",
      "Pay Maintenances",
      "Notice",
      "Raise Problem"
    ][index];
  }
}
