import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uconnecta/app_services.dart';
import 'package:uconnecta/data/constrains.dart';
import 'package:uconnecta/data/recognize_api.dart';

/// Full-screen camera page.
///
/// Opens the device camera immediately. After taking a shot the user sees
/// a preview and can confirm (→ zip & send) or retake. The result returned
/// via [Navigator.pop] is the decoded server response [Map] or `null` if the
/// user cancelled.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final _picker = ImagePicker();
  final _api = RecognizeApi(AppServices.apiClient);

  File? _photo;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Open camera as soon as the page is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
  }

  Future<void> _takePhoto() async {
    setState(() {
      _photo = null;
      _error = null;
    });

    final XFile? xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85, // mild lossy compression before zipping
      preferredCameraDevice: CameraDevice.rear,
    );

    if (xfile == null) {
      // User pressed back without taking a photo – close the page.
      if (mounted) Navigator.of(context).pop(null);
      return;
    }

    setState(() => _photo = File(xfile.path));
  }

  Future<void> _send() async {
    if (_photo == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final result = await _api.recognizePhoto(_photo!);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.lightBackgroundColor,
      appBar: AppBar(
        backgroundColor: KColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(null),
          icon: SvgPicture.asset(
            "assets/svgs/arrow_back.svg",
            width: 25,
            height: 14,
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        title: Text(
          'Photo recognition',
          style: KTextStyles.fontMediumBigStyle.copyWith(
            color: Colors.white,
          ),
        ),
      ),
      body: _photo == null
          ? const Center(child: CircularProgressIndicator(color: KColors.thirdColorHover))
          : _buildPreview(),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        // ── Photo preview ──────────────────────────────────────────────
        Expanded(
          child: ClipRRect(
            child: Image.file(
              _photo!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
    
        const SizedBox(height: 16),
    
        // ── Error message ──────────────────────────────────────────────
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: KTextStyles.fontSmallStyle.copyWith(color: KColors.badColor),
            ),
          ),
    
        // ── Action buttons ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Retake
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : _takePhoto,
                  icon: const Icon(Icons.replay_rounded,
                      size: 18, color: KColors.mainColor),
                  label: Text(
                    'Retake',
                    style: KTextStyles.fontSmallStyle.copyWith(
                        color: KColors.mainColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: KColors.mainColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Send
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: KColors.thirdColorHover,
                          ),
                        )
                      : const Icon(Icons.send_rounded,color: Colors.white, size: 18),
                  label: Text(
                    _sending ? 'Sending…' : 'Recognize',
                    style: KTextStyles.fontSmallStyle.copyWith(
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KColors.mainColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    
        const SizedBox(height: 8),
      ],
    );
  }
}
