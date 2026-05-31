import 'package:flutter/material.dart';
import 'modern_event_program_screen.dart';

class EventProgramScreen extends StatefulWidget {
  const EventProgramScreen({super.key});

  @override
  State<EventProgramScreen> createState() => _EventProgramScreenState();
}

class _EventProgramScreenState extends State<EventProgramScreen> {
  @override
  Widget build(BuildContext context) {
    // Use the modern event program screen
    return const ModernEventProgramScreen();
  }
}
