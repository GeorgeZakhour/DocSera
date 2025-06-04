import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:docsera/screens/doctors/doctor_panel/doctor_drawer.dart';
import 'package:flutter/material.dart';
import 'package:docsera/app/const.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class DoctorAppointments extends StatefulWidget {
  final Map<String, dynamic>? doctorData;

  const DoctorAppointments({Key? key, this.doctorData}) : super(key: key);

  @override
  _DoctorAppointmentsState createState() => _DoctorAppointmentsState();
}

class _DoctorAppointmentsState extends State<DoctorAppointments> {
  bool _isCalendarView = true; // ✅ Toggle between weekly & list view
  bool _showFreeSlots = false; // ✅ Track "Show Free Slots" button state
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? doctorId;
  Map<String, List<Map<String, dynamic>>> _appointmentsByDay = {}; // Appointments Grouped by Date


  @override
  void initState() {
    super.initState();
    _fetchDoctorAppointments();
  }

  /// **🔹 Fetch Appointments from Firestore**
  Future<void> _fetchDoctorAppointments() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    doctorId = prefs.getString('doctorId');

    if (doctorId == null) {
      print("❌ Doctor ID not found.");
      return;
    }

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .collection('appointments')
          .orderBy('timestamp', descending: false)
          .get();

      Map<String, List<Map<String, dynamic>>> groupedAppointments = {};

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> appointment = doc.data() as Map<String, dynamic>;

        // ✅ Ensure fields are not null to prevent errors
        String date = appointment['date'] ?? "";
        if (date.isEmpty) continue; // Skip if date is missing

        bool isBooked = appointment['booked'] ?? false; // ✅ Ensure `booked` is always boolean
        String time = appointment['time'] ?? "Unknown Time";
        String accountName = appointment['accountName'] ?? "Unknown Holder";
        String patientName = appointment['patientName'] ?? "Unknown Patient";
        String reason = appointment['reason'] ?? "No Reason Provided";
        String userAge = (appointment['userAge'] != null) ? appointment['userAge'].toString() : "-";
        String userGender = appointment['userGender'] ?? "-";
        String bookingTimestamp = appointment['bookingTimestamp'] != null
            ? _formatTimestamp(appointment['bookingTimestamp'])
            : "Unknown";

        if (!groupedAppointments.containsKey(date)) {
          groupedAppointments[date] = [];
        }

        groupedAppointments[date]!.add({
          'id': doc.id, // Firebase document ID for easy deletion
          'booked': isBooked,  // ✅ Store booked status properly
          'date': date,
          'time': time,
          'patientName': patientName,
          'reason': reason,
          'accountName': accountName,
          'userAge': userAge,
          'userGender': userGender,
          'bookingTimestamp': bookingTimestamp,
        });
      }

      setState(() {
        _appointmentsByDay = groupedAppointments;
      });

      print("✅ Loaded ${_appointmentsByDay.length} days of appointments.");
    } catch (e) {
      print("❌ Error fetching appointments: $e");
    }
  }

  /// **🔹 Add Available Slot (Date & Time Picker)**
  Future<void> _addAvailableSlot() async {
    DateTime? pickedDate;
    TimeOfDay? pickedTime;

    // ✅ Pick Date
    pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.main,
            colorScheme: ColorScheme.light(primary: AppColors.main),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    // ✅ Pick Time
    pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.main,
            colorScheme: ColorScheme.light(primary: AppColors.main),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    // ✅ Format Date & Time
    String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
    String formattedTime = pickedTime.format(context);

    // ✅ Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .collection('appointments')
          .add({
        'date': formattedDate,
        'time': formattedTime,
        'booked': false,
        'timestamp': Timestamp.fromDate(DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute)),
      });

      print("✅ Appointment Slot Added: $formattedDate at $formattedTime");

      // ✅ Refresh List
      _fetchDoctorAppointments();
    } catch (e) {
      print("❌ Error adding appointment: $e");
    }
  }


  /// **🔹 Delete an Appointment**
  Future<void> _deleteAppointment(String date, int index) async {
    String appointmentId = _appointmentsByDay[date]![index]['id'];

    try {
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .collection('appointments')
          .doc(appointmentId)
          .delete();

      setState(() {
        _appointmentsByDay[date]?.removeAt(index);
        if (_appointmentsByDay[date]?.isEmpty ?? false) {
          _appointmentsByDay.remove(date);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment Deleted Successfully!")),
      );
    } catch (e) {
      print("❌ Error deleting appointment: $e");
    }
  }

  Widget _toggleButton({
    required bool isLeft, // ✅ Use `bool` instead of `int`
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.main.withOpacity(0.7) : Colors.white,

          /// ✅ Use correct `BorderRadius`
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(8) : Radius.zero,
            bottomLeft: isLeft ? const Radius.circular(8) : Radius.zero,
            topRight: isLeft ? Radius.zero : const Radius.circular(8),
            bottomRight: isLeft ? Radius.zero : const Radius.circular(8),
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : AppColors.main,
          size: 20,
        ),
      ),
    );
  }

  /// **🔹 Show Slot Selection Dialog**
  void _showSlotSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Choose Slot Type", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// **🔹 Single or Multiple Slots**
              ListTile(
                leading: const Icon(Icons.date_range, color: AppColors.main),
                title: const Text("Single or Multiple Slots"),
                subtitle: const Text("Add one or multiple free slots for selected days."),
                onTap: () {
                  Navigator.pop(context);
                  _showSingleMultipleSlotDialog();
                },
              ),

              const Divider(),

              /// **🔹 Rotation-based Slots**
              ListTile(
                leading: const Icon(Icons.repeat, color: AppColors.main),
                title: const Text("Rotation-based Slots"),
                subtitle: const Text("Define weekly repeated slots with a custom time range."),
                onTap: () {
                  Navigator.pop(context);
                  _showRotationSlotDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// **🔹 Show Dialog for Selecting Multiple Dates & Times**
  void _showSingleMultipleSlotDialog() {
    List<DateTime> selectedDates = [];
    List<TimeOfDay> selectedTimes = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Select Dates & Times", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// **🔹 Date Selection**
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text("Select Days"),
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );

                      if (pickedDate != null && !selectedDates.contains(pickedDate)) {
                        setState(() {
                          selectedDates.add(pickedDate);
                        });
                      }
                    },
                  ),

                  /// **🔹 Show Selected Dates**
                  Wrap(
                    children: selectedDates.map((date) {
                      return Chip(
                        label: Text(DateFormat('yyyy-MM-dd').format(date)),
                        onDeleted: () {
                          setState(() {
                            selectedDates.remove(date);
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const Divider(),

                  /// **🔹 Time Selection**
                  ElevatedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: const Text("Select Time Slots"),
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );

                      if (pickedTime != null && !selectedTimes.contains(pickedTime)) {
                        setState(() {
                          selectedTimes.add(pickedTime);
                        });
                      }
                    },
                  ),

                  /// **🔹 Show Selected Time Slots**
                  Wrap(
                    children: selectedTimes.map((time) {
                      return Chip(
                        label: Text(time.format(context)),
                        onDeleted: () {
                          setState(() {
                            selectedTimes.remove(time);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addMultipleSlots(selectedDates, selectedTimes);
                    Navigator.pop(context);
                  },
                  child: const Text("Add Slots"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// **🔹 Add Multiple Slots to Firestore**
  void _addMultipleSlots(List<DateTime> dates, List<TimeOfDay> times) {
    for (var date in dates) {
      for (var time in times) {
        String formattedDate = DateFormat('yyyy-MM-dd').format(date);
        String formattedTime = time.format(context);

        FirebaseFirestore.instance.collection('doctors').doc(doctorId).collection('appointments').add({
          'date': formattedDate,
          'time': formattedTime,
          'booked': false,
          'timestamp': Timestamp.fromDate(
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
          ),
        });
      }
    }
    _fetchDoctorAppointments();
  }


  /// **🔹 Show Dialog for Rotation-based Slots**
  void _showRotationSlotDialog() {
    String selectedDay = "Monday";
    TimeOfDay startTime = TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = TimeOfDay(hour: 12, minute: 0);
    int interval = 30;
    DateTime? startRange;
    DateTime? endRange;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Define Rotation", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// **🔹 Select Day of the Week**
                  DropdownButton<String>(
                    value: selectedDay,
                    items: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                        .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDay = value!;
                      });
                    },
                  ),

                  /// **🔹 Select Start & End Time**
                  ElevatedButton(
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (pickedTime != null) {
                        setState(() {
                          startTime = pickedTime;
                        });
                      }
                    },
                    child: Text("Start: ${startTime.format(context)}"),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (pickedTime != null) {
                        setState(() {
                          endTime = pickedTime;
                        });
                      }
                    },
                    child: Text("End: ${endTime.format(context)}"),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Implement Firestore saving logic here
                    Navigator.pop(context);
                  },
                  child: const Text("Save Rotation"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      drawer: DoctorDrawer(doctorData: widget.doctorData),
      appBar: AppBar(
        backgroundColor: AppColors.main,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.whiteText, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Appointments & Availability",
          style: TextStyle(
            color: AppColors.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchDoctorAppointments,
          ),
        ],
      ),

      /// **Floating Button to Add Slot**
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.main,
        onPressed: () => _showSlotSelectionDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),

      /// **Main Content**
      body: Column(
        children: [
          /// **View Switcher**
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// 🔹 **View Mode Toggle (Left Side)**
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200, width: 1.5)), // ✅ Very thin border),
                  elevation: 0,
                  child: Row(
                    children: [
                      /// 📅 Calendar Button
                      _toggleButton(
                        isLeft: true,
                        icon: Icons.calendar_month,
                        isSelected: _isCalendarView,
                        onTap: () {
                          setState(() {
                            _isCalendarView = true;
                          });
                        },
                      ),

                      /// 📃 List Button
                      _toggleButton(
                        isLeft: false,
                        icon: Icons.list,
                        isSelected: !_isCalendarView,
                        onTap: () {
                          setState(() {
                            _isCalendarView = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                /// 🔹 **Filter Available Slots (Right Side)**
                TextButton.icon(
                  icon: Icon(
                    Icons.filter_alt,
                    size: 15,
                    color: _showFreeSlots ? Colors.white : AppColors.main.withOpacity(0.5), // ✅ Change color when active
                  ),
                  label: Text("Available Slots",
                    style: TextStyle(
                      color: _showFreeSlots ? Colors.white : AppColors.main.withOpacity(0.5), // ✅ Match icon color
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: _showFreeSlots ? AppColors.main.withOpacity(0.8) : Colors.white, // ✅ Change background when active
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(color: AppColors.main.withOpacity(0.5)), // ✅ Border to match design
                    ),
                    overlayColor: Colors.transparent, // ✅ Removes tap effect
                  ),

                  onPressed: () {
                    setState(() {
                      _showFreeSlots = !_showFreeSlots;
                    });
                  },
                ),


              ],
            ),
          ),


          /// **Toggle Between Views**
          Expanded(child: _isCalendarView ? _buildWeeklyCalendar() : _buildListView()),
        ],
      ),
    );
  }

  /// **📅 Weekly Calendar View**
  Widget _buildWeeklyCalendar() {
    return Column(
      children: [
        /// **Table Calendar**
        SizedBox(
          height: 150, // ✅ Ensure it has a fixed height
          child: TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle:  CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.main.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppColors.main,
                shape: BoxShape.circle,
              ),
            ),


    /// ✅ **Show Booked Appointments Count**
    calendarBuilders: CalendarBuilders(
    markerBuilder: (context, date, events) {
      String formattedDate = _formatDate(date);
      int bookedCount = _appointmentsByDay.containsKey(formattedDate)
          ? _appointmentsByDay[formattedDate]!
          .where((appointment) => appointment['booked'] == true)
          .length
          : 0;

      if (bookedCount == 0)
        return SizedBox(); // No marker if no booked appointments

      return Positioned(
        bottom: -2, // Position below the date
        right: 4, // Move to bottom-right
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.yellow, // ✅ Dark Main Color for Badge
            shape: BoxShape.circle,
          ),
          constraints: const BoxConstraints(
            minWidth: 10,
            minHeight: 10,
          ),
          child: Center(
            child: Text(
              "$bookedCount", // ✅ Show booked count
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    },
    ),
          ),
        ),

        /// **Appointments for Selected Date**
        Expanded(
          child: _appointmentsByDay.containsKey(_formatDate(_selectedDay))
              ? _buildListForDate(_formatDate(_selectedDay))
              : const Padding(
            padding: EdgeInsets.all(20),
            child: Text("No appointments for this day."),
          ),
        ),
      ],
    );
  }

  /// **📃 List View (Grouped by Day)**
  Widget _buildListView() {
    if (_appointmentsByDay.isEmpty) {
      return const Center(
        child: Text("No appointments available", style: TextStyle(fontSize: 16)),
      );
    }

    return ListView(
      children: _appointmentsByDay.keys.map((date) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 **Date Header (Top Left)**
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
              child: Text(
                date, // ✅ Display date
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.main),
              ),
            ),

            /// 🔹 **Appointments for the Date**
            _buildListForDate(date),
          ],
        );
      }).toList(),
    );
  }


  /// **📅 Appointment List for a Specific Date**
  Widget _buildListForDate(String date) {
    List<Map<String, dynamic>> appointments = _appointmentsByDay[date] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...appointments.where((appointment) => _showFreeSlots || (appointment['booked'] ?? false)).map((appointment) {
          bool isExpanded = false; // Track expansion state
          bool isBooked = appointment['booked'] ?? false; // ✅ Ensure it's always boolean

          return StatefulBuilder(
            builder: (context, setState) {
              return Card(
                elevation: 0,
                color: Colors.white, // ✅ Change color for free slots
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200, width: 1.5), // ✅ Very thin border
                ),
                child: Padding(
                  padding: isBooked ? EdgeInsets.symmetric(horizontal: 12, vertical: 8): EdgeInsets.symmetric(horizontal: 0, vertical: 0) ,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          /// 🔹 **Time and Clock Icon**
                          Container(
                            decoration: BoxDecoration(
                                color: isBooked ?AppColors.whiteText : AppColors.main.withOpacity(0.8),
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(10.0), bottomLeft: Radius.circular(10.0))),
                            child: Padding(
                              padding: isBooked ? EdgeInsets.all(0) : EdgeInsets.only(left: 20, right: 20, top:3, bottom: 7),
                              child: Column(
                                children: [
                                  isBooked ? Icon(Icons.access_time, color: AppColors.main, size: 22) : SizedBox(height: 0),
                                  const SizedBox(height: 5),
                                  Text(
                                    appointment['time'] ?? "Unknown Time",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isBooked ?AppColors.main : AppColors.whiteText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),

                          /// 🔹 **Patient Info or Available Slot**
                          Expanded(
                            child: isBooked
                                ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      appointment['patientName'] ?? "Unknown Patient",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      " (${appointment['userGender']}, ${appointment['userAge']})",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  appointment['reason'] ?? "No Reason Provided",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            )
                                : Center(
                                  child: const Text(
                                                                "Available",
                                                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.main,
                                                                ),
                                                              ),
                                ),
                          ),

                          /// 🔹 **Expand Icon**
                          if (isBooked)
                            IconButton(
                              icon: Icon(
                                isExpanded ? Icons.expand_less : Icons.chevron_right,
                                color: AppColors.main,
                              ),
                              onPressed: () {
                                setState(() {
                                  isExpanded = !isExpanded;
                                });
                              },
                            ),
                        ],
                      ),

                      /// 🔹 **Expanded Details for Booked Appointments**
                      if (isExpanded && isBooked)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow("Account Holder", appointment['accountName'] ?? "Unknown"),
                              _infoRow("New Patient", (appointment['newPatient'] ?? false) ? "Yes" : "No"),
                              _infoRow("Patient Name", appointment['patientName'] ?? "Unknown"),
                              _infoRow("Date", appointment['date'] ?? "Unknown"),
                              _infoRow("Time", appointment['time'] ?? "Unknown"),
                              _infoRow("Reason", appointment['reason'] ?? "Unknown"),
                              _infoRow("Booking Time", appointment['bookingTimestamp'] ?? "Unknown"),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }

  /// **🔹 Helper: Display Info Row**
  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style:  TextStyle(fontWeight: label == "Account Holder" ? FontWeight.w400 : FontWeight.bold, fontSize:  label == "Account Holder" ? 10 : 14)),
          Expanded(child: Text(value ?? "Unknown", style:  TextStyle(fontSize:  label == "Account Holder" ? 10 : 14))),
        ],
      ),
    );
  }
}

String _formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return "Unknown";
  return DateFormat("yyyy-MM-dd HH:mm").format(timestamp.toDate());
}

/// **🔹 Helper: Format Date (Handles String & DateTime)**
String _formatDate(dynamic date) {
  try {
    if (date is String) {
      date = DateTime.parse(date); // ✅ Convert String to DateTime
    }
    return DateFormat('yyyy-MM-dd').format(date); // ✅ Standard date format
  } catch (e) {
    print("❌ Error parsing date: $e");
    return "Invalid Date"; // ✅ Fallback for errors
  }
}

