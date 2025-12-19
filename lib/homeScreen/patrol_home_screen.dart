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

enum PatrolGroup { Patrol, Audit, QualityPatrol }

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          centerTitle: true,
          title: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: EmbossGlowTitle(text: 'AUDIT WEB'),
              ),
            ),
          ),
          backgroundColor: Color(0xFF0F2027),
          elevation: 0,
        ),
      ),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: glassDecorationSmall,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                /// 🌐 LANGUAGE
                                LanguageToggleSwitch(
                                  onLanguageChanged: (lang) {
                                    setState(() {
                                      currentLang = lang;
                                    });
                                  },
                                ),

                                /// 🏭 FACTORY
                                Row(
                                  children: [
                                    Text(
                                      "plant".tr(context),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
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
                                        fontSize: 20,
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
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      Expanded(
                        child: ListView(
                          children: [
                            _patrolGroupCard(
                              group: PatrolGroup.Patrol,
                              title: 'Weekly Safety Patrol',
                              icon: Icons.security,
                              prefix: 'Patrol',
                            ),

                            _patrolGroupCard(
                              group: PatrolGroup.Audit,
                              title: 'SRG Safety Audit',
                              icon: Icons.groups,
                              prefix: 'Audit',
                            ),

                            _patrolGroupCard(
                              group: PatrolGroup.QualityPatrol,
                              title: 'QA Quality Audit',
                              icon: Icons.verified,
                              prefix: 'QA Audit',
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

  Color _groupColor(PatrolGroup group, bool enabled) {
    if (!enabled) return Colors.white.withOpacity(0.5);

    switch (group) {
      case PatrolGroup.Patrol:
        return Colors.lightBlueAccent.shade400; // Weekly Safety Patrol
      case PatrolGroup.Audit:
        return Colors.green.shade400; // SRG Safety Audit
      case PatrolGroup.QualityPatrol:
        return Colors.purpleAccent.shade400; // QA Quality Audit
    }
  }

  Widget _patrolGroupCard({
    required PatrolGroup group,
    required String title,
    required IconData icon,
    required String prefix,
    bool enabled = true,
  }) {
    final isExpanded = expandedGroup == group;
    final color = _groupColor(group, enabled);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            children: [
              /// 🔹 PARENT HEADER
              InkWell(
                onTap: enabled
                    ? () {
                        setState(() {
                          expandedGroup = isExpanded ? null : group;
                        });
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 22,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 26),
                      const SizedBox(width: 12),
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
                              child: Icon(
                                Icons.expand_more,
                                size: 34,
                                color: color,
                              ),
                            )
                          : Icon(Icons.lock_outline, color: color, size: 26),
                    ],
                  ),
                ),
              ),

              /// 🔹 CHILD BODY
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 350),
                crossFadeState: isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _childPatrolContainer(
                  group: group,
                  prefix: prefix,
                  color: color,
                ),
                secondChild: const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _childPatrolContainer({
    required PatrolGroup group,
    required String prefix,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(18),
        // decoration: BoxDecoration(
        //   color: Colors.black.withOpacity(0.25), // ⬅ khác parent
        //   borderRadius: BorderRadius.circular(20),
        //   border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        // ),
        child: Column(
          children: [
            _patrolButton(
              number: '1)',
              title: '$prefix Before',
              color: color,
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
                      patrolGroup: group,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _patrolButton(
              number: '2)',
              title: '$prefix After',
              color: color,
              enabled: false,
            ),
            const SizedBox(height: 16),
            _patrolButton(
              number: '3)',
              title: '$prefix ReCheck',
              color: color,
              enabled: false,
            ),
          ],
        ),
      ),
    );
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

  Widget _patrolButton({
    required String number,
    required String title,
    required Color color,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
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
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: 1),
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
                  enabled
                      ? CallToActionArrow(color: color)
                      : Icon(Icons.lock_outline, color: color, size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
