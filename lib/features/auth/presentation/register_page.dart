import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../application/auth_controllers.dart';

class RegisterPage extends HookConsumerWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final firstNameController = useTextEditingController();
    final lastNameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final phoneController = useTextEditingController();
    final locationController = useTextEditingController();
    final communityController = useTextEditingController();
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          if (context.mounted) {
            context.go('/calendar');
          }
        },
      );
    });

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vytvoření účtu',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 520;
                          final fieldWidth = isNarrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 16) / 2;

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  controller: firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Jméno',
                                    helperText: 'Bez čísel, minimálně 2 znaky',
                                    errorMaxLines: 2,
                                  ),
                                  validator: AppValidators.validateFirstName,
                                  autofillHints: const [
                                    AutofillHints.givenName,
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  controller: lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Příjmení',
                                    helperText: ' ',
                                    errorMaxLines: 2,
                                  ),
                                  validator: AppValidators.validateLastName,
                                  autofillHints: const [
                                    AutofillHints.familyName,
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          errorMaxLines: 2,
                        ),
                        validator: AppValidators.validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefonní číslo',
                          errorMaxLines: 2,
                        ),
                        validator: AppValidators.validatePhone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Místo bydliště',
                          errorMaxLines: 2,
                        ),
                        validator: AppValidators.validateRequired,
                        autofillHints: const [AutofillHints.streetAddressLine1],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: communityController,
                        decoration: const InputDecoration(
                          labelText:
                              'Církev / farnost / křesťanské společenství',
                          errorMaxLines: 2,
                        ),
                        validator: AppValidators.validateRequired,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 520;
                          final fieldWidth = isNarrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 16) / 2;

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  controller: passwordController,
                                  decoration: const InputDecoration(
                                    labelText: 'Heslo',
                                    errorMaxLines: 2,
                                  ),
                                  obscureText: true,
                                  validator: AppValidators.validatePassword,
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: TextFormField(
                                  controller: confirmPasswordController,
                                  decoration: const InputDecoration(
                                    labelText: 'Potvrďte heslo',
                                    errorMaxLines: 2,
                                  ),
                                  obscureText: true,
                                  validator: (value) {
                                    if (value != passwordController.text) {
                                      return 'Hesla se musí shodovat';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: authState.isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .register(
                                      email: emailController.text.trim(),
                                      password: passwordController.text.trim(),
                                      firstName:
                                          firstNameController.text.trim(),
                                      lastName: lastNameController.text.trim(),
                                      phoneNumber: phoneController.text.trim(),
                                      location: locationController.text.trim(),
                                      community:
                                          communityController.text.trim(),
                                    );
                              },
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Zaregistrovat se'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Po registraci vám přijde ověřovací e-mail. Potvrďte ho prosím před prvním přihlášením, pokud jej neposkytuje vybraný poskytovatel.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: const Text('Máte účet? Přihlaste se'),
                      ),
                      if (authState.hasError) ...[
                        const SizedBox(height: 12),
                        Text(
                          authState.error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
