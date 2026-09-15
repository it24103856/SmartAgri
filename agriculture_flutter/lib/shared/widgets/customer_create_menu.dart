import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Keeps unfinished content while the customer switches tabs.
class CustomerDraft {
  String text = '';
  bool isQuestion = true;
  Uint8List? photo;
}

enum CustomerCreateAction { camera, text }

Future<CustomerCreateAction?> showCustomerCreateMenu(BuildContext context) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<CustomerCreateAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close create menu',
    barrierColor: Colors.black38,
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 850),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _BouncingCreateMenu(animation: animation),
    // Each ball follows its own path instead of sliding the whole menu.
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

class _BouncingCreateMenu extends StatelessWidget {
  final Animation<double> animation;

  const _BouncingCreateMenu({required this.animation});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 23),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: 248,
              height: 208,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final t = animation.value;
                  // Wind up, launch both actions together, then bounce on landing.
                  final travel = ((t - 0.12) / 0.66).clamp(0.0, 1.0);
                  final spread = Curves.easeInOutCubic.transform(travel);
                  final landing = ((t - 0.78) / 0.22).clamp(0.0, 1.0);
                  final jump = math.sin(math.pi * travel);
                  final actionLift =
                      38 * jump + 10 * math.sin(math.pi * landing);
                  final centerLift = 30 * math.sin(math.pi * t);
                  final labelOpacity = ((t - 0.72) / 0.28).clamp(0.0, 1.0);

                  Widget action(
                    String label,
                    IconData icon,
                    CustomerCreateAction value,
                    double side,
                  ) {
                    return Positioned(
                      left: 124 + side * 64 * spread - 48,
                      top: 184 - 104 * spread - actionLift - 28,
                      width: 96,
                      child: IgnorePointer(
                        ignoring: t < 0.5,
                        child: Opacity(
                          opacity: (travel * 5).clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: side * (1 - t) * 0.3,
                                child: Transform.scale(
                                  scale: 0.35 + 0.65 * spread,
                                  child: FloatingActionButton(
                                    heroTag: null,
                                    tooltip: label,
                                    shape: const CircleBorder(),
                                    elevation: 5 + 5 * jump,
                                    backgroundColor: colors.surface,
                                    foregroundColor: colors.primary,
                                    onPressed: () =>
                                        Navigator.pop(context, value),
                                    child: Icon(icon, size: 27),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Opacity(
                                opacity: labelOpacity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      action(
                        'Camera',
                        Icons.photo_camera_outlined,
                        CustomerCreateAction.camera,
                        -1,
                      ),
                      action(
                        'Write text',
                        Icons.edit_note_rounded,
                        CustomerCreateAction.text,
                        1,
                      ),
                      Positioned(
                        left: 100,
                        bottom: centerLift,
                        child: Transform.scale(
                          scaleX: 1 + 0.10 * jump,
                          scaleY: 1 - 0.08 * jump,
                          child: IconButton.filled(
                            tooltip: 'Close create menu',
                            onPressed: () => Navigator.pop(context),
                            icon: Transform.rotate(
                              angle:
                                  Curves.easeInOutCubic.transform(t) *
                                  math.pi /
                                  4,
                              child: const Icon(Icons.add_rounded, size: 30),
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              maximumSize: const Size(48, 48),
                              elevation: 4 + 6 * jump,
                              shadowColor: colors.primary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerComposerScreen extends StatefulWidget {
  final CustomerDraft draft;
  final bool openCamera;

  const CustomerComposerScreen({
    super.key,
    required this.draft,
    this.openCamera = false,
  });

  @override
  State<CustomerComposerScreen> createState() => _CustomerComposerScreenState();
}

class _CustomerComposerScreenState extends State<CustomerComposerScreen> {
  late final TextEditingController _text;
  bool _takingPhoto = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.draft.text);
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _takePhoto();
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto) return;
    setState(() {
      _takingPhoto = true;
      _cameraError = null;
    });
    try {
      final picker = ImagePicker();
      if (!picker.supportsImageSource(ImageSource.camera)) {
        setState(
          () => _cameraError =
              'Camera is not available on this device. You can still write below.',
        );
        return;
      }
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => widget.draft.photo = bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => _cameraError =
              'Could not open the camera. Check camera permission in Settings and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draft.isQuestion ? 'Ask a farming question' : 'Create a post',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.help_outline),
                  label: Text('Question'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit_outlined),
                  label: Text('Post'),
                ),
              ],
              selected: {widget.draft.isQuestion},
              onSelectionChanged: (selection) =>
                  setState(() => widget.draft.isQuestion = selection.single),
            ),
            const SizedBox(height: 16),
            Text(
              'Draft only — not published. Kept while you use the app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (widget.draft.photo case final photo?) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(photo, height: 240, fit: BoxFit.contain),
              ),
              TextButton.icon(
                onPressed: () => setState(() => widget.draft.photo = null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove photo'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _takingPhoto ? null : _takePhoto,
              icon: _takingPhoto
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(
                widget.draft.photo == null ? 'Take photo' : 'Retake photo',
              ),
            ),
            if (_cameraError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _cameraError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _text,
              autofocus: !widget.openCamera,
              minLines: 5,
              maxLines: 12,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) => widget.draft.text = value,
              decoration: const InputDecoration(
                labelText: 'Write text',
                hintText: 'Write something here…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
