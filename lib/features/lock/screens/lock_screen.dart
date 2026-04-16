import 'package:closetmate/data/services/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.onUnlocked});

  final VoidCallback? onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _ctrl = TextEditingController();
  String _errorMessage = '';
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final bioEnabled = await AppLockService.isBiometricEnabled;
    final bioAvailable = await AppLockService.isBiometricAvailable;
    if (!mounted) return;
    setState(() {
      _isBiometricEnabled = bioEnabled;
      _isBiometricAvailable = bioAvailable;
    });
    if (bioEnabled && bioAvailable) {
      await _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final success = await AppLockService.authenticateWithBiometrics();
    if (success && mounted) {
      _onUnlocked();
    }
  }

  Future<void> _verifyPin() async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    final correct = await AppLockService.verifyPin(_ctrl.text);
    if (!mounted) return;

    if (correct) {
      _onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'PIN 码错误，请重试';
        _ctrl.clear();
        _isVerifying = false;
      });
    }
  }

  void _onUnlocked() {
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ClosetMate',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请验证身份以继续',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '● ● ● ● ● ●',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      letterSpacing: 8,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    errorText: _errorMessage.isEmpty ? null : _errorMessage,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verifyPin(),
                  onChanged: (value) {
                    if (_errorMessage.isNotEmpty) {
                      setState(() => _errorMessage = '');
                    }
                    if (value.length == 6) {
                      _verifyPin();
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isVerifying ? null : _verifyPin,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('解锁'),
                  ),
                ),
                if (_isBiometricEnabled && _isBiometricAvailable) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('使用生物识别'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
