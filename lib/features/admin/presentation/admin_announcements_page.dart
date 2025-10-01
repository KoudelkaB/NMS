import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../application/admin_providers.dart';
import '../data/announcement_type.dart';

class AdminAnnouncementsPage extends HookConsumerWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    if (user?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Administrace oznámení'),
        ),
        body: const Center(
          child: Text('Nemáte oprávnění pro přístup k této stránce.'),
        ),
      );
    }

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final titleController = useTextEditingController();
    final messageController = useTextEditingController();
    final type = useState(AdminAnnouncementType.information);
    final controller = ref.watch(adminAnnouncementControllerProvider);

    ref.listen(adminAnnouncementControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          titleController.clear();
          messageController.clear();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Oznámení bylo odesláno')),
            );
          }
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrace oznámení'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<AdminAnnouncementType>(
                initialValue: type.value,
                decoration: const InputDecoration(
                  labelText: 'Typ oznámení',
                ),
                items: AdminAnnouncementType.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  type.value = value ?? AdminAnnouncementType.information;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titulek'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Zadejte titulek';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Zpráva',
                ),
                minLines: 4,
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Zadejte text zprávy';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: controller.isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        await ref
                            .read(adminAnnouncementControllerProvider.notifier)
                            .sendAnnouncement(
                              type: type.value,
                              title: titleController.text.trim(),
                              message: messageController.text.trim(),
                            );
                      },
                icon: controller.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Odeslat oznámení'),
              ),
              if (controller.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  controller.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
