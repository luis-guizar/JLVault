import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_generator_service.dart';
import 'password_strength_indicator.dart';

class PasswordGeneratorDialog extends StatefulWidget {
  final String? initialPassword;

  const PasswordGeneratorDialog({super.key, this.initialPassword});

  @override
  State<PasswordGeneratorDialog> createState() =>
      _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  late PasswordGenerationOptions _options;
  String _generatedPassword = '';
  bool _obscurePassword = false;

  @override
  void initState() {
    super.initState();
    _options = const PasswordGenerationOptions();
    _generatePassword();
  }

  void _generatePassword() {
    try {
      setState(() {
        _generatedPassword = PasswordGeneratorService.generatePassword(
          _options,
        );
      });
    } catch (e) {
      setState(() {
        _generatedPassword = '';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating password: $e')));
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Password Generator',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Generated Password Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _obscurePassword
                                      ? '●' * _generatedPassword.length
                                      : _generatedPassword,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: _copyToClipboard,
                                tooltip: 'Copy password',
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _generatePassword,
                                tooltip: 'Generate new password',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PasswordStrengthIndicator(
                            password: _generatedPassword,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Length Slider
                    Text(
                      'Length: ${_options.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _options.length.toDouble(),
                      min: 4,
                      max: 128,
                      divisions: 124,
                      label: _options.length.toString(),
                      onChanged: (value) {
                        setState(() {
                          _options = _options.copyWith(length: value.round());
                        });
                        _generatePassword();
                      },
                    ),

                    const SizedBox(height: 16),

                    // Character Type Options
                    const Text(
                      'Character Types',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    _buildCheckboxTile(
                      'Lowercase (a-z)',
                      _options.includeLowercase,
                      (value) => setState(() {
                        _options = _options.copyWith(includeLowercase: value);
                        _generatePassword();
                      }),
                    ),

                    _buildCheckboxTile(
                      'Uppercase (A-Z)',
                      _options.includeUppercase,
                      (value) => setState(() {
                        _options = _options.copyWith(includeUppercase: value);
                        _generatePassword();
                      }),
                    ),

                    _buildCheckboxTile(
                      'Numbers (0-9)',
                      _options.includeNumbers,
                      (value) => setState(() {
                        _options = _options.copyWith(includeNumbers: value);
                        _generatePassword();
                      }),
                    ),

                    _buildCheckboxTile(
                      'Symbols (!@#\$%^&*)',
                      _options.includeSymbols,
                      (value) => setState(() {
                        _options = _options.copyWith(includeSymbols: value);
                        _generatePassword();
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Additional Options
                    const Text(
                      'Additional Options',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    _buildCheckboxTile(
                      'Exclude ambiguous characters (il1Lo0O)',
                      _options.excludeAmbiguous,
                      (value) => setState(() {
                        _options = _options.copyWith(excludeAmbiguous: value);
                        _generatePassword();
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _generatedPassword.isNotEmpty
                        ? () => Navigator.of(context).pop(_generatedPassword)
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Use Password'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? false),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
