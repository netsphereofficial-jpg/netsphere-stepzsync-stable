import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../models/race_models.dart';
import '../../../services/admin/admin_race_service.dart';

/// Admin Create Race Screen
/// Comprehensive form for creating races from admin panel

class AdminCreateRaceScreen extends StatefulWidget {
  const AdminCreateRaceScreen({Key? key}) : super(key: key);

  @override
  State<AdminCreateRaceScreen> createState() => _AdminCreateRaceScreenState();
}

class _AdminCreateRaceScreenState extends State<AdminCreateRaceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form Controllers
  final _titleController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _startAddressController = TextEditingController();
  final _endAddressController = TextEditingController();
  final _startLatController = TextEditingController();
  final _startLngController = TextEditingController();
  final _endLatController = TextEditingController();
  final _endLngController = TextEditingController();
  final _totalDistanceController = TextEditingController();
  final _participantLimitController = TextEditingController();

  // Dropdowns
  String _selectedRaceType = 'Public';
  String _selectedGender = 'All';
  DateTime? _selectedScheduleTime;
  DateTime? _selectedDeadline;

  final List<String> _raceTypes = ['Solo', 'Private', 'Public', 'Marathon', 'Quick Race'];
  final List<String> _genderOptions = ['All', 'Male', 'Female', 'Other'];

  @override
  void dispose() {
    _titleController.dispose();
    _orgNameController.dispose();
    _startAddressController.dispose();
    _endAddressController.dispose();
    _startLatController.dispose();
    _startLngController.dispose();
    _endLatController.dispose();
    _endLngController.dispose();
    _totalDistanceController.dispose();
    _participantLimitController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isScheduleTime) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        final dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isScheduleTime) {
            _selectedScheduleTime = dateTime;
          } else {
            _selectedDeadline = dateTime;
          }
        });
      }
    }
  }

  void _calculateDistance() {
    if (_startLatController.text.isNotEmpty &&
        _startLngController.text.isNotEmpty &&
        _endLatController.text.isNotEmpty &&
        _endLngController.text.isNotEmpty) {
      try {
        final distance = AdminRaceService.calculateDistance(
          double.parse(_startLatController.text),
          double.parse(_startLngController.text),
          double.parse(_endLatController.text),
          double.parse(_endLngController.text),
        );
        setState(() {
          _totalDistanceController.text = distance.toStringAsFixed(2);
        });
      } catch (e) {
        print('Error calculating distance: $e');
      }
    }
  }

  Future<void> _createRace() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedScheduleTime == null) {
      _showError('Please select a schedule time');
      return;
    }

    if (_selectedDeadline == null) {
      _showError('Please select a race deadline');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final race = RaceModel(
        title: _titleController.text.trim(),
        orgName: _orgNameController.text.trim(),
        createdTime: DateTime.now(),
        startAddress: _startAddressController.text.trim(),
        endAddress: _endAddressController.text.trim(),
        raceType: _selectedRaceType,
        totalDistance: double.parse(_totalDistanceController.text),
        genderPrefrence: _selectedGender,
        raceStoppingTime: _selectedDeadline!.toIso8601String(),
        totalParticipant: 0,
        partcipantLimit: int.parse(_participantLimitController.text),
        scheduleTime: _selectedScheduleTime!.toIso8601String(),
        startLatitude: double.parse(_startLatController.text),
        startLongitude: double.parse(_startLngController.text),
        endLatitude: double.parse(_endLatController.text),
        endLongitude: double.parse(_endLngController.text),
        createdBy: currentUser.uid,
        status: 'scheduled',
        statusId: 0,
        raceDeadline: _selectedDeadline,
      );

      final raceId = await AdminRaceService.createRace(race);

      if (mounted) {
        Get.snackbar(
          'Success',
          'Race created successfully!',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        // Navigate back
        Get.back(result: true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to create race: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Create New Race',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2759FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.directions_run_rounded,
                              color: Color(0xFF2759FF),
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Create a New Race',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1a1a1a),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fill in the details below to create a new race for your users',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Basic Information Section
                  _buildSectionHeader('Basic Information'),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _titleController,
                            label: 'Race Title',
                            hint: 'e.g., Morning Marathon 2025',
                            icon: Icons.title,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _orgNameController,
                            label: 'Organizer Name',
                            hint: 'e.g., StepzSync Team',
                            icon: Icons.business,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  label: 'Race Type',
                                  value: _selectedRaceType,
                                  items: _raceTypes,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRaceType = value!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdown(
                                  label: 'Gender Preference',
                                  value: _selectedGender,
                                  items: _genderOptions,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Location Details Section
                  _buildSectionHeader('Location Details'),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _startAddressController,
                            label: 'Start Address',
                            hint: 'Enter starting point address',
                            icon: Icons.location_on,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _startLatController,
                                  label: 'Latitude',
                                  hint: '0.0',
                                  icon: Icons.my_location,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => _calculateDistance(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _startLngController,
                                  label: 'Longitude',
                                  hint: '0.0',
                                  icon: Icons.explore,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => _calculateDistance(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Divider(color: Colors.grey[300]),
                          const SizedBox(height: 24),

                          Text(
                            'End Location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _endAddressController,
                            label: 'End Address',
                            hint: 'Enter destination address',
                            icon: Icons.flag,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _endLatController,
                                  label: 'Latitude',
                                  hint: '0.0',
                                  icon: Icons.my_location,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => _calculateDistance(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _endLngController,
                                  label: 'Longitude',
                                  hint: '0.0',
                                  icon: Icons.explore,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => _calculateDistance(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Race Configuration Section
                  _buildSectionHeader('Race Configuration'),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _totalDistanceController,
                                  label: 'Total Distance (km)',
                                  hint: 'Auto-calculated or enter manually',
                                  icon: Icons.straighten,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _participantLimitController,
                                  label: 'Participant Limit',
                                  hint: 'e.g., 50',
                                  icon: Icons.people,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildDateTimePicker(
                            label: 'Schedule Time',
                            value: _selectedScheduleTime,
                            onTap: () => _selectDateTime(context, true),
                          ),
                          const SizedBox(height: 20),
                          _buildDateTimePicker(
                            label: 'Race Deadline',
                            value: _selectedDeadline,
                            onTap: () => _selectDateTime(context, false),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createRace,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2759FF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Create Race',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF2759FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1a1a1a),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        child: Text(
          value != null
              ? DateFormat('MMM dd, yyyy hh:mm a').format(value)
              : 'Select date and time',
          style: TextStyle(
            color: value != null ? Colors.black87 : Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
