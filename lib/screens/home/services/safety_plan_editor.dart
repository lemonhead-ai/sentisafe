import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/safety_plan_model.dart';
import '../../../core/safety_plan_provider.dart';

class SafetyPlanEditor extends StatefulWidget {
  const SafetyPlanEditor({super.key});

  @override
  State<SafetyPlanEditor> createState() => _SafetyPlanEditorState();
}

class _SafetyPlanEditorState extends State<SafetyPlanEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _safeWordController = TextEditingController();
  bool _isFormExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingPlan());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    _safeWordController.dispose();
    super.dispose();
  }

  void _loadExistingPlan() {
    final provider = Provider.of<SafetyPlanProvider>(context, listen: false);
    final plan = provider.safetyPlan;
    if (plan != null) {
      setState(() {
        _safeWordController.text = plan.safeWord;
      });
    }
  }

  void _saveSafeWord() {
    final provider = Provider.of<SafetyPlanProvider>(context, listen: false);
    final existingPlan = provider.safetyPlan;

    final newPlan = SafetyPlan(
      contacts: existingPlan?.contacts ?? [],
      safeWord: _safeWordController.text,
    );

    provider.saveSafetyPlan(newPlan);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Safe word updated')),
    );
  }

  void _saveContact() {
    if (_formKey.currentState!.validate()) {
      final contact = EmergencyContact(
        name: _nameController.text,
        phone: _phoneController.text,
        relationship: _relationshipController.text,
      );

      final provider = Provider.of<SafetyPlanProvider>(context, listen: false);
      final existingPlan = provider.safetyPlan;

      final newPlan = SafetyPlan(
        contacts: [...(existingPlan?.contacts ?? []), contact],
        safeWord: existingPlan?.safeWord ?? _safeWordController.text,
      );

      provider.saveSafetyPlan(newPlan);
      _clearForm();
      _toggleForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact saved successfully')),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _relationshipController.clear();
  }

  void _toggleForm() {
    setState(() {
      _isFormExpanded = !_isFormExpanded;
    });
  }

  void _deleteContact(EmergencyContact contact) {
    final provider = Provider.of<SafetyPlanProvider>(context, listen: false);
    final currentPlan = provider.safetyPlan;

    if (currentPlan == null) return;

    final newContacts = List<EmergencyContact>.from(currentPlan.contacts)
      ..removeWhere((c) => c.phone == contact.phone && c.name == contact.name);

    final newPlan = SafetyPlan(
      contacts: newContacts,
      safeWord: currentPlan.safeWord,
    );

    provider.saveSafetyPlan(newPlan);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Safety Plan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSafeWordSection(),
            const SizedBox(height: 24),
            _buildContactsHeader(),
            const SizedBox(height: 16),
            if (_isFormExpanded) _buildContactForm(),
            const SizedBox(height: 16),
            _buildContactsList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleForm,
        icon: Icon(_isFormExpanded ? Icons.close : Icons.add),
        label: Text(_isFormExpanded ? 'Close' : 'Add Contact'),
      ),
    );
  }

  Widget _buildSafeWordSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Safe Word',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _safeWordController,
              decoration: InputDecoration(
                hintText: 'Enter a word that signals emergency',
                prefixIcon: const Icon(Icons.security),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSafeWord,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Save Safe Word', style: GoogleFonts.poppins()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsHeader() {
    return Text(
      'Emergency Contacts',
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildContactForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Contact',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Contact Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Phone number is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relationshipController,
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Relationship is required' : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveContact,
                  icon: const Icon(Icons.save),
                  label: Text('Save Contact', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    return Consumer<SafetyPlanProvider>(
      builder: (context, provider, _) {
        final contacts = provider.safetyPlan?.contacts ?? [];

        if (contacts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No emergency contacts added yet',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the "Add Contact" button to add someone',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 25,
                  child: Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  contact.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          contact.phone,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          contact.relationship,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: () => _showDeleteConfirmation(contact),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Contact', style: GoogleFonts.poppins()),
        content: Text(
          'Are you sure you want to delete ${contact.name} from your emergency contacts?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              _deleteContact(contact);
              Navigator.of(context).pop();
            },
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}