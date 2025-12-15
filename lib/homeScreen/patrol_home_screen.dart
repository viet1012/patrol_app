import 'package:flutter/material.dart';

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề lớn
              const Center(
                child: Text(
                  'SAFETY CROSS PATROL',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Dòng chọn Nhà máy
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD), // xanh nhạt
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nhà máy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    DropdownButton<String>(
                      value: selectedFactory,
                      underline: const SizedBox(), // ẩn gạch chân mặc định
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black87,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      dropdownColor: Colors.white,
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
              const SizedBox(height: 50),

              // 3 nút lớn
              Expanded(
                child: ListView(
                  children: [
                    _buildPatrolButton(
                      number: '1)',
                      title: 'Patrol_Before',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CameraScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    _buildPatrolButton(
                      number: '2)',
                      title: 'Patrol_After',
                      onTap: () => _navigateTo(context, 'Patrol After'),
                    ),
                    const SizedBox(height: 20),
                    _buildPatrolButton(
                      number: '3)',
                      title: 'Patrol_HSE check',
                      onTap: () => _navigateTo(context, 'Patrol HSE Check'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatrolButton({
    required String number,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 28),
          ],
        ),
      ),
    );
  }
}
