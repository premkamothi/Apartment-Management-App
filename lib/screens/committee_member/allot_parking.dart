import 'package:flutter/material.dart';

class AllotParking extends StatefulWidget {
  const AllotParking({super.key});

  @override
  State<AllotParking> createState() => _AllotParkingState();
}

class _AllotParkingState extends State<AllotParking> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Allot Parking"),
      ),
    );
  }
}
