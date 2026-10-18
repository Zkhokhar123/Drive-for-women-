import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../services/firebase_service.dart';
import '../../services/user_session.dart';
import '../driver/driver_home.dart';

// ─────────────────────────────────────────────────────────────
//  DriverRegisterScreen  (4 steps)
//
//  Step 1 — Personal info & vehicle details
//  Step 2 — CNIC (number + front photo)
//  Step 3 — Driving licence (number + front photo)
//  Step 4 — Bike/vehicle photo + number plate (text + photo)
// ─────────────────────────────────────────────────────────────
class DriverRegisterScreen extends StatefulWidget {
  final String phone;
  final String firebaseUid;
  final String prefillName;

  const DriverRegisterScreen({
    super.key,
    required this.phone,
    required this.firebaseUid,
    this.prefillName = '',
  });

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _pageCtrl = PageController();
  int _step = 0; // 0 | 1 | 2 | 3

  // ── Step 1 controllers ─────────────────────────────────────
  late TextEditingController _nameCtrl;
  final _vModelCtrl = TextEditingController();
  final _vRegCtrl   = TextEditingController();
  final _vColorCtrl = TextEditingController();
  final _vYearCtrl  = TextEditingController();

  // ── Step 2 controllers ─────────────────────────────────────
  final _cnicNumberCtrl = TextEditingController();

  // ── Step 3 controllers ─────────────────────────────────────
  final _licenceNumberCtrl = TextEditingController();

  // ── Step 4 controllers ─────────────────────────────────────
  final _numberPlateCtrl = TextEditingController();

  // ── Picked files ───────────────────────────────────────────
  File? _cnicFile;
  File? _licenceFile;
  File? _bikeFile;
  File? _numberPlateFile;

  // ── Upload / submit state ──────────────────────────────────
  double _uploadProgress = 0.0;
  bool _isSubmitting = false;
  String _submitStatus = '';

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefillName);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _vModelCtrl.dispose();
    _vRegCtrl.dispose();
    _vColorCtrl.dispose();
    _vYearCtrl.dispose();
    _cnicNumberCtrl.dispose();
    _licenceNumberCtrl.dispose();
    _numberPlateCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────

  void _nextStep() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step == 1 && !_validateStep2()) return;
    if (_step == 2 && !_validateStep3()) return;

    if (_step < 3) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  bool _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Please enter your full name', isError: true);
      return false;
    }
    if (_vModelCtrl.text.trim().isEmpty) {
      _snack('Please enter your vehicle model', isError: true);
      return false;
    }
    if (_vRegCtrl.text.trim().isEmpty) {
      _snack('Please enter your registration number', isError: true);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    final cnic = _cnicNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cnic.length != 13) {
      _snack('CNIC must be 13 digits (e.g. 42201-1234567-1)', isError: true);
      return false;
    }
    if (_cnicFile == null) {
      _snack('Please upload your CNIC photo', isError: true);
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_licenceNumberCtrl.text.trim().isEmpty) {
      _snack('Please enter your driving licence number', isError: true);
      return false;
    }
    if (_licenceFile == null) {
      _snack('Please upload your driving licence photo', isError: true);
      return false;
    }
    return true;
  }

  // ── Image picker ───────────────────────────────────────────

  Future<void> _pickImage(String docType) async {
    final source = await _showSourceDialog();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      if (docType == 'cnic')        _cnicFile        = file;
      if (docType == 'licence')     _licenceFile     = file;
      if (docType == 'bike')        _bikeFile        = file;
      if (docType == 'numberPlate') _numberPlateFile = file;
    });
    _snack('${_docLabel(docType)} photo selected ✓');
  }

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.camera_alt_rounded, color: Colors.white),
              ),
              title: const Text('Take a Photo',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.accent,
                child: Icon(Icons.photo_library_rounded, color: Colors.white),
              ),
              title: const Text('Choose from Gallery',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _docLabel(String docType) {
    switch (docType) {
      case 'cnic':        return 'CNIC';
      case 'licence':     return 'Licence';
      case 'bike':        return 'Vehicle';
      case 'numberPlate': return 'Number Plate';
      default:            return docType;
    }
  }

  // ── Submit ──────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_bikeFile == null) {
      _snack('Please upload your vehicle photo', isError: true);
      return;
    }
    if (_numberPlateCtrl.text.trim().isEmpty) {
      _snack('Please enter your number plate', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
      _submitStatus = 'Uploading CNIC…';
    });

    try {
      final uid = widget.firebaseUid.isNotEmpty
          ? widget.firebaseUid
          : FirebaseService.instance.currentUid ?? '';
      if (uid.isEmpty) throw Exception('No Firebase UID — please log in again');

      _setStatus('Uploading CNIC photo…', 0.08);
      final cnicUrl = await FirebaseService.instance.uploadDocument(
          uid: uid, localPath: _cnicFile!.path, docType: 'cnic');

      _setStatus('Uploading Driving Licence…', 0.30);
      final licenceUrl = await FirebaseService.instance.uploadDocument(
          uid: uid, localPath: _licenceFile!.path, docType: 'licence');

      _setStatus('Uploading Vehicle Photo…', 0.55);
      final bikeUrl = await FirebaseService.instance.uploadDocument(
          uid: uid, localPath: _bikeFile!.path, docType: 'bike');

      String numberPlateUrl = '';
      if (_numberPlateFile != null) {
        _setStatus('Uploading Number Plate Photo…', 0.75);
        numberPlateUrl = await FirebaseService.instance.uploadDocument(
            uid: uid,
            localPath: _numberPlateFile!.path,
            docType: 'numberPlate');
      }

      _setStatus('Saving profile…', 0.90);
      await FirebaseService.instance.saveDriver(
        uid:           uid,
        name:          _nameCtrl.text.trim(),
        phone:         widget.phone,
        vehicleModel:  _vModelCtrl.text.trim(),
        vehicleReg:    _vRegCtrl.text.trim(),
        vehicleColor:
            _vColorCtrl.text.trim().isEmpty ? 'N/A' : _vColorCtrl.text.trim(),
        vehicleYear:
            _vYearCtrl.text.trim().isEmpty ? '2024' : _vYearCtrl.text.trim(),
        cnicNumber:    _cnicNumberCtrl.text.trim(),
        cnicUrl:       cnicUrl,
        licenceNumber: _licenceNumberCtrl.text.trim(),
        licenceUrl:    licenceUrl,
        bikeUrl:       bikeUrl,
        numberPlate:   _numberPlateCtrl.text.trim().toUpperCase(),
        numberPlateUrl: numberPlateUrl,
      );

      _setStatus('Done! 🎉', 1.0);
      UserSession.instance.setDriver(
        name:        _nameCtrl.text.trim(),
        phone:       widget.phone,
        vModel:      _vModelCtrl.text.trim(),
        vReg:        _vRegCtrl.text.trim(),
        vColor: _vColorCtrl.text.trim().isEmpty ? 'N/A' : _vColorCtrl.text.trim(),
        vYear:  _vYearCtrl.text.trim().isEmpty ? '2024' : _vYearCtrl.text.trim(),
        cnicPath:    cnicUrl,
        licencePath: licenceUrl,
        bikePath:    bikeUrl,
        firebaseUid: uid,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DriverHome()));
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _submitStatus = '';
      });
      _snack('Upload failed: $e', isError: true);
    }
  }

  void _setStatus(String msg, double progress) {
    if (mounted) setState(() { _submitStatus = msg; _uploadProgress = progress; });
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.textPrimary),
                onPressed: _isSubmitting ? null : _prevStep)
            : const BackButton(color: AppTheme.textPrimary),
        title: Text(_stepTitle,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Step progress bar ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Row(
              children: List.generate(4, (i) {
                final done = i <= _step;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: done ? AppGradients.tripleGradient : null,
                      color: done ? null : AppTheme.bgCard2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Step ${_step + 1} of 4',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 12)),
                Text(_stepSubtitle,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Pages ───────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),

          // ── Bottom CTA ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: _isSubmitting
                ? _buildUploadProgress()
                : GradientButton(
                    label: _step == 3
                        ? 'Submit & Start Driving 🚀'
                        : 'Continue  →',
                    onPressed: _nextStep,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Progress indicator ──────────────────────────────────────

  Widget _buildUploadProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_submitStatus,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
            Text('${(_uploadProgress * 100).round()}%',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            minHeight: 6,
            color: AppTheme.primary,
            backgroundColor: AppTheme.bgCard2,
          ),
        ),
      ],
    );
  }

  // ── Step titles ─────────────────────────────────────────────

  String get _stepTitle {
    switch (_step) {
      case 0:  return 'Personal & Vehicle Info';
      case 1:  return 'CNIC Verification';
      case 2:  return 'Driving Licence';
      default: return 'Vehicle & Number Plate';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 0:  return 'Basic details';
      case 1:  return 'Identity document';
      case 2:  return 'Driving credentials';
      default: return 'Vehicle documents';
    }
  }

  // ── Step 1: Personal + vehicle info ────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('👤 Personal Information'),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person_rounded, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('🏍️ Vehicle Information'),
          const SizedBox(height: 10),
          TextField(
            controller: _vModelCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Vehicle Model * (e.g. Honda CD 70)',
              prefixIcon:
                  Icon(Icons.motorcycle_rounded, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vRegCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Registration Number * (e.g. KAR-1234)',
              prefixIcon: Icon(Icons.confirmation_number_rounded,
                  color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _vColorCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Colour',
                  prefixIcon:
                      Icon(Icons.palette_rounded, color: AppTheme.textHint),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _vYearCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Year',
                  prefixIcon: Icon(Icons.calendar_today_rounded,
                      color: AppTheme.textHint),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          const _InfoBanner(
            text:
                'All vehicle details must match your registration certificate (RC book).',
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ── Step 2: CNIC ─────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('🪪 CNIC Number'),
          const SizedBox(height: 8),
          TextField(
            controller: _cnicNumberCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                letterSpacing: 1.5,
                fontSize: 15),
            decoration: const InputDecoration(
              labelText: 'CNIC Number * (13 digits)',
              hintText: '42201-1234567-1',
              prefixIcon: Icon(Icons.credit_card_rounded, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Format: 42201-1234567-1  (no dashes needed)',
            style: TextStyle(color: AppTheme.textHint, fontSize: 11),
          ),
          const SizedBox(height: 24),
          _sectionLabel('📸 CNIC Photo (Front Side)'),
          const SizedBox(height: 8),
          const Text(
            'Upload a clear, well-lit photo of your CNIC front. '
            'Make sure all text is readable.',
            style: TextStyle(color: AppTheme.textHint, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          _DocUploadCard(
            label: 'CNIC Front Side',
            icon: Icons.credit_card_rounded,
            file: _cnicFile,
            onTap: () => _pickImage('cnic'),
          ),
          const SizedBox(height: 16),
          const _InfoBanner(
            text:
                'Your CNIC photo is encrypted and used only for identity verification.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ── Step 3: Driving licence ──────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('🪪 Driving Licence Number'),
          const SizedBox(height: 8),
          TextField(
            controller: _licenceNumberCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                color: AppTheme.textPrimary, letterSpacing: 1.2),
            decoration: const InputDecoration(
              labelText: 'Licence Number *',
              hintText: 'e.g. LHR-12345678',
              prefixIcon: Icon(Icons.badge_rounded, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('📸 Driving Licence Photo (Front)'),
          const SizedBox(height: 8),
          _DocUploadCard(
            label: 'Driving Licence Front',
            icon: Icons.badge_rounded,
            file: _licenceFile,
            onTap: () => _pickImage('licence'),
          ),
          const SizedBox(height: 16),
          const _InfoBanner(
            text:
                'Licence must be valid and unexpired. Renewal licences are also accepted.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ── Step 4: Bike photo + number plate ────────────────────────

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('🏍️ Vehicle Photo'),
          const SizedBox(height: 8),
          _DocUploadCard(
            label: 'Clear photo of your vehicle',
            icon: Icons.motorcycle_rounded,
            file: _bikeFile,
            onTap: () => _pickImage('bike'),
          ),
          const SizedBox(height: 24),
          _sectionLabel('🔢 Number Plate'),
          const SizedBox(height: 8),
          TextField(
            controller: _numberPlateCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                fontSize: 15),
            decoration: const InputDecoration(
              labelText: 'Number Plate *',
              hintText: 'e.g. KAR-1234 or LEA-00234',
              prefixIcon: Icon(Icons.pin_rounded, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('📸 Number Plate Photo  (optional)'),
          const SizedBox(height: 8),
          _DocUploadCard(
            label: 'Number plate photo',
            icon: Icons.pin_rounded,
            file: _numberPlateFile,
            onTap: () => _pickImage('numberPlate'),
            isOptional: true,
          ),
          const SizedBox(height: 16),
          const _InfoBanner(
            text:
                'After submission, documents are reviewed within 24 hours. '
                'You can start accepting rides once approved.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15),
      );
}

// ── Reusable doc-upload card ─────────────────────────────────

class _DocUploadCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? file;
  final VoidCallback onTap;
  final bool isOptional;

  const _DocUploadCard({
    required this.label,
    required this.icon,
    required this.file,
    required this.onTap,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    final picked = file != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        decoration: BoxDecoration(
          color: picked
              ? AppTheme.success.withValues(alpha: 0.08)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: picked
                ? AppTheme.success.withValues(alpha: 0.5)
                : (isOptional
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.primary.withValues(alpha: 0.25)),
            width: picked ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            if (picked)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: Image.file(file!,
                    height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: picked
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      picked ? Icons.check_circle_rounded : icon,
                      color: picked ? AppTheme.success : AppTheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                  color: picked
                                      ? AppTheme.success
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                            if (isOptional) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.textHint
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('optional',
                                    style: TextStyle(
                                        color: AppTheme.textHint,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          picked
                              ? 'Photo selected — tap to change'
                              : 'Tap to take photo or choose from gallery',
                          style: TextStyle(
                              color: picked
                                  ? AppTheme.success.withValues(alpha: 0.8)
                                  : AppTheme.textHint,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    picked ? Icons.edit_rounded : Icons.camera_alt_rounded,
                    color: picked ? AppTheme.success : AppTheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info banner ──────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, color: AppTheme.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}
