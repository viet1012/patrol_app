import 'package:flutter/widgets.dart';

/// Rebuild boundary over a [Listenable] (the Fixed Asset controller).
///
/// [select] takes a snapshot of just the values a section needs (a Dart
/// record, compared field-by-field with `==`); [builder] runs only when that
/// snapshot changes, so unrelated notifications skip the section.
///
/// Collections compare by identity: the controller assigns new lists, and
/// for sets mutated in place the snapshot should include the length too.
class FixedAssetSelector<T> extends StatefulWidget {
  final Listenable listenable;
  final T Function() select;
  final Widget Function(BuildContext context, T value) builder;

  const FixedAssetSelector({
    super.key,
    required this.listenable,
    required this.select,
    required this.builder,
  });

  @override
  State<FixedAssetSelector<T>> createState() => _FixedAssetSelectorState<T>();
}

class _FixedAssetSelectorState<T> extends State<FixedAssetSelector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select();
    widget.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant FixedAssetSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.listenable, widget.listenable)) {
      oldWidget.listenable.removeListener(_onChanged);
      widget.listenable.addListener(_onChanged);
    }
    _value = widget.select();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.select();
    if (next == _value) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
