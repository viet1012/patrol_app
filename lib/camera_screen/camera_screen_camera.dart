part of '../test.dart';

extension _CameraScreenCamera on _CameraScreenState {
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
              enablePowerControl: true,
              // Cùng kiểu switch với FixedAssetScreen.
              useSwitchPowerControl: true,
              enableZoomControls: true,
            ),
          ),
          if (_isCheckingQr)
            Positioned.fill(
              child: IgnorePointer(child: _buildCheckingQrOverlay()),
            ),
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
