import 'dart:async';
import 'dart:ui';

import 'package:chuphinh/widget/glass_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../LanguageFlagButton.dart';
import '../after/after_overview_screen.dart';
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

enum PatrolGroup { Patrol, Audit, QualityPatrol, AssetUpdate }

enum PatrolAction { before, after, recheck, summary }

class PatrolHomeScreen extends StatefulWidget {
  final String accountCode;

  const PatrolHomeScreen({super.key, required this.accountCode});

  @override
  State<PatrolHomeScreen> createState() => _PatrolHomeScreenState();
}

class _PatrolHomeScreenState extends State<PatrolHomeScreen> {
  // ============================================================
  // STATE
  // ============================================================

  String? selectedFactory;
  String currentLang = 'VI';

  List<MachineModel> machines = const [];
  List<HsePatrolTeamModel> teams = const [];
  List<String> _factories = const [];

  bool isLoading = true;
  String? errorMessage;

  PatrolGroup? expandedGroup;

  String _employeeName = '';
  HsePatrolTeamModel? _autoTeam;
  bool _needManualSelect = true;
  bool _qrHandled = false;
  AuthMe? _authMe;

  // Chỉ dùng để chặn init trùng trong trường hợp widget bị gắn lại bất thường.
  bool _initializing = false;

  // ============================================================
  // CONSTANT UI
  // ============================================================

  static const _pageGradient = LinearGradient(
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _appBarColor = Color(0xFF0F2027);

  static final BoxDecoration _glassDecorationSmall = BoxDecoration(
    color: Colors.white.withOpacity(.10),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(.22), width: 1),
  );

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Cho frame đầu tiên render trước, sau đó mới bắt đầu tải.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeScreen();
      }
    });
  }

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  Future<void> _initializeScreen() async {
    if (_initializing) return;
    _initializing = true;

    try {
      /*
       * Chạy song song các request không phụ thuộc nhau.
       *
       * Trước đây:
       * auth -> session -> machines -> teams
       *
       * Bây giờ:
       * auth, session, machines, teams, employee chạy cùng lúc.
       */
      final results = await Future.wait<dynamic>([
        _fetchAuthMe(),
        SessionStore.getPlant(widget.accountCode),
        HseMasterService.fetchMachines(),
        HseMasterService.fetchAll(),
        _fetchEmployeeNameValue(widget.accountCode),
      ]);

      if (!mounted) return;

      final authMe = results[0] as AuthMe?;
      final savedPlant = results[1] as String?;
      final loadedMachines = results[2] as List<MachineModel>;
      final loadedTeams = results[3] as List<HsePatrolTeamModel>;
      final employeeName = results[4] as String;

      final hrPlant = authMe?.plant?.trim();
      final sessionPlant = savedPlant?.trim();

      String? initialPlant;
      if (hrPlant != null && hrPlant.isNotEmpty) {
        initialPlant = hrPlant;
      } else if (sessionPlant != null && sessionPlant.isNotEmpty) {
        initialPlant = sessionPlant;
      }

      final patrolTeam = HseMasterService.findTeamByEmp(
        widget.accountCode,
        PatrolGroup.Patrol,
        loadedTeams,
      );

      final factories = _buildFactories(loadedMachines, loadedTeams);

      // Nếu plant từ HR/session không còn trong master thì không tự đổi bừa.
      final validInitialPlant = factories.contains(initialPlant)
          ? initialPlant
          : null;

      setState(() {
        _authMe = authMe;
        machines = List.unmodifiable(loadedMachines);
        teams = List.unmodifiable(loadedTeams);
        _factories = List.unmodifiable(factories);

        _employeeName = employeeName;
        selectedFactory = validInitialPlant;

        _autoTeam = patrolTeam;
        expandedGroup = patrolTeam == null ? null : PatrolGroup.Patrol;
        _needManualSelect = patrolTeam == null;

        errorMessage = null;
        isLoading = false;
      });

      // Save ngoài setState, không chặn render UI.
      if (hrPlant != null && hrPlant.isNotEmpty) {
        unawaited(SessionStore.savePlant(widget.accountCode, hrPlant));
      }
    } catch (error, stackTrace) {
      debugPrint('PatrolHome initialize error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    } finally {
      _initializing = false;
    }
  }

  Future<AuthMe?> _fetchAuthMe() async {
    try {
      final response = await DioClient.get(
        '/api/hr/me',
        queryParameters: {'code': widget.accountCode},
      );

      if (response.statusCode == 200 && response.data != null) {
        return AuthMe.fromJson(Map<String, dynamic>.from(response.data));
      }
    } catch (error) {
      // Auth permission lỗi không nên làm toàn màn hình fail.
      debugPrint('Load auth me error: $error');
    }

    return null;
  }

  Future<String> _fetchEmployeeNameValue(String code) async {
    final employeeCode = code.trim();
    if (employeeCode.isEmpty) return '';

    try {
      final response = await DioClient.get(
        '/api/hr/name',
        queryParameters: {'code': employeeCode},
      );

      if (response.statusCode == 200) {
        return response.data?.toString().trim() ?? '';
      }
    } catch (error) {
      // Tên nhân viên chỉ là dữ liệu phụ, không làm fail màn hình.
      debugPrint('Load employee name error: $error');
    }

    return '';
  }

  List<String> _buildFactories(
    List<MachineModel> machineItems,
    List<HsePatrolTeamModel> teamItems,
  ) {
    final values = <String>{};

    for (final machine in machineItems) {
      final plant = machine.plant?.toString().trim() ?? '';
      if (plant.isNotEmpty) values.add(plant);
    }

    for (final team in teamItems) {
      final plant = team.plant?.trim() ?? '';
      if (plant.isNotEmpty) values.add(plant);
    }

    final result = values.toList(growable: false);

    result.sort((a, b) {
      final aNumber = _extractTrailingNumber(a);
      final bNumber = _extractTrailingNumber(b);

      final numberCompare = aNumber.compareTo(bNumber);
      if (numberCompare != 0) return numberCompare;

      return a.compareTo(b);
    });

    return result;
  }

  int _extractTrailingNumber(String value) {
    final part = value.split('_').last;
    return int.tryParse(part) ?? 999999;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final validFactory = _factories.contains(selectedFactory)
        ? selectedFactory
        : null;

    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: _PatrolAppBar(),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _pageGradient),
        child: SafeArea(child: _buildBody(validFactory)),
      ),
    );
  }

  Widget _buildBody(String? validFactory) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.lightBlueAccent,
          strokeWidth: 2.5,
        ),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return CommonUI.errorPage(message: errorMessage!, context: context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeHeader(
            employeeName: _employeeName,
            accountCode: widget.accountCode,
          ),
          const SizedBox(height: 8),
          _buildToolbar(validFactory),
          const SizedBox(height: 18),
          Expanded(child: _buildGroupList()),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildToolbar(String? validFactory) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: _glassDecorationSmall,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LanguageToggleSwitch(
              onLanguageChanged: (language) {
                if (language == currentLang) return;

                setState(() {
                  currentLang = language;
                });
              },
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: validFactory,
                isExpanded: true,
                dropdownColor: const Color(0xFF17242C),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white70,
                  size: 30,
                ),
                decoration: InputDecoration(
                  labelText: 'plant'.tr(context),
                  filled: true,
                  fillColor: Colors.white.withOpacity(.10),
                  border: _plantBorder(Colors.white.withOpacity(.28)),
                  enabledBorder: _plantBorder(Colors.white.withOpacity(.28)),
                  focusedBorder: _plantBorder(
                    const Color(0xFF7986CB),
                    width: 1.6,
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                  floatingLabelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7986CB),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                items: _factories
                    .map(
                      (factory) => DropdownMenuItem<String>(
                        value: factory,
                        child: Text(factory),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _onFactoryChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _plantBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Future<void> _onFactoryChanged(String? value) async {
    if (value == selectedFactory) return;

    setState(() {
      selectedFactory = value;
      _autoTeam = null;
      _needManualSelect = true;
    });

    if (value != null && value.isNotEmpty) {
      await SessionStore.savePlant(widget.accountCode, value);
    }
  }

  Widget _buildGroupList() {
    if (selectedFactory == null) {
      return const SizedBox.shrink();
    }

    /*
     * ListView.builder chỉ build card cần hiển thị.
     * Tránh tạo sẵn toàn bộ cây widget con trong frame đầu.
     */
    return ListView.builder(
      key: ValueKey(selectedFactory),
      cacheExtent: 200,
      physics: const BouncingScrollPhysics(),
      itemCount: PatrolGroup.values.length,
      itemBuilder: (context, index) {
        final group = PatrolGroup.values[index];
        final config = _groupConfig(group);

        return RepaintBoundary(
          child: _PatrolEntryAnimation(
            index: index,
            child: _patrolGroupCard(
              group: group,
              title: config.title,
              icon: config.icon,
              prefix: config.prefix,
              titleScreen: config.titleScreen,
              enabled: config.enabled,
            ),
          ),
        );
      },
    );
  }

  _GroupConfig _groupConfig(PatrolGroup group) {
    switch (group) {
      case PatrolGroup.Patrol:
        return const _GroupConfig(
          title: 'Weekly Safety Patrol',
          icon: Icons.security,
          prefix: 'Patrol',
          titleScreen: 'Safety Patrol',
        );
      case PatrolGroup.Audit:
        return const _GroupConfig(
          title: 'SRG Safety Audit',
          icon: Icons.groups,
          prefix: 'Audit',
          titleScreen: 'Safety Audit',
        );
      case PatrolGroup.QualityPatrol:
        return const _GroupConfig(
          title: 'QA Quality Patrol',
          icon: Icons.verified,
          prefix: 'QA Patrol',
          titleScreen: 'QA Patrol',
        );
      case PatrolGroup.AssetUpdate:
        return const _GroupConfig(
          title: 'Asset Update',
          icon: Icons.inventory_rounded,
          prefix: 'Asset Patrol',
          titleScreen: 'Asset Patrol',
        );
    }
  }

  Widget _buildBottomActions() {
    return SizedBox(
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: GlassActionButton(icon: Icons.logout, onTap: _logout),
          ),
          Center(
            child: QrScanGlassButton(
              onTap: _openQrScannerDialog,
              duration: const Duration(milliseconds: 900),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await CommonUI.showGlassConfirm(
      context: context,
      icon: Icons.logout_rounded,
      iconColor: Colors.redAccent,
      title: 'Logout',
      message: 'Do you want to logout?',
      cancelText: 'Cancel',
      confirmText: 'Logout',
      confirmColor: Colors.redAccent,
    );

    if (!confirmed || !mounted) return;

    await SessionStore.clear();

    if (!mounted) return;
    context.go('/');
  }

  // ============================================================
  // GROUP CARD
  // ============================================================

  Color _groupColor(PatrolGroup group, bool enabled) {
    if (!enabled) {
      return Colors.white.withOpacity(.5);
    }

    switch (group) {
      case PatrolGroup.Patrol:
        return Colors.lightBlueAccent.shade400;
      case PatrolGroup.Audit:
        return Colors.green.shade400;
      case PatrolGroup.QualityPatrol:
        return Colors.purpleAccent.shade100;
      case PatrolGroup.AssetUpdate:
        return Colors.yellow.shade700;
    }
  }

  void _onExpandGroup(PatrolGroup group) {
    if (expandedGroup == group) {
      setState(() {
        expandedGroup = null;
        _autoTeam = null;
        _needManualSelect = true;
      });
      return;
    }

    final team = HseMasterService.findTeamByEmp(
      widget.accountCode,
      group,
      teams,
    );

    setState(() {
      expandedGroup = group;
      _autoTeam = team;
      _needManualSelect = team == null;
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
    final expanded = expandedGroup == group;
    final color = _groupColor(group, enabled);

    /*
     * Bỏ BackdropFilter ở từng card.
     * Blur trên nhiều card là nguyên nhân raster lag lớn trên Flutter Web.
     * Nền trong suốt + border vẫn giữ cảm giác glass nhưng nhẹ hơn nhiều.
     */
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(.90), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: enabled ? () => _onExpandGroup(group) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
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
                  if (enabled)
                    AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Icon(Icons.expand_more, size: 34, color: color),
                    )
                  else
                    Icon(Icons.lock_outline, color: color, size: 26),
                ],
              ),
            ),
          ),

          /*
           * Chỉ tạo child khi expanded.
           * AnimatedCrossFade trước đây luôn giữ cả firstChild và secondChild.
           */
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _childPatrolContainer(
                      group: group,
                      prefix: prefix,
                      color: color,
                      titleScreen: titleScreen,
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _childPatrolContainer({
    required PatrolGroup group,
    required String prefix,
    required Color color,
    required String titleScreen,
  }) {
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
            onTap: () => _openBefore(group, titleScreen),
          ),
          const SizedBox(height: 16),
          _patrolButton(
            number: '2)',
            title: 'Action After',
            color: color,
            enabled: canAfter,
            onTap: () => _openAfter(group, titleScreen),
          ),
          const SizedBox(height: 16),
          _patrolButton(
            number: '3)',
            title: _recheckTitle(group),
            color: color,
            enabled: canRecheck,
            onTap: () => _openRecheck(group, titleScreen),
          ),
          const SizedBox(height: 16),
          _patrolButton(
            number: '4)',
            title: 'Data Table',
            color: color,
            enabled: canTable,
            onTap: () => _openSummary(group),
          ),
        ],
      ),
    );
  }

  Widget _patrolButton({
    required String number,
    required String title,
    required Color color,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: color.withOpacity(.11),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(.85), width: 1),
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
                if (enabled)
                  CallToActionArrow(color: color)
                else
                  Icon(Icons.lock_outline, color: color, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openBefore(PatrolGroup group, String titleScreen) {
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
  }

  void _openAfter(PatrolGroup group, String titleScreen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AfterOverviewScreen(
          accountCode: widget.accountCode,
          machines: machines,
          selectedPlant: selectedFactory,
          titleScreen: titleScreen,
          patrolGroup: group,
        ),
      ),
    );
  }

  void _openRecheck(PatrolGroup group, String titleScreen) {
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
  }

  void _openSummary(PatrolGroup group) {
    context.go(
      '/home/summary?group=${group.name}&plant=$selectedFactory',
      extra: {'accountCode': widget.accountCode, 'me': _authMe},
    );
  }

  String _recheckTitle(PatrolGroup group) {
    switch (group) {
      case PatrolGroup.Patrol:
        return 'HSE ReCheck';
      case PatrolGroup.Audit:
        return 'SRG Recheck';
      case PatrolGroup.QualityPatrol:
        return 'QA Recheck';
      case PatrolGroup.AssetUpdate:
        return 'Asset Recheck';
    }
  }

  // ============================================================
  // QR DIALOG
  // ============================================================

  Future<void> _openQrScannerDialog() async {
    final dialogKey = GlobalKey<QrScannerDialogState>();
    _qrHandled = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: QrScannerDialog(
            key: dialogKey,
            onDetected: (qr) async {
              if (_qrHandled) return;
              _qrHandled = true;

              await dialogKey.currentState?.stopCamera();

              if (dialogContext.mounted) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              }

              if (!mounted) return;

              final rawQr = qr.trim();
              if (rawQr.isEmpty) return;

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
        );
      },
    );

    _qrHandled = false;
  }
}

// ============================================================
// STATIC / SMALL WIDGETS
// ============================================================

class _PatrolAppBar extends StatelessWidget {
  const _PatrolAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      backgroundColor: _PatrolHomeScreenState._appBarColor,
      elevation: 0,
      title: RepaintBoundary(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/flags/favicon.png',
              width: 40,
              height: 40,
              filterQuality: FilterQuality.medium,
              fit: BoxFit.contain,
              cacheWidth: 80,
              cacheHeight: 80,
            ),
            const SizedBox(width: 8),
            EmbossGlowTitle(text: 'S-PATROL'),
            const SizedBox(width: 8),
            AppVersionText(),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  final String employeeName;
  final String accountCode;

  const _WelcomeHeader({required this.employeeName, required this.accountCode});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Welcome:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            employeeName.isNotEmpty ? employeeName : accountCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, color: Colors.lightBlueAccent),
          ),
        ),
      ],
    );
  }
}

class _PatrolEntryAnimation extends StatelessWidget {
  final int index;
  final Widget child;

  const _PatrolEntryAnimation({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    /*
     * Animation ngắn hơn và khoảng cách stagger nhỏ hơn.
     * Không dùng blur hoặc scale nên raster nhẹ.
     */
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 45),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, cachedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: cachedChild,
          ),
        );
      },
    );
  }
}

class _GroupConfig {
  final String title;
  final IconData icon;
  final String prefix;
  final String titleScreen;
  final bool enabled;

  const _GroupConfig({
    required this.title,
    required this.icon,
    required this.prefix,
    required this.titleScreen,
    this.enabled = true,
  });
}
