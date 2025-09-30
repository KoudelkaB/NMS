import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/application/auth_providers.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/data/time_slot.dart';

class ProfilePage extends HookConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final assignments = ref.watch(userAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Můj profil'),
      ),
      body: AsyncValueWidget(
        value: appUserAsync,
        builder: (user) {
          if (user == null) {
            return const Center(
              child: Text('Nebyla nalezena uživatelská data.'),
            );
          }

          return HookBuilder(
            builder: (hookContext) {
              final firstNameController =
                  useTextEditingController(text: user.firstName);
              final lastNameController =
                  useTextEditingController(text: user.lastName);
              final phoneController =
                  useTextEditingController(text: user.phoneNumber);
              final locationController =
                  useTextEditingController(text: user.location);
              final communityController =
                  useTextEditingController(text: user.community);
              final formKey = useMemoized(() => GlobalKey<FormState>());
              final authRepository = ref.read(authRepositoryProvider);
              final isSaving = useState(false);
              final email = user.email;

              return Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Osobní údaje',
                                  style: Theme.of(hookContext).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: firstNameController,
                                        decoration:
                                            const InputDecoration(labelText: 'Jméno'),
                                        validator: AppValidators.validateFirstName,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: lastNameController,
                                        decoration:
                                            const InputDecoration(labelText: 'Příjmení'),
                                        validator: AppValidators.validateLastName,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: email,
                                  decoration: const InputDecoration(labelText: 'E-mail'),
                                  readOnly: true,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: phoneController,
                                  decoration:
                                      const InputDecoration(labelText: 'Telefonní číslo'),
                                  validator: AppValidators.validatePhone,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: locationController,
                                  decoration:
                                      const InputDecoration(labelText: 'Místo bydliště'),
                                  validator: AppValidators.validateRequired,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: communityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Církev / farnost / křesťanské společenství',
                                  ),
                                  validator: AppValidators.validateRequired,
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: isSaving.value
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!.validate()) {
                                            return;
                                          }
                                          isSaving.value = true;
                                          try {
                                            await authRepository.updateProfile(
                                              user.copyWith(
                                                firstName:
                                                    firstNameController.text.trim(),
                                                lastName: lastNameController.text.trim(),
                                                phoneNumber:
                                                    phoneController.text.trim(),
                                                location:
                                                    locationController.text.trim(),
                                                community:
                                                    communityController.text.trim(),
                                                updatedAt: DateTime.now(),
                                              ),
                                            );
                                            if (!hookContext.mounted) return;
                                            ScaffoldMessenger.of(hookContext).showSnackBar(
                                              const SnackBar(
                                                content: Text('Profil byl uložen.'),
                                              ),
                                            );
                                          } catch (error) {
                                            if (!hookContext.mounted) return;
                                            ScaffoldMessenger.of(hookContext).showSnackBar(
                                              SnackBar(
                                                content:
                                                    Text('Nelze uložit profil: $error'),
                                              ),
                                            );
                                          } finally {
                                            isSaving.value = false;
                                          }
                                        },
                                  child: isSaving.value
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Uložit změny'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Moje rezervované časy',
                        style: Theme.of(hookContext).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      AsyncValueWidget(
                        value: assignments,
                        builder: (slots) {
                          if (slots.isEmpty) {
                            return const Text('Zatím nemáte žádné rezervované časy.');
                          }
                          final formatter =
                              DateFormat('d. MMMM yyyy HH:mm', 'cs_CZ');
                          return Column(
                            children: [
                              for (final slot in slots)
                                Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.event_available),
                                    title: Text(formatter.format(slot.start)),
                                    subtitle: Text(
                                      slot.participants
                                          .firstWhere(
                                            (p) => p.uid == user.uid,
                                            orElse: () => slot.participants.isNotEmpty
                                                ? slot.participants.first
                                                : const ParticipantSummary(
                                                    uid: '',
                                                    firstName: '',
                                                    lastName: '',
                                                  ),
                                          )
                                          .fullName,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
