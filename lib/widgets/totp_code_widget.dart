import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/totp_config.dart';
import '../services/totp_generator.dart';

/// Widget that displays a TOTP code with countdown timer
class TOTPCodeWidget extends StatefulWidget {
  final TOTPConfig config;
  final bool showCopyButton;
  final VoidCallback? onCopy;

  const TOTPCodeWidget({
    super.key,
    required this.config,
    this.showCopyButton = true,
    this.onCopy,
  });

  @override
  State<TOTPCodeWidget> createState() => _TOTPCodeWidgetState();
}

class _TOTPCodeWidgetState extends State<TOTPCodeWidget>
    with TickerProviderStateMixin {
  late StreamSubscription<String> _codeSubscription;
  late StreamSubscription<int> _remainingSubscription;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  String _currentCode = '';
  int _remainingSeconds = 0;
  bool _isExpiringSoon = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: Duration(seconds: widget.config.period),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    _initializeStreams();
    _updateProgress();
  }

  void _initializeStreams() {
    // Initialize with current values
    _currentCode = TOTPGenerator.generateCode(widget.config);
    _remainingSeconds = TOTPGenerator.getRemainingSeconds(widget.config);
    _isExpiringSoon = _remainingSeconds <= 10;

    // Listen to code changes
    _codeSubscription = TOTPGenerator.getCodeStream(widget.config).listen((
      code,
    ) {
      if (mounted) {
        setState(() {
          _currentCode = code;
        });
        _updateProgress();
      }
    });

    // Listen to remaining seconds changes
    _remainingSubscription =
        TOTPGenerator.getRemainingSecondsStream(widget.config).listen((
          remaining,
        ) {
          if (mounted) {
            setState(() {
              _remainingSeconds = remaining;
              _isExpiringSoon = remaining <= 10;
            });
          }
        });
  }

  void _updateProgress() {
    final progress = TOTPGenerator.getProgress(widget.config);
    _progressController.reset();
    _progressController.animateTo(progress);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildCodeDisplay(),
            const SizedBox(height: 12),
            _buildProgressIndicator(),
            const SizedBox(height: 8),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.security, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.config.issuer,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (widget.config.accountName.isNotEmpty)
                Text(
                  widget.config.accountName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
        ),
        if (widget.showCopyButton)
          IconButton(
            onPressed: _copyCode,
            icon: const Icon(Icons.copy),
            tooltip: 'Copy code',
          ),
      ],
    );
  }

  Widget _buildCodeDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _isExpiringSoon ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isExpiringSoon ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatCode(_currentCode),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: _isExpiringSoon ? Colors.red.shade700 : Colors.black87,
              letterSpacing: 4,
            ),
          ),
          if (_isExpiringSoon) ...[
            const SizedBox(width: 8),
            Icon(Icons.warning, color: Colors.red.shade700, size: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expires in $_remainingSeconds seconds',
              style: TextStyle(
                fontSize: 12,
                color: _isExpiringSoon ? Colors.red.shade700 : Colors.grey[600],
                fontWeight: _isExpiringSoon
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            Text(
              '${widget.config.period}s period',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _progressAnimation.value,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isExpiringSoon ? Colors.red : Theme.of(context).primaryColor,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${widget.config.digits} digits • ${widget.config.algorithm.name}',
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
        if (_isExpiringSoon)
          Text(
            'EXPIRING SOON',
            style: TextStyle(
              fontSize: 10,
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  String _formatCode(String code) {
    // Add spaces every 3 digits for better readability
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    } else if (code.length == 8) {
      return '${code.substring(0, 4)} ${code.substring(4)}';
    }
    return code;
  }

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _currentCode));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('TOTP code copied to clipboard'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );

      widget.onCopy?.call();
    }
  }

  @override
  void dispose() {
    _codeSubscription.cancel();
    _remainingSubscription.cancel();
    _progressController.dispose();
    super.dispose();
  }
}

/// Compact version of TOTP code widget for list items
class CompactTOTPCodeWidget extends StatefulWidget {
  final TOTPConfig config;
  final VoidCallback? onTap;

  const CompactTOTPCodeWidget({super.key, required this.config, this.onTap});

  @override
  State<CompactTOTPCodeWidget> createState() => _CompactTOTPCodeWidgetState();
}

class _CompactTOTPCodeWidgetState extends State<CompactTOTPCodeWidget> {
  late StreamSubscription<String> _codeSubscription;
  late StreamSubscription<int> _remainingSubscription;

  String _currentCode = '';
  int _remainingSeconds = 0;
  bool _isExpiringSoon = false;

  @override
  void initState() {
    super.initState();

    // Initialize with current values
    _currentCode = TOTPGenerator.generateCode(widget.config);
    _remainingSeconds = TOTPGenerator.getRemainingSeconds(widget.config);
    _isExpiringSoon = _remainingSeconds <= 10;

    // Listen to changes
    _codeSubscription = TOTPGenerator.getCodeStream(widget.config).listen((
      code,
    ) {
      if (mounted) {
        setState(() {
          _currentCode = code;
        });
      }
    });

    _remainingSubscription =
        TOTPGenerator.getRemainingSecondsStream(widget.config).listen((
          remaining,
        ) {
          if (mounted) {
            setState(() {
              _remainingSeconds = remaining;
              _isExpiringSoon = remaining <= 10;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _isExpiringSoon ? Colors.red.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isExpiringSoon ? Colors.red.shade200 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.security,
              size: 16,
              color: _isExpiringSoon
                  ? Colors.red.shade700
                  : Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              _formatCode(_currentCode),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: _isExpiringSoon ? Colors.red.shade700 : Colors.black87,
              ),
            ),
            const Spacer(),
            Text(
              '${_remainingSeconds}s',
              style: TextStyle(
                fontSize: 12,
                color: _isExpiringSoon ? Colors.red.shade700 : Colors.grey[600],
                fontWeight: _isExpiringSoon
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (_isExpiringSoon) ...[
              const SizedBox(width: 4),
              Icon(Icons.warning, size: 12, color: Colors.red.shade700),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCode(String code) {
    // Add spaces every 3 digits for better readability
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    } else if (code.length == 8) {
      return '${code.substring(0, 4)} ${code.substring(4)}';
    }
    return code;
  }

  @override
  void dispose() {
    _codeSubscription.cancel();
    _remainingSubscription.cancel();
    super.dispose();
  }
}

/// Widget for displaying multiple TOTP codes in a list
class TOTPCodeListWidget extends StatelessWidget {
  final List<TOTPConfig> configs;
  final Function(TOTPConfig)? onConfigTap;
  final Function(TOTPConfig)? onConfigCopy;

  const TOTPCodeListWidget({
    super.key,
    required this.configs,
    this.onConfigTap,
    this.onConfigCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (configs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No TOTP codes configured',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Add TOTP authentication to your accounts for extra security',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: configs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final config = configs[index];
        return TOTPCodeWidget(
          config: config,
          onCopy: () => onConfigCopy?.call(config),
        );
      },
    );
  }
}
