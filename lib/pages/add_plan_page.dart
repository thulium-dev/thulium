// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:thulium_campus/thulium_campus.dart';
import 'package:thulium/l10n/generated/app_localizations.dart';

/// Collects one plan and an optional new category as a single draft.
/// The caller persists both atomically, so canceling leaves no category.
final class AddPlanPage extends StatefulWidget {
  const AddPlanPage({
    required this.initialDate,
    required this.categories,
    required this.onSave,
    this.initialPlan,
    this.initialOccurrence,
    this.singleOccurrence = false,
    super.key,
  });

  final DateTime initialDate;
  final List<CustomPlanCategory> categories;

  /// Existing values to edit; the caller decides whether to replace one
  /// occurrence or the whole repeating rule after this form is submitted.
  final CustomPlan? initialPlan;

  /// A dated lesson or rule occurrence can contain missing data that the edit
  /// form will require the user to complete before saving.
  final CourseOccurrence? initialOccurrence;
  final bool singleOccurrence;
  final Future<void> Function(CustomPlan plan, CustomPlanCategory? category)
  onSave;

  @override
  State<AddPlanPage> createState() => _AddPlanPageState();
}

final class _AddPlanPageState extends State<AddPlanPage> {
  static const _NEW_CATEGORY = '__new_category__';
  static const _COLORS = <int>[
    0xFF6B5CE7,
    0xFFE65C73,
    0xFF1C9B86,
    0xFFDD8838,
    0xFF3988D4,
    0xFFAA63BD,
  ];

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initialOccurrence?.name ?? widget.initialPlan?.name,
  );
  late final _location = TextEditingController(
    text: widget.initialOccurrence?.location ?? widget.initialPlan?.location,
  );
  final _categoryName = TextEditingController();
  late final _interval = TextEditingController(
    text: (widget.initialPlan?.intervalDays ?? 2).toString(),
  );
  late final _date = FDateFieldController(date: widget.initialDate);
  late final _start = FTimeFieldController(
    time: widget.initialOccurrence != null
        ? FTime.fromDateTime(widget.initialOccurrence!.startsAt)
        : widget.initialPlan != null
        ? FTime.fromDateTime(widget.initialPlan!.startsAt)
        : const FTime(9),
  );
  late final _end = FTimeFieldController(
    time: widget.initialOccurrence != null
        ? FTime.fromDateTime(widget.initialOccurrence!.endsAt)
        : widget.initialPlan != null
        ? FTime.fromDateTime(widget.initialPlan!.endsAt)
        : const FTime(10),
  );
  late String _selectedCategory =
      widget.initialOccurrence?.category ??
      widget.initialPlan?.category ??
      PlanCategories.LESSON;
  late PlanRepeat _repeat = widget.singleOccurrence
      ? PlanRepeat.none
      : widget.initialPlan?.repeat ?? PlanRepeat.none;
  int _colorValue = _COLORS.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _categoryName.dispose();
    _interval.dispose();
    _date.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final date = _date.value;
    final start = _start.value;
    final end = _end.value;
    if (date == null || start == null || end == null) {
      setState(() => _error = l10n.planTimeRequired);
      return;
    }
    final startsAt = DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );
    final endsAt = DateTime(
      date.year,
      date.month,
      date.day,
      end.hour,
      end.minute,
    );
    if (!endsAt.isAfter(startsAt)) {
      setState(() => _error = l10n.planEndAfterStart);
      return;
    }
    final intervalDays = int.tryParse(_interval.text.trim());
    if (_repeat == PlanRepeat.intervalDays &&
        (intervalDays == null || intervalDays < 1)) {
      setState(() => _error = l10n.planIntervalInvalid);
      return;
    }

    CustomPlanCategory? newCategory;
    if (_selectedCategory == _NEW_CATEGORY) {
      final name = _categoryName.text.trim();
      if (name.isEmpty) {
        setState(() => _error = l10n.requiredField);
        return;
      }
      if (name.toLowerCase() == l10n.planLessonCategory.toLowerCase() ||
          name.toLowerCase() == PlanCategories.LESSON ||
          widget.categories.any(
            (category) => category.name.toLowerCase() == name.toLowerCase(),
          )) {
        setState(() => _error = l10n.planCategoryDuplicate);
        return;
      }
      newCategory = CustomPlanCategory(
        id: 'user.${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        colorValue: _colorValue,
      );
    }
    final plan = CustomPlan(
      id:
          widget.initialPlan?.id ??
          'plan.${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      location: _location.text.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      category: newCategory?.id ?? _selectedCategory,
      repeat: _repeat,
      intervalDays: _repeat == PlanRepeat.intervalDays ? intervalDays! : 1,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(plan, newCategory);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.planSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = context.theme.colors;
    final repeatLabels = <PlanRepeat, String>{
      PlanRepeat.none: l10n.planRepeatNone,
      PlanRepeat.daily: l10n.planRepeatDaily,
      PlanRepeat.weekly: l10n.planRepeatWeekly,
      PlanRepeat.intervalDays: l10n.planRepeatInterval,
    };
    return FScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FButton.icon(
                        semanticsLabel: l10n.backAction,
                        variant: FButtonVariant.ghost,
                        onPress: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.initialPlan == null &&
                              widget.initialOccurrence == null
                          ? l10n.planAddTitle
                          : l10n.planEditTitle,
                      style: context.theme.typography.xl2,
                    ),
                    const SizedBox(height: 24),
                    FTextFormField(
                      control: FTextFieldControl.managed(controller: _name),
                      label: Text(l10n.planName),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.requiredField
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FTextFormField(
                      control: FTextFieldControl.managed(controller: _location),
                      label: Text(l10n.planLocation),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.requiredField
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FDateField.calendar(
                      control: FDateFieldControl.managed(controller: _date),
                      label: Text(l10n.planDate),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FTimeField.picker(
                            control: FTimeFieldControl.managed(
                              controller: _start,
                            ),
                            hour24: true,
                            label: Text(l10n.planStartTime),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FTimeField.picker(
                            control: FTimeFieldControl.managed(
                              controller: _end,
                            ),
                            hour24: true,
                            label: Text(l10n.planEndTime),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FSelect<String>.rich(
                      label: Text(l10n.planCategory),
                      control: FSelectControl<String>.lifted(
                        value: _selectedCategory,
                        onChange: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                              _error = null;
                            });
                          }
                        },
                      ),
                      format: (value) {
                        if (value == PlanCategories.LESSON) {
                          return l10n.planLessonCategory;
                        }
                        if (value == _NEW_CATEGORY) return l10n.planNewCategory;
                        for (final category in widget.categories) {
                          if (category.id == value) return category.name;
                        }
                        return value;
                      },
                      children: [
                        FSelectItem<String>(
                          title: Text(l10n.planLessonCategory),
                          value: PlanCategories.LESSON,
                        ),
                        for (final category in widget.categories)
                          FSelectItem<String>(
                            title: Text(category.name),
                            value: category.id,
                            prefix: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(category.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        FSelectItem<String>(
                          title: Text(l10n.planNewCategory),
                          value: _NEW_CATEGORY,
                        ),
                      ],
                    ),
                    if (_selectedCategory == _NEW_CATEGORY) ...[
                      const SizedBox(height: 12),
                      FTextField(
                        control: FTextFieldControl.managed(
                          controller: _categoryName,
                        ),
                        label: Text(l10n.planCategoryName),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.planCategoryColor,
                        style: context.theme.typography.sm,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          for (final value in _COLORS)
                            Semantics(
                              button: true,
                              selected: _colorValue == value,
                              label:
                                  '${l10n.planCategoryColor} ${_COLORS.indexOf(value) + 1}',
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _colorValue = value),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Color(value),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _colorValue == value
                                          ? color.foreground
                                          : color.border,
                                      width: _colorValue == value ? 3 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (!widget.singleOccurrence) ...[
                      const SizedBox(height: 24),
                      Text(l10n.planRepeat, style: context.theme.typography.sm),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in repeatLabels.entries)
                            _choice(
                              entry.value,
                              _repeat == entry.key,
                              () => setState(() => _repeat = entry.key),
                            ),
                        ],
                      ),
                      if (_repeat == PlanRepeat.intervalDays) ...[
                        const SizedBox(height: 12),
                        FTextField(
                          control: FTextFieldControl.managed(
                            controller: _interval,
                          ),
                          label: Text(l10n.planIntervalDays),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: context.theme.typography.sm.copyWith(
                          color: color.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FButton(
                      onPress: _saving ? null : _save,
                      child: Text(
                        widget.initialPlan == null &&
                                widget.initialOccurrence == null
                            ? l10n.planSave
                            : l10n.planSaveChanges,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onPress) => FButton(
    variant: selected ? FButtonVariant.primary : FButtonVariant.outline,
    size: FButtonSizeVariant.sm,
    mainAxisSize: MainAxisSize.min,
    onPress: onPress,
    child: Text(label),
  );
}
