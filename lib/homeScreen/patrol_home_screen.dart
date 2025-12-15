import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../animate/christmas_title.dart';
import '../test.dart';

class PatrolHomeScreen extends StatefulWidget {
  const PatrolHomeScreen({super.key});

  @override
  State<PatrolHomeScreen> createState() => _PatrolHomeScreenState();
}

class _PatrolHomeScreenState extends State<PatrolHomeScreen> {
  // Danh sách nhà máy
  final List<String> factories = ['612K', '611T', '613F', '614F', 'Meivy'];

  // Nhà máy hiện tại được chọn (mặc định là 612K)
  String selectedFactory = '612K';

  // Hàm chuyển screen
  void _navigateTo(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(
            child: Text(
              'Đây là màn hình $title\nNhà máy đang chọn: $selectedFactory',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background gradient nhẹ nhàng
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey.shade900,
              Colors.blueGrey.shade700,
              Colors.blueGrey.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề lớn kiểu glass
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 32,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'SAFETY CROSS PATROL',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ChristmasTitle(),
                const SizedBox(height: 40),

                // Dòng chọn Nhà máy kiểu glass
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nhà máy',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          DropdownButton<String>(
                            value: selectedFactory,
                            dropdownColor: Colors.blueGrey.shade900.withOpacity(
                              0.9,
                            ),
                            underline: const SizedBox(),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white70,
                              size: 30,
                            ),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            items: factories.map((String factory) {
                              return DropdownMenuItem<String>(
                                value: factory,
                                child: Text(factory),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedFactory = newValue;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // 3 nút lớn kiểu glass
                Expanded(
                  child: ListView(
                    children: [
                      _buildPatrolButton(
                        number: '1)',
                        title: 'Patrol Before',
                        isEnabled: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CameraScreen(selectedPlant: selectedFactory),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildPatrolButton(
                        number: '2)',
                        title: 'Patrol After',
                        isEnabled: false,
                        onTap: null,
                      ),
                      const SizedBox(height: 20),
                      _buildPatrolButton(
                        number: '3)',
                        title: 'Patrol HSE check',
                        isEnabled: false,
                        onTap: null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatrolButton({
    required String number,
    required String title,
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    final bool isDisabled = !isEnabled;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: GestureDetector(
          onTap: isDisabled ? null : onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: isDisabled ? 0.5 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDisabled
                      ? Colors.white.withOpacity(0.3)
                      : Colors.lightGreenAccent.shade400,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDisabled
                          ? Colors.white54
                          : Colors.lightGreenAccent.shade400,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDisabled
                                ? Colors.white60
                                : Colors.lightGreenAccent.shade400,
                          ),
                        ),
                        if (isDisabled)
                          const Text(
                            'Coming soon...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isDisabled
                        ? Colors.white38
                        : Colors.lightGreenAccent.shade400,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
