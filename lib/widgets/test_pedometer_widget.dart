import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class TestPedometerWidget extends StatefulWidget {
  final Function(int)? onStepCountChanged;

  const TestPedometerWidget({
    super.key,
    this.onStepCountChanged,
  });

  @override
  State<TestPedometerWidget> createState() => _TestPedometerWidgetState();
}

class _TestPedometerWidgetState extends State<TestPedometerWidget> {
  late Stream<StepCount> _stepCountStream;
  late Stream<PedestrianStatus> _pedestrianStatusStream;
  String _status = '?', _steps = '?';
  String _permissionStatus = 'Unknown';
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  @override
  void initState() {
    super.initState();
    _initPedometer();
  }

  Future<void> _initPedometer() async {
    await _checkPermissions();
    _initPlatformState();
  }

  Future<void> _checkPermissions() async {
    try {
      var status = await Permission.activityRecognition.status;

      if (!status.isGranted) {
        status = await Permission.activityRecognition.request();
      }

      // For iOS, also check motion permissions
      var motionStatus = await Permission.sensors.status;
      if (!motionStatus.isGranted) {
        motionStatus = await Permission.sensors.request();
      }

      setState(() {
        _permissionStatus = status.isGranted ? 'Granted' : 'Denied';
      });
    } catch (e) {
      setState(() {
        _permissionStatus = 'Error: $e';
      });
    }
  }

  void _initPlatformState() {
    try {
      _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
      _pedestrianStatusSubscription = _pedestrianStatusStream
          .listen(_onPedestrianStatusChanged, onError: _onPedestrianStatusError);
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountSubscription = _stepCountStream
          .listen(_onStepCount, onError: _onStepCountError);
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize: $e';
      });
    }
  }

  void _onStepCount(StepCount event) {
    print('Step Count: ${event.steps}');
    setState(() {
      _steps = event.steps.toString();
    });

    // Call the callback if provided
    widget.onStepCountChanged?.call(event.steps);
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    print('Pedestrian Status: ${event.status}');
    setState(() {
      _status = event.status;
    });
  }

  void _onStepCountError(error) {
    print('Step Count Error: $error');
    setState(() {
      _steps = 'Step Count not available';
    });
  }

  void _onPedestrianStatusError(error) {
    print('Pedestrian Status Error: $error');
    setState(() {
      _status = 'Pedestrian Status not available';
    });
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_walk,
                color: Color(0xFF2759FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Test Pedometer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2759FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Permission Status
          _buildInfoRow('Permission Status', _permissionStatus),
          const SizedBox(height: 12),

          // Step Count
          _buildInfoRow('Steps', _steps),
          const SizedBox(height: 12),

          // Pedestrian Status
          _buildInfoRow('Status', _status),

          const SizedBox(height: 16),

          // Refresh Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _initPedometer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2759FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}