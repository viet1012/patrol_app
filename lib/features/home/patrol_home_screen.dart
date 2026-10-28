import 'dart:async';

import 'package:chuphinh/core/api/auth_me_api.dart';
import 'package:chuphinh/core/api/fixed_asset_backend.dart';
import 'package:chuphinh/shared/widgets/glass_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chuphinh/features/home/widgets/language_flag_button.dart';
import 'package:chuphinh/features/patrol/after/after_overview_screen.dart';
import 'package:chuphinh/shared/animations/call_to_action_arrow.dart';
import 'package:chuphinh/shared/animations/glow_title.dart';
import 'package:chuphinh/core/network/dio_client.dart';
import 'package:chuphinh/core/api/hse_master_service.dart';
import 'package:chuphinh/shared/widgets/animated_glass_action_button.dart';
import 'package:chuphinh/shared/widgets/app_version_text.dart';
import 'package:chuphinh/shared/widgets/common_ui_helper.dart';
import 'package:chuphinh/shared/utils/plant_constants.dart';
import 'package:chuphinh/core/models/patrol_group.dart';
import 'package:chuphinh/core/permission/patrol_group_ui.dart';
import 'package:chuphinh/features/fixed_asset/fixed_asset_screen.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_badge.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_screen.dart';
import 'package:chuphinh/features/fixed_asset/reprint/fixed_asset_reprint_strings.dart';
import 'package:chuphinh/core/models/auth_me.dart';
import 'package:chuphinh/core/models/group_access.dart';
import 'package:chuphinh/core/models/hse_patrol_team_model.dart';
import 'package:chuphinh/core/models/machine_model.dart';
import 'package:chuphinh/shared/qr/qr_scanner_dialog.dart';
import 'package:chuphinh/features/patrol/recheck/recheck_detail_screen.dart';
import 'package:chuphinh/core/session/session_store.dart';
import 'package:chuphinh/features/patrol/before/patrol_before_screen.dart';
import 'package:chuphinh/core/i18n/translator.dart';

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

  /// Quyền theo group, tính 1 lần sau khi tải AuthMe.
  Map<PatrolGroup, GroupAccess> _access = const {};

  /// Tải AuthMe lỗi: ẩn mọi group, hiện banner "Thử lại".
  bool _authFailed = false;
  bool _authRetrying = false;

  /// Số máy cần in lại QR (badge). `null` = chưa tải / lỗi.
  int? _reprintCount;

  /// Đã tải lần đầu (khi mở card Fixed Asset) -> đóng/mở card không tải lại.
  bool _reprintFetched = false;

  /// Bỏ qua kết quả của request cũ nếu có request mới hơn.
  int _reprintRequestId = 0;

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

      final access = GroupAccess.mapOf(authMe);
      final autoExpand =
          patrolTeam != null && access[PatrolGroup.Patrol]!.any;

      setState(() {
        _access = access;
        _authFailed = authMe == null;
        machines = List.unmodifiable(loadedMachines);
        teams = List.unmodifiable(loadedTeams);
        _factories = List.unmodifiable(factories);

        _employeeName = employeeName;
        selectedFactory = validInitialPlant;

        _autoTeam = patrolTeam;
        expandedGroup = autoExpand ? PatrolGroup.Patrol : null;
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

  // Auth permission lỗi không nên làm toàn màn hình fail -> trả null.
  // AuthMeApi.fetch đã tự catch và trả null khi lỗi -> null = tải quyền lỗi.
  Future<AuthMe?> _fetchAuthMe() => AuthMeApi.fetch(widget.accountCode);

  GroupAccess _accessOf(PatrolGroup group) =>
      _access[group] ?? GroupAccess.none;

  Future<void> _retryAuthMe() async {
    if (_authRetrying) return;
    setState(() => _authRetrying = true);

    final authMe = await _fetchAuthMe();
    if (!mounted) return;

    setState(() {
      _authRetrying = false;
      _access = GroupAccess.mapOf(authMe);
      _authFailed = authMe == null;

      // Lần đầu chưa có plant (do HR lỗi) -> dùng plant HR nếu hợp lệ.
      final hrPlant = authMe?.plant?.trim();
      if (selectedFactory == null && _factories.contains(hrPlant)) {
        selectedFactory = hrPlant;
      }

      if (expandedGroup != null && !_visibleGroups.contains(expandedGroup)) {
        expandedGroup = null;
      }
    });
  }

  void _showNoPermission() {
    CommonUI.showSnackBar(
      context: context,
      message: 'no_permission'.tr(context),
      color: Colors.redAccent,
    );
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

    // SPC luôn đứng đầu, không trùng nếu master có sẵn.
    values.remove(kAllPlantCode);

    final result = values.toList(growable: false);

    result.sort((a, b) {
      final aNumber = _extractTrailingNumber(a);
      final bNumber = _extractTrailingNumber(b);

      final numberCompare = aNumber.compareTo(bNumber);
      if (numberCompare != 0) return numberCompare;

      return a.compareTo(b);
    });

    return [kAllPlantCode, ...result];
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
          if (_authFailed) ...[
            const SizedBox(height: 8),
            _buildAuthFailedBanner(),
          ],
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

  Widget _buildAuthFailedBanner() {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: _glassDecorationSmall.copyWith(
        border: Border.all(color: Colors.orangeAccent.withOpacity(.6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'perm_load_failed'.tr(context),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: _authRetrying ? null : _retryAuthMe,
            child: _authRetrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orangeAccent,
                    ),
                  )
                : Text(
                    'retry'.tr(context),
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
          ),
        ],
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

      // Group đang mở bị ẩn ở plant mới -> quay về Patrol (nếu Patrol hiện).
      final visible = _visibleGroups;
      if (expandedGroup != null && !visible.contains(expandedGroup)) {
        expandedGroup = visible.contains(PatrolGroup.Patrol)
            ? PatrolGroup.Patrol
            : null;
      }
    });

    if (value != null && value.isNotEmpty) {
      await SessionStore.savePlant(widget.accountCode, value);
    }
  }

  bool get _isAllPlant => isAllPlant(selectedFactory);

  // SPC chỉ xem Data Table của Patrol (cần quyền summary), group khác ẩn.
  // Plant thường: group có ít nhất 1 quyền. Group không quyền -> ẩn.
  List<PatrolGroup> get _visibleGroups {
    if (_isAllPlant) {
      return _accessOf(PatrolGroup.Patrol).summary
          ? const [PatrolGroup.Patrol]
          : const [];
    }

    return PatrolGroup.values
        .where((g) => _accessOf(g).any)
        .toList(growable: false);
  }

  Widget _buildGroupList() {
    if (selectedFactory == null) {
      return const SizedBox.shrink();
    }

    final groups = _visibleGroups;

    /*
     * ListView.builder chỉ build card cần hiển thị.
     * Tránh tạo sẵn toàn bộ cây widget con trong frame đầu.
     */
    return ListView.builder(
      key: ValueKey(selectedFactory),
      cacheExtent: 200,
      physics: const BouncingScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];

        return RepaintBoundary(
          child: _PatrolEntryAnimation(
            index: index,
            child: _patrolGroupCard(group: group, ui: kPatrolGroupUi[group]!),
          ),
        );
      },
    );
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
          if (_accessOf(PatrolGroup.Patrol).after)
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

    if (group == PatrolGroup.FixedAsset && !_reprintFetched) {
      _fetchReprintCount();
    }
  }

  // Group không quyền đã bị ẩn ở _visibleGroups -> card luôn mở được.
  Widget _patrolGroupCard({
    required PatrolGroup group,
    required PatrolGroupUi ui,
  }) {
    final expanded = expandedGroup == group;
    final color = ui.color;

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
            onTap: () => _onExpandGroup(group),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
              child: Row(
                children: [
                  Icon(ui.icon, color: color, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ui.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: Icon(Icons.expand_more, size: 34, color: color),
                  ),
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
                  ? _childPatrolContainer(group: group, ui: ui)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _childPatrolContainer({
    required PatrolGroup group,
    required PatrolGroupUi ui,
  }) {
    final access = _accessOf(group);
    final color = ui.color;
    final prefix = ui.prefix;
    final titleScreen = ui.titleScreen;

    // Fixed Asset không thuộc workflow Patrol: kiểm kê + in lại QR.
    if (group == PatrolGroup.FixedAsset) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Column(
          children: [
            _patrolButton(
              number: '1)',
              title: 'Open Fixed Asset',
              color: color,
              enabled: access.can(kFixedAssetAuditAction),
              onTap: _openFixedAsset,
            ),
            const SizedBox(height: 16),
            _patrolButton(
              number: '2)',
              title: FixedAssetReprintStrings.menuTitle,
              color: color,
              enabled: access.can(kFixedAssetReprintAction),
              onTap: _openFixedAssetReprint,
              badge: FixedAssetReprintBadge(
                color: color,
                count: _reprintCount,
              ),
            ),
          ],
        ),
      );
    }

    // SPC (tất cả nhà máy): chỉ xem Data Table.
    if (_isAllPlant) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: _patrolButton(
          number: '1)',
          title: 'Data Table',
          color: color,
          enabled: access.summary,
          onTap: () => _openSummary(group),
        ),
      );
    }

    // Chỉ render nút group có; số thứ tự đánh theo nút thực sự hiện ra.
    final buttons = <Widget>[];
    void addButton(
      PatrolAction action,
      String title,
      bool enabled,
      VoidCallback onTap,
    ) {
      if (!ui.actions.contains(action)) return;
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 16));
      buttons.add(
        _patrolButton(
          number: '${(buttons.length ~/ 2) + 1})',
          title: title,
          color: color,
          enabled: enabled,
          onTap: onTap,
        ),
      );
    }

    addButton(
      PatrolAction.before,
      '$prefix Before',
      access.before,
      () => _openBefore(group, titleScreen),
    );
    addButton(
      PatrolAction.after,
      'Action After',
      access.after,
      () => _openAfter(group, titleScreen),
    );
    addButton(
      PatrolAction.recheck,
      ui.recheckTitle,
      access.recheck,
      () => _openRecheck(group, titleScreen),
    );
    addButton(
      PatrolAction.summary,
      'Data Table',
      access.summary,
      () => _openSummary(group),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(children: buttons),
    );
  }

  Widget _patrolButton({
    required String number,
    required String title,
    required Color color,
    required bool enabled,
    VoidCallback? onTap,
    Widget? badge,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: enabled ? onTap : _showNoPermission,
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
                        Text(
                          'no_permission'.tr(context),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (badge != null) ...[badge, const SizedBox(width: 10)],
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

  void _openFixedAsset() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixedAssetScreen(
          accountCode: widget.accountCode,
          selectedPlant: selectedFactory,
          userName: _employeeName,
        ),
      ),
    ).then((_) => _fetchReprintCount());
  }

  /// "In lại QR" lấy mọi xưởng (audit lưu theo xưởng, không theo nhà máy).
  void _openFixedAssetReprint() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FixedAssetReprintScreen()),
    ).then((_) => _fetchReprintCount());
  }

  /// Tải số máy cần in lại QR cho badge. Lỗi: giữ số cũ.
  Future<void> _fetchReprintCount() async {
    _reprintFetched = true;
    final requestId = ++_reprintRequestId;
    try {
      final rows = await const FixedAssetBackend().fetchQrMismatch();
      if (!mounted || requestId != _reprintRequestId) return;
      setState(() => _reprintCount = rows.length);
    } catch (_) {
      // Lỗi: giữ nguyên badge.
    }
  }

  void _openBefore(PatrolGroup group, String titleScreen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatrolBeforeScreen(
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
    // Tham số nằm trong URL (không dùng extra) để F5 vẫn giữ trang.
    context.go(
      Uri(
        path: '/home/summary',
        queryParameters: {'group': group.name, 'plant': selectedFactory ?? ''},
      ).toString(),
    );
  }

  // ============================================================
  // QR DIALOG
  // ============================================================

  Future<void> _openQrScannerDialog() async {
    if (!_accessOf(PatrolGroup.Patrol).after) {
      _showNoPermission();
      return;
    }

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

              context.go(
                Uri(
                  path: '/after/${Uri.encodeComponent(rawQr)}',
                  queryParameters: {'group': PatrolGroup.Patrol.name},
                ).toString(),
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
