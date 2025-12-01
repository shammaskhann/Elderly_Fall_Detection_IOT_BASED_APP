import 'package:fall_detection_app/main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _useMLDetection = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _phoneController.text = prefs.getString('emergency_phone') ?? '';
    _useMLDetection = prefs.getBool('use_ml_detection') ?? true;
    setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_phone', _phoneController.text.trim());
    await prefs.setBool('use_ml_detection', _useMLDetection);

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: successColor, size: 20),
            const SizedBox(width: 8),
            const Text('Settings saved successfully'),
          ],
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: successColor.withOpacity(0.2), width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );

    // Close after a brief delay
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.pop(context);
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundColor, Color(0xFFEDF2F7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: backgroundColor,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Configure your fall detection preferences',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emergency Contact Section
                      _buildSectionHeader(
                        'Emergency Contact',
                        Icons.emergency_outlined,
                      ),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Primary Emergency Contact',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter the phone number that will be contacted in case of a detected fall.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.phone_outlined),
                                labelText: 'Phone Number',
                                hintText: '+1 (123) 456-7890',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: backgroundColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Include country code for international numbers',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Detection Settings Section
                      // _buildSectionHeader(
                      //   'Detection Settings',
                      //   Icons.security_outlined,
                      // ),

                      // Container(
                      //   padding: const EdgeInsets.all(20),
                      //   decoration: BoxDecoration(
                      //     color: surfaceColor,
                      //     borderRadius: BorderRadius.circular(16),
                      //     boxShadow: [
                      //       BoxShadow(
                      //         color: Colors.black.withOpacity(0.05),
                      //         blurRadius: 20,
                      //         offset: const Offset(0, 10),
                      //       ),
                      //     ],
                      //   ),
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       // Detection Method Toggle
                      //       Container(
                      //         padding: const EdgeInsets.all(16),
                      //         decoration: BoxDecoration(
                      //           color: backgroundColor,
                      //           borderRadius: BorderRadius.circular(12),
                      //           border: Border.all(
                      //             color: _useMLDetection
                      //                 ? primaryColor.withOpacity(0.2)
                      //                 : Colors.grey.shade200,
                      //           ),
                      //         ),
                      //         child: Row(
                      //           children: [
                      //             Container(
                      //               padding: const EdgeInsets.all(10),
                      //               decoration: BoxDecoration(
                      //                 color: _useMLDetection
                      //                     ? primaryColor.withOpacity(0.1)
                      //                     : Colors.grey.shade100,
                      //                 borderRadius: BorderRadius.circular(10),
                      //               ),
                      //               child: Icon(
                      //                 _useMLDetection
                      //                     ? Icons.psychology_outlined
                      //                     : Icons.speed_outlined,
                      //                 color: _useMLDetection
                      //                     ? primaryColor
                      //                     : textSecondary,
                      //                 size: 24,
                      //               ),
                      //             ),
                      //             const SizedBox(width: 16),
                      //             Expanded(
                      //               child: Column(
                      //                 crossAxisAlignment:
                      //                     CrossAxisAlignment.start,
                      //                 children: [
                      //                   Text(
                      //                     'ML-Enhanced Detection',
                      //                     style: Theme.of(context)
                      //                         .textTheme
                      //                         .bodyLarge
                      //                         ?.copyWith(
                      //                           fontWeight: FontWeight.w600,
                      //                         ),
                      //                   ),
                      //                   const SizedBox(height: 4),
                      //                   Text(
                      //                     'Advanced AI-powered detection',
                      //                     style: Theme.of(context)
                      //                         .textTheme
                      //                         .bodyMedium
                      //                         ?.copyWith(color: textSecondary),
                      //                   ),
                      //                 ],
                      //               ),
                      //             ),
                      //             Transform.scale(
                      //               scale: 1.2,
                      //               child: Switch.adaptive(
                      //                 value: _useMLDetection,
                      //                 onChanged: (value) {
                      //                   setState(() {
                      //                     _useMLDetection = value;
                      //                   });
                      //                 },
                      //                 activeColor: primaryColor,
                      //                 activeTrackColor: primaryColor
                      //                     .withOpacity(0.3),
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),

                      //       const SizedBox(height: 16),

                      //       // Method Details Card
                      //       Container(
                      //         padding: const EdgeInsets.all(16),
                      //         decoration: BoxDecoration(
                      //           color: _useMLDetection
                      //               ? primaryColor.withOpacity(0.08)
                      //               : warningColor.withOpacity(0.08),
                      //           borderRadius: BorderRadius.circular(12),
                      //           border: Border.all(
                      //             color: _useMLDetection
                      //                 ? primaryColor.withOpacity(0.2)
                      //                 : warningColor.withOpacity(0.2),
                      //           ),
                      //         ),
                      //         child: Row(
                      //           crossAxisAlignment: CrossAxisAlignment.start,
                      //           children: [
                      //             Icon(
                      //               _useMLDetection
                      //                   ? Icons.check_circle_outline
                      //                   : Icons.warning_amber_outlined,
                      //               color: _useMLDetection
                      //                   ? primaryColor
                      //                   : warningColor,
                      //               size: 20,
                      //             ),
                      //             const SizedBox(width: 12),
                      //             Expanded(
                      //               child: Column(
                      //                 crossAxisAlignment:
                      //                     CrossAxisAlignment.start,
                      //                 children: [
                      //                   Text(
                      //                     _useMLDetection
                      //                         ? 'Recommended Method'
                      //                         : 'Basic Detection',
                      //                     style: Theme.of(context)
                      //                         .textTheme
                      //                         .bodyMedium
                      //                         ?.copyWith(
                      //                           fontWeight: FontWeight.w600,
                      //                           color: _useMLDetection
                      //                               ? primaryColor
                      //                               : warningColor,
                      //                         ),
                      //                   ),
                      //                   const SizedBox(height: 4),
                      //                   Text(
                      //                     _useMLDetection
                      //                         ? 'Uses advanced ML model with 55+ features for accurate fall detection with minimal false positives.'
                      //                         : 'Uses simple heuristic methods that may generate false alarms during vigorous activities.',
                      //                     style: Theme.of(context)
                      //                         .textTheme
                      //                         .bodySmall
                      //                         ?.copyWith(color: textPrimary),
                      //                   ),
                      //                 ],
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),

                      //       const SizedBox(height: 12),

                      //       // Feature Comparison
                      //       Row(
                      //         children: [
                      //           Expanded(
                      //             child: Column(
                      //               crossAxisAlignment:
                      //                   CrossAxisAlignment.start,
                      //               children: [
                      //                 Row(
                      //                   children: [
                      //                     Icon(
                      //                       _useMLDetection
                      //                           ? Icons.check
                      //                           : Icons.close,
                      //                       color: _useMLDetection
                      //                           ? successColor
                      //                           : textSecondary,
                      //                       size: 16,
                      //                     ),
                      //                     const SizedBox(width: 4),
                      //                     Text(
                      //                       'High Accuracy',
                      //                       style: Theme.of(context)
                      //                           .textTheme
                      //                           .bodySmall
                      //                           ?.copyWith(
                      //                             color: textPrimary,
                      //                             fontWeight: _useMLDetection
                      //                                 ? FontWeight.w600
                      //                                 : FontWeight.normal,
                      //                           ),
                      //                     ),
                      //                   ],
                      //                 ),
                      //                 const SizedBox(height: 8),
                      //                 Row(
                      //                   children: [
                      //                     Icon(
                      //                       _useMLDetection
                      //                           ? Icons.check
                      //                           : Icons.close,
                      //                       color: _useMLDetection
                      //                           ? successColor
                      //                           : textSecondary,
                      //                       size: 16,
                      //                     ),
                      //                     const SizedBox(width: 4),
                      //                     Text(
                      //                       'Zero False Positives',
                      //                       style: Theme.of(context)
                      //                           .textTheme
                      //                           .bodySmall
                      //                           ?.copyWith(
                      //                             color: textPrimary,
                      //                             fontWeight: _useMLDetection
                      //                                 ? FontWeight.w600
                      //                                 : FontWeight.normal,
                      //                           ),
                      //                     ),
                      //                   ],
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //           Expanded(
                      //             child: Column(
                      //               crossAxisAlignment:
                      //                   CrossAxisAlignment.start,
                      //               children: [
                      //                 Row(
                      //                   children: [
                      //                     Icon(
                      //                       _useMLDetection
                      //                           ? Icons.check
                      //                           : Icons.close,
                      //                       color: _useMLDetection
                      //                           ? successColor
                      //                           : textSecondary,
                      //                       size: 16,
                      //                     ),
                      //                     const SizedBox(width: 4),
                      //                     Text(
                      //                       'Activity Recognition',
                      //                       style: Theme.of(context)
                      //                           .textTheme
                      //                           .bodySmall
                      //                           ?.copyWith(
                      //                             color: textPrimary,
                      //                             fontWeight: _useMLDetection
                      //                                 ? FontWeight.w600
                      //                                 : FontWeight.normal,
                      //                           ),
                      //                     ),
                      //                   ],
                      //                 ),
                      //                 const SizedBox(height: 8),
                      //                 Row(
                      //                   children: [
                      //                     Icon(
                      //                       _useMLDetection
                      //                           ? Icons.flash_on
                      //                           : Icons.flash_off,
                      //                       color: _useMLDetection
                      //                           ? primaryColor
                      //                           : textSecondary,
                      //                       size: 16,
                      //                     ),
                      //                     const SizedBox(width: 4),
                      //                     Text(
                      //                       _useMLDetection
                      //                           ? 'Advanced Algorithm'
                      //                           : 'Basic Algorithm',
                      //                       style: Theme.of(context)
                      //                           .textTheme
                      //                           .bodySmall
                      //                           ?.copyWith(
                      //                             color: textPrimary,
                      //                             fontWeight: FontWeight.w600,
                      //                           ),
                      //                     ),
                      //                   ],
                      //                 ),
                      //               ],
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.save_outlined,
                                size: 22,
                                color: backgroundColor,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Save Settings',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: backgroundColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // // Reset Button
                      // SizedBox(
                      //   width: double.infinity,
                      //   height: 56,
                      //   child: OutlinedButton(
                      //     onPressed: () {
                      //       // Reset to defaults
                      //       _phoneController.clear();
                      //       _useMLDetection = true;
                      //       setState(() {});
                      //     },
                      //     style: OutlinedButton.styleFrom(
                      //       foregroundColor: textSecondary,
                      //       side: BorderSide(color: Colors.grey.shade500),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(16),
                      //       ),
                      //     ),
                      //     child: const Text('Reset to Defaults'),
                      //   ),
                      // ),
                    ],
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
