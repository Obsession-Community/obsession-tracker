import 'package:flutter/material.dart';

/// Dialog for entering passwords for export/import operations
class PasswordDialog extends StatefulWidget {
  final String title;
  final String message;
  final bool confirmPassword;
  final String? hint;

  const PasswordDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmPassword = false,
    this.hint,
  });

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();

  /// Show dialog for exporting (with password confirmation)
  static Future<String?> showExportDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PasswordDialog(
        title: 'Protect Export',
        message: 'Choose a password to encrypt this session export.\n\n'
            'You will need this password to open the file later.',
        confirmPassword: true,
        hint: 'Choose a strong password',
      ),
    );
  }

  /// Show dialog for importing (password entry only)
  static Future<String?> showImportDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PasswordDialog(
        title: 'Enter Password',
        message: 'Enter the password to decrypt this session.',
        hint: 'Password',
      ),
    );
  }
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Listen to text changes to update UI in real-time
    _passwordController.addListener(_onTextChanged);
    _confirmController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // Clear error message when user types
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else {
      // Trigger rebuild to update strength indicator and match status
      setState(() {});
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onTextChanged);
    _confirmController.removeListener(_onTextChanged);
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final password = _passwordController.text;

    // Validate password strength
    if (password.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters long';
      });
      return;
    }

    // Confirm passwords match (if required)
    if (widget.confirmPassword) {
      final confirm = _confirmController.text;
      if (password != confirm) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }
    }

    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.confirmPassword ? Icons.lock_outline : Icons.lock_open,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(widget.title),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              widget.message,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.hint ?? 'Password',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 8) {
                  return 'At least 8 characters';
                }
                return null;
              },
              onFieldSubmitted: widget.confirmPassword
                  ? null
                  : (_) => _submit(), // Submit on Enter if no confirmation
            ),

            // Confirm password field (only for export)
            if (widget.confirmPassword) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter password',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm password';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(), // Submit on Enter
              ),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Password strength indicator (for export)
            if (widget.confirmPassword) ...[
              const SizedBox(height: 16),
              _PasswordStrengthIndicator(
                password: _passwordController.text,
              ),
              // Password match indicator
              if (_confirmController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PasswordMatchIndicator(
                  password: _passwordController.text,
                  confirmPassword: _confirmController.text,
                ),
              ],
            ],
          ],
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmPassword ? 'Encrypt' : 'Decrypt'),
        ),
      ],
    );
  }
}

/// Password strength indicator
class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  (String, Color, double) _calculateStrength() {
    if (password.isEmpty) {
      return ('', Colors.grey, 0.0);
    }

    int score = 0;

    // Length
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Character types
    if (RegExp('[a-z]').hasMatch(password)) score++;
    if (RegExp('[A-Z]').hasMatch(password)) score++;
    if (RegExp('[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) {
      return ('Weak', Colors.red, 0.33);
    } else if (score <= 4) {
      return ('Fair', Colors.orange, 0.66);
    } else if (score <= 6) {
      return ('Good', Colors.green, 0.85);
    } else {
      return ('Strong', Colors.green.shade700, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, progress) = _calculateStrength();

    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          color: color,
        ),
      ],
    );
  }
}

/// Password match indicator
class _PasswordMatchIndicator extends StatelessWidget {
  final String password;
  final String confirmPassword;

  const _PasswordMatchIndicator({
    required this.password,
    required this.confirmPassword,
  });

  @override
  Widget build(BuildContext context) {
    final matches = password == confirmPassword;
    final color = matches ? Colors.green : Colors.orange;
    final icon = matches ? Icons.check_circle : Icons.info_outline;
    final label = matches ? 'Passwords match' : 'Passwords do not match';

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
