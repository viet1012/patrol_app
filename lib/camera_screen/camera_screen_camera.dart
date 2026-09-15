part of '../test.dart';

extension _CameraScreenCamera on _CameraScreenState {
  Future<void> _toggleCameraPower() async {
    if (_cameraSwitching) return;

    final camera = _cameraKey.currentState;
    if (camera == null) {
      if (!mounted) return;
      CommonUI.showWarning(
        context: context,
        title: 'Camera Error',
        message: 'Camera is not ready.',
      );
      return;
    }

    setState(() => _cameraSwitching = true);

    try {
      final success = camera.isCameraSleeping
          ? await camera.wakeCamera()
          : await _sleepCamera(camera);

      if (!mounted) return;

      _cameraUiSleeping = camera.isCameraSleeping;

      if (!success && !camera.isCameraSleeping) {
        CommonUI.showWarning(
          context: context,
          title: 'Camera Error',
          message: 'Unable to start camera. Please check camera permission.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Toggle camera error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      CommonUI.showWarning(
        context: context,
        title: 'Camera Error',
        message: 'Unable to change camera state.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _cameraSwitching = false;
          _cameraUiSleeping = _cameraKey.currentState?.isCameraSleeping ?? true;
        });
      }
    }
  }

  Future<bool> _sleepCamera(CameraPreviewBoxState camera) async {
    await camera.sleepCamera();
    return camera.isCameraSleeping;
  }

  void _onCameraSleepingChanged(bool sleeping) {
    if (!mounted || _cameraUiSleeping == sleeping) return;
    setState(() => _cameraUiSleeping = sleeping);
  }

  Widget _buildBatterySavingTip() {
    final sleeping = _cameraUiSleeping;
    final color = sleeping ? const Color(0xFF22C55E) : Colors.amber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.32)),
      ),
      child: Row(
        children: [
          Icon(
            sleeping
                ? Icons.videocam_off_rounded
                : Icons.battery_saver_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Battery Saving',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sleeping
                      ? 'Camera and QR scanner are off.'
                      : 'Turn off camera while walking to save battery.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.68),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _cameraSwitching ? null : _toggleCameraPower,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minWidth: 58, minHeight: 30),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _cameraSwitching
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      sleeping ? 'WAKE' : 'OFF',
                      style: TextStyle(
                        color: sleeping ? Colors.white : Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return SizedBox(
      width: 340,
      height: 340,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CameraPreviewBox(
              key: _cameraKey,
              size: 340,
              plant: _selectedPlant,
              type: widget.patrolGroup.name,
              group: _selectedGroup,
              patrolGroup: widget.patrolGroup,
              onImagesChanged: (images) {
                _imagesNotifier.value = List<Uint8List>.unmodifiable(images);
              },
              onQrDetected: _handleQrDetected,
              onCameraSleepingChanged: _onCameraSleepingChanged,
            ),
          ),
          if (_isCheckingQr && !_cameraUiSleeping)
            Positioned.fill(child: _buildCheckingQrOverlay()),
        ],
      ),
    );
  }

  Widget _buildCheckingQrOverlay() {
    return Container(
      alignment: Alignment.center,
      color: Colors.black.withOpacity(.20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF22C55E).withOpacity(.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Checking QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((_checkingQrKey ?? '').isNotEmpty)
                  Text(
                    _checkingQrKey!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
