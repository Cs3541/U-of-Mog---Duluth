
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';

class AddEventSheet extends StatefulWidget {
  const AddEventSheet({
    super.key,
    required this.initialDate,
  });

  final DateTime initialDate;

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();

  late DateTime _date = widget.initialDate;
  TimeOfDay _time = TimeOfDay.now();

  EventCategory _category = EventCategory.run;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  // Pick event date
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  // Pick event time
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );

    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  // Save event
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      Event(
        id: '',
        title: _title.text.trim(),
        date: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _time.hour,
          _time.minute,
        ),
        category: _category,
        location: _location.text.trim(),
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New event',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 16),

              // Event categories
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in EventCategory.values)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) {
                        setState(() => _category = c);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Event title
              TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Enter a title'
                        : null,
              ),

              const SizedBox(height: 12),

              // Date and time
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(
                        Icons.calendar_today,
                        size: 18,
                      ),
                      label: Text(DateFormat.yMMMd().format(_date)),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(
                        Icons.schedule,
                        size: 18,
                      ),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Location
              TextFormField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              FilledButton(
                onPressed: _save,
                child: const Text('Save event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
