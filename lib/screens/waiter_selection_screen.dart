import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../theme/app_colors.dart';

import 'manager_dashboard_screen.dart';
import 'table_selection_screen.dart';

class _PinInputDialog extends StatefulWidget {
  const _PinInputDialog({
    required this.title,
    required this.hint,
    required this.onSubmit,
  });

  final String title;
  final String hint;
  final ValueChanged<String> onSubmit;

  @override
  State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => _controller.text.length >= 4;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                counterText: '',
              ),
              autofocus: true,
              onSubmitted: (_) {
                if (_enabled) {
                  widget.onSubmit(_controller.text);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_enabled) widget.onSubmit(_controller.text);
                    },
                    child: const Text('Confirm'),
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

/// Waiter Selection Screen - displays list of waiters for NAME mode login.
/// Waiters click their name to access their tables.
class WaiterSelectionScreen extends StatefulWidget {
  const WaiterSelectionScreen({super.key});

  @override
  State<WaiterSelectionScreen> createState() => _WaiterSelectionScreenState();
}

class _WaiterSelectionScreenState extends State<WaiterSelectionScreen> {
  final ManagerData _m = ManagerData.instance;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _m.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  void _selectWaiter(String waiterName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TableSelectionScreen(waiterName: waiterName),
      ),
    );
  }

  void _backToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final waiters = _m.waiters;

    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: const Text('Select Waiter'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToLogin,
        ),
        actions: [
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return _PinInputDialog(
                    title: 'Admin PIN',
                    hint: 'Enter admin PIN',
                    onSubmit: (pin) async {
                      Navigator.of(context).pop();
                      if (pin == '9999') {
                        if (!mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ManagerDashboardScreen(),
                          ),
                        );
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Admin PIN i gabuar.')),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Welcome! Please select your name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: waiters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.person_outline,
                            size: 64,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No waiters found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: waiters.length,
                      itemBuilder: (context, index) {
                        final waiter = waiters[index];
                        return _buildWaiterButton(
                          name: waiter.name,
                          onTap: () => _selectWaiter(waiter.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterButton({
    required String name,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryGreen, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 38, color: AppColors.primaryGreen),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGreenText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
