import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin.dart';
import '../services/super_admin_service.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({Key? key}) : super(key: key);

  @override
  _AdminManagementScreenState createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  late Future<List<Admin>> _adminsFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  void _loadAdmins() {
    final superAdminService = Provider.of<SuperAdminService>(
      context,
      listen: false,
    );
    _adminsFuture = superAdminService.getAllAdmins();
  }

  Future<void> _refreshAdmins() async {
    setState(() {
      _loadAdmins();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Admin>>(
          future: _adminsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshAdmins,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No admins found'));
            }

            final admins = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: admins.length,
              itemBuilder: (context, index) {
                final admin = admins[index];
                return _buildAdminCard(admin);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminCard(Admin admin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      admin.isSuperAdmin
                          ? Colors.amber
                          : Theme.of(context).primaryColor,
                  child: Icon(
                    admin.isSuperAdmin
                        ? Icons.admin_panel_settings
                        : Icons.person,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        admin.username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        admin.email,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: admin.isActive,
                  onChanged: (value) => _updateAdminStatus(admin, value),
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Chip(
                  label: Text(
                    admin.isSuperAdmin ? 'Super Admin' : 'Admin',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor:
                      admin.isSuperAdmin
                          ? Colors.amber
                          : Theme.of(context).primaryColor,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditAdminDialog(context, admin),
                  tooltip: 'Edit Admin',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAdminStatus(Admin admin, bool isActive) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final superAdminService = Provider.of<SuperAdminService>(
        context,
        listen: false,
      );

      await superAdminService.updateAdmin(admin.id, isActive: isActive);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Admin ${admin.username} ${isActive ? 'activated' : 'deactivated'} successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _refreshAdmins();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating admin: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddAdminDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String username = '';
    String email = '';
    String password = '';
    bool isSuperAdmin = false;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Admin'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        icon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                      onSaved: (value) => username = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        icon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      onSaved: (value) => email = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        icon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onSaved: (value) => password = value!,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Super Admin'),
                      subtitle: const Text('Grant super admin privileges'),
                      value: isSuperAdmin,
                      onChanged: (value) {
                        isSuperAdmin = value;
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    Navigator.of(context).pop();

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      final superAdminService = Provider.of<SuperAdminService>(
                        context,
                        listen: false,
                      );

                      await superAdminService.createAdmin(
                        username,
                        email,
                        password,
                        isSuperAdmin,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Admin created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      _refreshAdmins();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating admin: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showEditAdminDialog(BuildContext context, Admin admin) {
    final formKey = GlobalKey<FormState>();
    String username = admin.username;
    String email = admin.email;
    String? password;
    bool isSuperAdmin = admin.isSuperAdmin;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Admin: ${admin.username}'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: admin.username,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        icon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                      onSaved: (value) => username = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: admin.email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        icon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      onSaved: (value) => email = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'New Password (optional)',
                        icon: Icon(Icons.lock),
                        hintText: 'Leave blank to keep current password',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onSaved:
                          (value) => password = value!.isEmpty ? null : value,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Super Admin'),
                      subtitle: const Text('Grant super admin privileges'),
                      value: isSuperAdmin,
                      onChanged: (value) {
                        isSuperAdmin = value;
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    Navigator.of(context).pop();

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      final superAdminService = Provider.of<SuperAdminService>(
                        context,
                        listen: false,
                      );

                      await superAdminService.updateAdmin(
                        admin.id,
                        username: username,
                        email: email,
                        password: password,
                        isSuperAdmin: isSuperAdmin,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Admin updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      _refreshAdmins();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating admin: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }
}
