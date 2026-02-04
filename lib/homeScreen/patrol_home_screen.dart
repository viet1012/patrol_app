import 'dart:ui';

import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../LanguageFlagButton.dart';
import '../after/after_detail_screen.dart';
import '../animate/call_to_action_arrow.dart';
import '../animate/glow_title.dart';
import '../api/dio_client.dart';
import '../api/hse_master_service.dart';
import '../common/animated_glass_action_button.dart';
import '../common/app_version_text.dart';
import '../common/common_ui_helper.dart';
import '../model/auth_me.dart';
import '../model/hse_patrol_team_model.dart';
import '../model/machine_model.dart';
import '../qrCode/qr_scanner_dialog.dart';
import '../recheck/recheck_detail_screen.dart';
import '../session/session_store.dart';
import '../test.dart';
import '../translator.dart';

enum PatrolGroup { Patrol, Audit, QualityPatrol }

enum PatrolAction { before, after, recheck, summary }

class PatrolHomeScreen extends StatefulWidget {
  final String accountCode;

  const PatrolHomeScreen({super.key, required this.accountCode});

  @override
  State<PatrolHomeScreen> createState() => _PatrolHomeScreenState();
}

class _PatrolHomeScreenState extends State<PatrolHomeScreen> {
  List<String> getPlantList(List<MachineModel> machines) {
    return machines
        .map((e) => e.plant?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet() // 🔥 remove duplicate
        .toList();
  }

  String? selectedFactory;

  String currentLang = "VI";

  List<MachineModel> machines = [];
  bool isLoading = true;
  String? errorMessage;
  List<HsePatrolTeamModel> teams = [];

  // bool showWeeklyOptions = false;
  PatrolGroup? expandedGroup;

  String _employeeName = '';

  Future<void> _initEmployee() async {
    await fetchEmployeeName(widget.accountCode);
    debugPrint("EMPLOYEE NAME = $_employeeName");
  }

  HsePatrolTeamModel? _autoTeam;
  bool _needManualSelect = true;
  bool _qrHandled = false;
  final _qrDialogKey = GlobalKey<QrScannerDialogState>();
  AuthMe? _authMe;

  @override
  void initState() {
    super.initState();
    _initEmployee();
    _loadAuthMe();
    _initData();
  }

  Future<void> _initData() async {
    await _loadHseMaster(); // load machines trước
    await _loadTeams(); // sau đó mới auto set plant
  }

  Future<void> _loadAuthMe() async {
    try {
      final dio = DioClient.dio;
      final res = await dio.get(
        '/api/hr/me',
        queryParameters: {'code': widget.accountCode},
      );

      if (res.statusCode == 200) {
        setState(() {
          _authMe = AuthMe.fromJson(res.data);
        });
      }
    } catch (e) {
      debugPrint('Load auth me error: $e');
    }
  }

  Future<void> _loadTeams() async {
    try {
      final data = await HseMasterService.fetchAll();

      HsePatrolTeamModel? found;
      PatrolGroup? foundGroup;

      for (final g in PatrolGroup.values) {
        final t = HseMasterService.findTeamByEmp(widget.accountCode, g, data);
        if (t != null) {
          found = t;
          foundGroup = g;
          break;
        }
      }

      setState(() {
        teams = data;
        _autoTeam = found;
        expandedGroup = foundGroup;
        _needManualSelect = found == null;

        if (found != null) {
          selectedFactory = found.plant;
        }
      });
      print(
        "Plant: ${found?.plant} - Fac: ${found?.fac} - Group: ${found?.grp} ",
      );
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  Future<void> _loadHseMaster() async {
    try {
      final data = await HseMasterService.fetchMachines();

      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      setState(() {
        machines = data;
        if (_autoTeam == null) {
          selectedFactory = null;
        }
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

  List<String> getAllFactories({
    required List<MachineModel> machines,
    required List<HsePatrolTeamModel> teams,
  }) {
    final machinePlants = machines
        .map((e) => e.plant?.trim())
        .whereType<String>();

    final teamPlants = teams.map((e) => e.plant?.trim()).whereType<String>();

    return {...machinePlants, ...teamPlants}.toList();
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

  Future<void> fetchEmployeeName(String code) async {
    if (code.trim().isEmpty) {
      setState(() {
        _employeeName = '';
      });
      return;
    }

    try {
      final dio = DioClient.dio;
      final response = await dio.get(
        '/api/hr/name',
        queryParameters: {'code': code.trim()},
      );

      if (response.statusCode == 200) {
        setState(() {
          _employeeName = response.data.toString();
        });
      } else {
        setState(() {
          _employeeName = '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching employee name: $e');
      setState(() {
        _employeeName = '';
      });
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    // final List<String> factories = getPlantList(machines);
    final factories = _autoTeam != null
        ? [_autoTeam!.plant!]
        : getAllFactories(machines: machines, teams: teams);
    factories.sort((a, b) {
      int getNum(String s) => int.tryParse(s.split('_').last) ?? 0;

      return getNum(a).compareTo(getNum(b));
    });
    debugPrint('FACTORIES = $factories');
    debugPrint('AUTO TEAM = ${_autoTeam?.plant}');
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          centerTitle: true,
          title: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/flags/favicon.png',
                    width: 40,
                    height: 40,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 8),
                  EmbossGlowTitle(text: 'S-PATROL'),
                  SizedBox(width: 8),
                  AppVersionText(),
                  // EmbossGlowTitle(text: ApiConfig.version, fontSize: 13),
                ],
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
              ? CommonUI.errorPage(
                  message: errorMessage.toString(),
                  context: context,
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Welcome:",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            (_employeeName.isNotEmpty)
                                ? _employeeName
                                : (widget.accountCode ?? ''),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.lightBlueAccent,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8),
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
                                SizedBox(
                                  width: 150,
                                  child: DropdownButtonFormField<String>(
                                    value: selectedFactory,
                                    // null lúc đầu
                                    isExpanded: true,
                                    dropdownColor: Colors.blueGrey.shade900
                                        .withOpacity(0.95),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.white70,
                                      size: 30,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "plant".tr(context),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.35),
                                          width: 1.2,
                                        ),
                                      ),

                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.35),
                                        ),
                                      ),

                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF7986CB),
                                          width: 1.8,
                                        ),
                                      ),

                                      /// 🏷️ label bình thường
                                      labelStyle: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),

                                      /// 🏷️ label khi bay lên
                                      floatingLabelStyle: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7986CB),
                                      ),

                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),

                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),

                                    items: factories.map((f) {
                                      return DropdownMenuItem<String>(
                                        value: f,
                                        child: Text(f),
                                      );
                                    }).toList(),

                                    onChanged: (val) {
                                      setState(() {
                                        selectedFactory = val;

                                        // 👇 nếu user đổi plant thì coi như chọn tay
                                        _autoTeam = null;
                                        _needManualSelect = true;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Expanded(
                        child: selectedFactory == null
                            ? const SizedBox()
                            : ListView(
                                key: ValueKey(selectedFactory),
                                children: [
                                  _animatedCard(
                                    0,
                                    _patrolGroupCard(
                                      group: PatrolGroup.Patrol,
                                      title: 'Weekly Safety Patrol',
                                      icon: Icons.security,
                                      prefix: 'Patrol',
                                      titleScreen: 'Safety Patrol',
                                    ),
                                  ),
                                  _animatedCard(
                                    1,
                                    _patrolGroupCard(
                                      group: PatrolGroup.Audit,
                                      title: 'SRG Safety Audit',
                                      icon: Icons.groups,
                                      enabled: true,
                                      prefix: 'Audit',
                                      titleScreen: 'Safety Audit',
                                    ),
                                  ),
                                  _animatedCard(
                                    2,
                                    _patrolGroupCard(
                                      group: PatrolGroup.QualityPatrol,
                                      title: 'QA Quality Patrol',
                                      icon: Icons.verified,
                                      prefix: 'QA Patrol',
                                      enabled: true,
                                      titleScreen: 'QA Patrol',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // ⬅️ LOGOUT (LEFT)
                          Positioned(
                            left: 0,
                            child: GlassActionButton(
                              icon: Icons.logout,
                              onTap: () async {
                                final confirm = await CommonUI.showGlassConfirm(
                                  context: context,
                                  icon: Icons.logout_rounded,
                                  iconColor: Colors.redAccent,
                                  title: "Logout",
                                  message: "Do you want to logout?",
                                  cancelText: "Cancel",
                                  confirmText: "Logout",
                                  confirmColor: Colors.redAccent,
                                );

                                if (!confirm || !context.mounted) return;

                                await SessionStore.clear();
                                if (!context.mounted) return;

                                context.go('/'); // ✅ QUAY VỀ LOGIN
                              },

                              // onTap: () async {
                              //   final confirm = await CommonUI.showGlassConfirm(
                              //     context: context,
                              //     icon: Icons.logout_rounded,
                              //     iconColor: Colors.redAccent,
                              //     title: "Logout",
                              //     message: "Do you want to logout?",
                              //     cancelText: "Cancel",
                              //     confirmText: "Logout",
                              //     confirmColor: Colors.redAccent,
                              //   );
                              //
                              //   if (!confirm || !context.mounted) return;
                              //
                              //   await SessionStore.clear();
                              //   if (!context.mounted) return;
                              //
                              //   Navigator.pushAndRemoveUntil(
                              //     context,
                              //     MaterialPageRoute(
                              //       builder: (_) => const LoginPage(),
                              //     ),
                              //     (_) => false,
                              //   );
                              // },
                            ),
                          ),
                          Center(
                            child: QrScanGlassButton(
                              onTap: _openQrScannerDialog,
                              duration: Duration(milliseconds: 900),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _openQrScannerDialog() async {
    final dialogKey = GlobalKey<QrScannerDialogState>(); // ✅ tạo mới mỗi lần
    _qrHandled = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: QrScannerDialog(
          key: dialogKey,
          onDetected: (qr) async {
            if (_qrHandled) return;
            _qrHandled = true;

            await dialogKey.currentState?.stopCamera(); // ✅ dùng key local

            final nav = Navigator.of(ctx, rootNavigator: true);
            if (nav.canPop()) nav.pop();

            await Future.delayed(const Duration(milliseconds: 150));
            if (!mounted) return;

            final rawQr = qr.trim();
            final safeQr = Uri.encodeComponent(rawQr);

            context.go(
              '/after/$safeQr',
              extra: {
                'accountCode': widget.accountCode,
                'qrCode': rawQr,
                'patrolGroup': PatrolGroup.Patrol,
              },
            );
          },
        ),
      ),
    ).whenComplete(() {
      _qrHandled = false;
    });
  }

  String _recheckTitle(PatrolGroup group) {
    switch (group) {
      case PatrolGroup.Patrol:
        return 'HSE ReCheck';
      case PatrolGroup.Audit:
        return 'SRG Recheck';
      case PatrolGroup.QualityPatrol:
        return 'QA Recheck';
    }
  }

  Widget _animatedCard(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 140),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -(1 - value) * 20), // nhẹ hơn 30
            child: child,
          ),
        );
      },
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
        return Colors.purpleAccent.shade100; // QA Quality Audit
    }
  }

  void _onExpandGroup(PatrolGroup group) {
    // Nếu đang mở → click lại thì đóng
    if (expandedGroup == group) {
      setState(() {
        expandedGroup = null;
        _autoTeam = null;
        _needManualSelect = true;
      });
      return;
    }

    // Nếu click group khác → mở group mới
    final team = HseMasterService.findTeamByEmp(
      widget.accountCode,
      group,
      teams,
    );

    setState(() {
      expandedGroup = group;
      _autoTeam = team;
      _needManualSelect = team == null;

      if (team != null) {
        selectedFactory = team.plant;
      }
    });
  }

  Widget _patrolGroupCard({
    required PatrolGroup group,
    required String title,
    required IconData icon,
    required String prefix,
    required String titleScreen,
    bool enabled = true,
  }) {
    final isExpanded = expandedGroup == group;
    final color = _groupColor(group, enabled);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
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
                        _onExpandGroup(group);
                      }
                    : null,

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
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
                  titleScreen: titleScreen,
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
    required String titleScreen,
  }) {
    // final canRecheck = AccessRule().can(
    //   PatrolAction.recheck,
    //   group: group,
    //   user: widget.accountCode,
    // );
    final canBefore = _authMe?.can(group, PatrolAction.before) ?? false;
    final canAfter = _authMe?.can(group, PatrolAction.after) ?? false;
    final canRecheck = _authMe?.can(group, PatrolAction.recheck) ?? false;
    final canTable = _authMe?.can(group, PatrolAction.summary) ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        children: [
          _patrolButton(
            number: '1)',
            title: '$prefix Before',
            color: color,
            enabled: canBefore,
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
                    titleScreen: titleScreen,
                    accountCode: widget.accountCode,
                    autoTeam: _autoTeam,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _patrolButton(
            number: '2)',
            title: 'Action After',
            color: color,
            enabled: canAfter,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AfterDetailScreen(
                    accountCode: widget.accountCode,
                    machines: machines,
                    selectedPlant: selectedFactory,
                    titleScreen: titleScreen,
                    patrolGroup: group,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          _patrolButton(
            number: '3)',
            title: _recheckTitle(group),
            color: color,
            enabled: canRecheck,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecheckDetailScreen(
                    accountCode: widget.accountCode,
                    machines: machines,
                    selectedPlant: selectedFactory,
                    titleScreen: titleScreen,
                    patrolGroup: group,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          _patrolButton(
            number: '4)',
            title: 'Data Table',
            color: color,
            enabled: canTable,
            onTap: () {
              context.go(
                '/home/summary?group=${group.name}&plant=$selectedFactory',
              );
            },
          ),
        ],
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
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
                            'Permission',
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
