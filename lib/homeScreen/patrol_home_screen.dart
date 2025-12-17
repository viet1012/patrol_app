import 'dart:ui';

import 'package:flutter/material.dart';

import '../LanguageFlagButton.dart';
import '../animate/christmas_title.dart';
import '../api/hse_master_service.dart';
import '../model/hse_patrol_team_model.dart';
import '../model/machine_model.dart';
import '../test.dart';
import '../translator.dart';
import '../widget/error_display.dart';

class PatrolHomeScreen extends StatefulWidget {
  const PatrolHomeScreen({super.key});

  @override
  State<PatrolHomeScreen> createState() => _PatrolHomeScreenState();
}

class _PatrolHomeScreenState extends State<PatrolHomeScreen> {
  // final List<String> factories = ['612K', '611T', '613F', '614F', 'meivy'];

  List<String> getPlantList(List<MachineModel> machines) {
    return machines
        .map((e) => e.plant?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet() // 🔥 remove duplicate
        .toList();
  }

  // String selectedFactory = '612K';
  String? selectedFactory;

  String currentLang = "VI";

  List<MachineModel> machines = [];
  bool isLoading = true;
  String? errorMessage;
  List<HsePatrolTeamModel> teams = [];

  @override
  void initState() {
    super.initState();
    _loadHseMaster();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await HseMasterService.fetchAll();
      setState(() {
        teams = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Load patrol teams error: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadHseMaster() async {
    try {
      final data = await HseMasterService.fetchMachines();

      final plants = getPlantList(data);

      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      setState(() {
        machines = data;
        selectedFactory = plants.isNotEmpty ? plants.first : null;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Load HSE master error: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Common decoration for glass containers
  final BoxDecoration glassDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  final BoxDecoration glassDecorationSmall = BoxDecoration(
    color: Colors.white.withOpacity(0.12),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
  );

  final TextStyle titleTextStyle = const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 2,
  );

  @override
  Widget build(BuildContext context) {
    final List<String> factories = getPlantList(machines);
    ;

    return Scaffold(
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
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.lightBlueAccent.shade400,
                  ),
                )
              : errorMessage != null && errorMessage!.isNotEmpty
              ? ErrorDisplay(
                  errorMessage: errorMessage!,
                  onRetry: () {
                    _loadHseMaster();
                    _loadTeams();
                  },
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: LanguageToggleSwitch(
                          onLanguageChanged: (lang) {
                            setState(() {
                              currentLang = lang;
                            });

                            debugPrint("📢 Language from child: $lang");
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

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
                              decoration: glassDecoration,
                              child: Column(
                                children: [
                                  const Text(
                                    'SAFETY CROSS PATROL',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: glassDecorationSmall,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "plant".tr(context),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: selectedFactory,
                                  dropdownColor: Colors.blueGrey.shade900
                                      .withOpacity(0.9),
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
                                  items: factories
                                      .map(
                                        (f) => DropdownMenuItem(
                                          value: f,
                                          child: Text(f),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        selectedFactory = val;
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

                      Expanded(
                        child: ListView(
                          children: [
                            _patrolButton(
                              number: '1)',
                              title: 'Patrol Before',
                              enabled: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CameraScreen(
                                      machines: machines,
                                      patrolTeams: teams,
                                      lang: currentLang,
                                      selectedPlant: selectedFactory,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _patrolButton(
                              number: '2)',
                              title: 'Patrol After',
                              enabled: false,
                            ),
                            const SizedBox(height: 20),
                            _patrolButton(
                              number: '3)',
                              title: 'Patrol HSE check',
                              enabled: false,
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

  Widget _patrolButton({
    required String number,
    required String title,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final color = enabled
        ? Colors.lightBlueAccent.shade400
        : Colors.white.withOpacity(0.5);
    final opacity = enabled ? 1.0 : 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: 2),
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
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        if (!enabled)
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
                  Icon(Icons.arrow_forward_ios, color: color, size: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
