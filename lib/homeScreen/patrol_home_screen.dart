import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../LanguageFlagButton.dart';
import '../animate/call_to_action_arrow.dart';
import '../animate/christmas_title.dart';
import '../animate/glow_title.dart';
import '../api/hse_master_service.dart';
import '../model/hse_patrol_team_model.dart';
import '../model/machine_model.dart';
import '../test.dart';
import '../translator.dart';
import '../widget/error_display.dart';

enum PatrolGroup { weekly, srg, qa }

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

  // bool showWeeklyOptions = false;
  PatrolGroup? expandedGroup;

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
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F2027), // deep blue-black
              Color(0xFF203A43), // tech blue
              Color(0xFF2C5364), // cyan blue
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
                              child: EmbossGlowTitle(text: 'AUDIT WEB'),
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

                      const SizedBox(height: 30),

                      Expanded(
                        child: Expanded(
                          child: ListView(
                            children: [
                              _parentPatrolButton(
                                group: PatrolGroup.weekly,
                                title: 'Weekly Safety Patrol',
                                icon: Icons.security,
                              ),
                              _childPatrolOptions(
                                group: PatrolGroup.weekly,
                                prefix: 'Patrol',
                              ),

                              const SizedBox(height: 24),

                              _parentPatrolButton(
                                group: PatrolGroup.srg,
                                title: 'SRG Safety Audit',
                                icon: Icons.groups,
                                enabled: true,
                              ),
                              _childPatrolOptions(
                                group: PatrolGroup.srg,
                                prefix: 'Audit',
                              ),

                              const SizedBox(height: 24),

                              _parentPatrolButton(
                                group: PatrolGroup.qa,
                                title: 'QA Quality Audit',
                                icon: Icons.verified,
                                enabled: false, // ✅ enable ô cuối
                              ),
                              _childPatrolOptions(
                                group: PatrolGroup.qa,
                                prefix: 'QA Audit',
                              ),

                              // _weeklyPatrolButton(),
                              // AnimatedSize(
                              //   duration: const Duration(milliseconds: 400),
                              //   curve: Curves.easeInOut,
                              //   child: showWeeklyOptions
                              //       ? Column(
                              //           children: [
                              //             const SizedBox(height: 20),
                              //             _patrolButton(
                              //               number: '1)',
                              //               title: 'Patrol Before',
                              //               enabled: true,
                              //               onTap: () {
                              //                 Navigator.push(
                              //                   context,
                              //                   MaterialPageRoute(
                              //                     builder: (_) => CameraScreen(
                              //                       machines: machines,
                              //                       patrolTeams: teams,
                              //                       lang: currentLang,
                              //                       selectedPlant:
                              //                           selectedFactory,
                              //                     ),
                              //                   ),
                              //                 );
                              //               },
                              //             ),
                              //             const SizedBox(height: 20),
                              //             _patrolButton(
                              //               number: '2)',
                              //               title: 'Patrol After',
                              //               enabled: false,
                              //             ),
                              //             const SizedBox(height: 20),
                              //             _patrolButton(
                              //               number: '3)',
                              //               title: 'Patrol HSE check',
                              //               enabled: false,
                              //             ),
                              //           ],
                              //         )
                              //       : const SizedBox(),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Color _groupColor(PatrolGroup group, bool enabled) {
    if (!enabled) return Colors.white.withOpacity(0.5);

    switch (group) {
      case PatrolGroup.weekly:
        return Colors.lightBlueAccent.shade400; // Weekly Safety Patrol
      case PatrolGroup.srg:
        return Colors.orangeAccent.shade400; // SRG Safety Audit
      case PatrolGroup.qa:
        return Colors.purpleAccent.shade400; // QA Quality Audit
    }
  }

  Widget _parentPatrolButton({
    required PatrolGroup group,
    required String title,
    required IconData icon,
    bool enabled = true,
  }) {
    final isExpanded = expandedGroup == group;
    final color = _groupColor(group, enabled);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: GestureDetector(
          onTap: enabled
              ? () {
                  setState(() {
                    expandedGroup = isExpanded ? null : group;
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 26, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                enabled
                    ? AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(Icons.expand_more, size: 34, color: color),
                      )
                    : Icon(Icons.lock_outline, color: color, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _childPatrolOptions({
    required PatrolGroup group,
    required String prefix,
  }) {
    if (expandedGroup != group) return const SizedBox();

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Column(
        children: [
          const SizedBox(height: 20),
          _patrolButton(
            number: '1)',
            title: '$prefix Before',
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
          _patrolButton(number: '2)', title: '$prefix After', enabled: false),
          const SizedBox(height: 20),
          _patrolButton(number: '3)', title: '$prefix Check', enabled: false),
        ],
      ),
    );
  }

  // Widget _weeklyPatrolButton() {
  //   return ClipRRect(
  //     borderRadius: BorderRadius.circular(22),
  //     child: BackdropFilter(
  //       filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
  //       child: GestureDetector(
  //         onTap: () {
  //           setState(() {
  //             showWeeklyOptions = !showWeeklyOptions;
  //           });
  //         },
  //         child: Container(
  //           padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
  //           decoration: BoxDecoration(
  //             color: Colors.white.withOpacity(0.18),
  //             borderRadius: BorderRadius.circular(22),
  //             border: Border.all(
  //               color: Colors.lightBlueAccent.shade400,
  //               width: 2.5,
  //             ),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withOpacity(0.2),
  //                 blurRadius: 14,
  //                 offset: const Offset(0, 6),
  //               ),
  //             ],
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(
  //                 Icons.security,
  //                 size: 32,
  //                 color: Colors.lightBlueAccent.shade400,
  //               ),
  //               const SizedBox(width: 16),
  //               Expanded(
  //                 child: Text(
  //                   'Weekly Safety Patrol',
  //                   style: TextStyle(
  //                     fontSize: 24,
  //                     fontWeight: FontWeight.w900,
  //                     color: Colors.lightBlueAccent.shade400,
  //                     letterSpacing: 1.2,
  //                   ),
  //                 ),
  //               ),
  //               AnimatedRotation(
  //                 turns: showWeeklyOptions ? 0.5 : 0,
  //                 duration: const Duration(milliseconds: 300),
  //                 child: Icon(
  //                   Icons.expand_more,
  //                   size: 34,
  //                   color: Colors.lightBlueAccent.shade400,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

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
                      fontSize: 18,
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
                            fontSize: 18,
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
                  if (enabled)
                    CallToActionArrow(color: color)
                  else
                    Icon(Icons.lock_outline, color: color, size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
