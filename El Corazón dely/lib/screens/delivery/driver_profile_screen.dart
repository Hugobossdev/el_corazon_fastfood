import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import '../../services/app_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/storage_service.dart';
import '../../models/user.dart';
import '../../models/driver.dart';
import '../../models/driver_badge.dart';
import '../../models/driver_rating.dart';
import '../../utils/validators.dart';
import '../../ui/ui.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();
  final _vehicleController = TextEditingController();
  
  final ImagePicker _imagePicker = ImagePicker();
  io.File? _newProfilePhoto;
  Uint8List? _newProfilePhotoBytes;
  
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoadingDriverData = true;

  Driver? _driverProfile;
  List<DriverBadge> _badges = [];
  List<DriverRating> _ratings = [];
  Map<String, dynamic>? _detailedStats;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted || !context.mounted) return;
    final appService = Provider.of<AppService>(context, listen: false);
    final user = appService.currentUser;

    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _emailController.text = user.email;
      
      await _loadDriverData(user.id);
    }
  }

  Future<void> _loadDriverData(String userId) async {
    if (!mounted || !context.mounted) return;
    
    setState(() {
      _isLoadingDriverData = true;
    });

    try {
      if (!mounted || !context.mounted) return;
      final appService = Provider.of<AppService>(context, listen: false);
      final databaseService = appService.databaseService;

      // 1. Charger le profil driver
      // Note: getDriverProfile retourne une map avec les infos user jointes
      // Nous avons besoin des infos spécifiques driver pour le modèle Driver
      // On va essayer de récupérer via la table drivers directement si nécessaire
      // ou parser la réponse existante.
      
      // Utilisation de la méthode existante getDriverProfile qui tape sur drivers_with_user_info
      final driverData = await databaseService.getDriverProfile(userId);
      
      if (driverData != null) {
        _driverProfile = Driver.fromMap(driverData);
        _licenseController.text = _driverProfile?.licenseNumber ?? '';
        _vehicleController.text = '${_driverProfile?.vehicleType ?? ''} ${_driverProfile?.vehicleNumber ?? ''}'.trim();
      }

      // 2. Charger les badges
      final badgesData = await databaseService.getDriverBadges(_driverProfile?.id ?? '');
      _badges = badgesData.map((data) {
        // La structure retournée par Supabase pour les relations est parfois imbriquée
        // driver_earned_badges contient driver_badges via la clé 'driver_badges'
        if (data['driver_badges'] != null) {
          final badgeInfo = data['driver_badges'] as Map<String, dynamic>;
          // On ajoute la date d'obtention qui est dans la table de liaison
          badgeInfo['earned_at'] = data['earned_at']; 
          // Si le modèle DriverBadge attend 'created_at', on peut utiliser earned_at ou created_at du badge
          // Pour l'affichage, earned_at est plus pertinent.
          // Adaptons selon le modèle DriverBadge.
          return DriverBadge.fromMap(badgeInfo);
        }
        return DriverBadge.fromMap(data);
      }).toList();

      // 3. Charger les avis
      final ratingsData = await databaseService.getDriverRatings(_driverProfile?.id ?? '');
      _ratings = ratingsData.map((data) => DriverRating.fromMap(data)).toList();

      // 4. Charger les stats détaillées
      _detailedStats = await databaseService.getDriverDetailedStats(_driverProfile?.id ?? '');

    } catch (e) {
      debugPrint('Erreur chargement données livreur: $e');
      // On ne bloque pas l'UI, mais on loggue l'erreur
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDriverData = false;
        });
      }
    }
  }

  /// Helper to create a File on mobile only
  /// This ensures we use dart:io.File, not dart:html.File
  io.File _createFileFromPath(String path) {
    if (kIsWeb) {
      throw UnsupportedError('File creation not supported on web');
    }
    // On mobile, io.File is dart:io.File
    // Use a cast to work around conditional import type checking
    // ignore: avoid_dynamic_calls
    return (io.File as dynamic)(path);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _newProfilePhotoBytes = bytes;
            _newProfilePhoto = null;
          });
        } else {
          setState(() {
            _newProfilePhoto = _createFileFromPath(image.path);
            _newProfilePhotoBytes = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sélection de l\'image')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final user = appService.currentUser;

      if (user != null) {
        String? newPhotoUrl;

        // Upload photo if changed
        if (_newProfilePhoto != null || _newProfilePhotoBytes != null) {
          final storageService = StorageService();
          if (kIsWeb && _newProfilePhotoBytes != null) {
            newPhotoUrl = await storageService.uploadDriverDocument(
              userId: user.id,
              fileBytes: _newProfilePhotoBytes!,
              documentType: 'profile_photo',
            );
          } else if (_newProfilePhoto != null) {
            newPhotoUrl = await storageService.uploadFile(
              file: _newProfilePhoto!,
              bucketName: 'driver-documents', // Using consistent bucket
              folder: '${user.id}/profiles',
            );
          }
        }

        // Update user profile in database
        final databaseService = appService.databaseService;
        final updates = {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
        
        if (newPhotoUrl != null) {
          updates['profile_image'] = newPhotoUrl;
        }

        await databaseService.updateUserProfile(user.id, updates);

        // Update driver profile if needed (for photo)
        if (newPhotoUrl != null && _driverProfile != null) {
           // We might want to update the driver table specifically if the photos are stored there too
           // But user profile image is usually sufficient for display
        }

        // Reload user profile
        await appService.initialize();
        if (!mounted || !context.mounted) return;
        await _loadProfile(); // Reload driver data too

        if (!mounted || !context.mounted) return;
        setState(() {
          _isEditing = false;
          _isSaving = false;
          _newProfilePhoto = null;
          _newProfilePhotoBytes = null;
        });

        if (!mounted || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      setState(() {
        _isSaving = false;
      });
      final errorHandler =
          Provider.of<ErrorHandlerService>(context, listen: false);
      errorHandler.logError('Erreur sauvegarde profil', details: e);
      errorHandler.showErrorSnackBar(
          context, 'Erreur lors de la sauvegarde: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _loadProfile();
                });
              },
            ),
        ],
      ),
      body: Consumer<AppService>(
        builder: (context, appService, child) {
          final user = appService.currentUser;
          if (user == null) {
            // Si l'utilisateur est null, on tente de le récupérer ou on affiche une erreur
            if (appService.isInitialized) {
               return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('Profil introuvable'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => appService.initialize(),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: AppSpacing.pagePadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(user),
                  const SizedBox(height: AppSpacing.xl),
                  if (_isLoadingDriverData)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ))
                  else ...[
                    _buildStatsSection(user),
                    const SizedBox(height: AppSpacing.xl),
                    _buildBadgesSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildDriverInfoSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildRatingsSection(),
                    if (_isEditing) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _buildSaveButton(),
                    ],
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    ImageProvider? backgroundImage;
    
    if (_newProfilePhotoBytes != null) {
      backgroundImage = MemoryImage(_newProfilePhotoBytes!);
    } else if (_newProfilePhoto != null) {
      backgroundImage = FileImage(_newProfilePhoto! as dynamic);
    } else if (_driverProfile?.profilePhotoUrl != null) {
      backgroundImage = NetworkImage(_driverProfile!.profilePhotoUrl!);
    }

    return AppCard(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: scheme.surface,
                  backgroundImage: backgroundImage,
                  child: backgroundImage == null
                      ? Text(
                          _initials(user.name),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        )
                      : null,
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                )
              else if (_driverProfile?.verificationStatus == 'approved')
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      Icons.verified,
                      color: scheme.primary,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            user.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user.email,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: user.isOnline ? scheme.secondary : scheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.isOnline ? Icons.online_prediction : Icons.do_not_disturb_on_outlined,
                  size: 16,
                  color: user.isOnline ? scheme.onSecondary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  user.isOnline ? 'En ligne' : 'Hors ligne',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: user.isOnline ? scheme.onSecondary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'DR';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'DR';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p.substring(0, 1)).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Informations personnelles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.validatePhone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Informations livreur',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseController,
              enabled: false, // On ne permet pas de modifier le permis ici pour l'instant
              decoration: const InputDecoration(
                labelText: 'Numéro de permis',
                prefixIcon: Icon(Icons.card_membership),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleController,
              enabled: false, // Idem pour le véhicule
              decoration: const InputDecoration(
                labelText: 'Véhicule',
                prefixIcon: Icon(Icons.directions_bike),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
             _buildVerificationStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStatus() {
    Color color;
    IconData icon;
    String text;

    switch (_driverProfile?.verificationStatus) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Vérifié';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Rejeté';
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = 'En attente';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            'Statut: $text',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Statistiques',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Livraisons',
                    _driverProfile?.completedDeliveries.toString() ?? '0',
                    Icons.delivery_dining,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Note',
                    (_driverProfile?.rating ?? 0.0).toStringAsFixed(1),
                    Icons.star,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Avis',
                    _driverProfile?.totalRatings.toString() ?? '0',
                    Icons.comment,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection() {
    if (_badges.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Badges (${_badges.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Icon(Icons.emoji_events, color: Colors.amber[700]),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _badges.length,
                itemBuilder: (context, index) {
                  final badge = _badges[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badge.iconUrl ?? '🏆', 
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.name,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsSection() {
    if (_ratings.isEmpty && _detailedStats == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Avis et Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_detailedStats != null) ...[
              _buildRatingBreakdown(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            if (_ratings.isNotEmpty) ...[
              Text(
                'Derniers avis',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ratings.take(3).length, // Afficher les 3 derniers
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final rating = _ratings[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
                    title: Row(
                      children: [
                        Text(
                          'Commande #${rating.orderId.substring(0, 4)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.ratingAverage.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    subtitle: rating.comment != null && rating.comment!.isNotEmpty
                        ? Text(rating.comment!)
                        : const Text('Pas de commentaire', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  );
                },
              ),
            ] else
              const Center(child: Text('Aucun avis pour le moment')),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBreakdown() {
    if (_detailedStats == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildBreakdownItem('Ponctualité', _detailedStats!['avg_time_rating']),
        _buildBreakdownItem('Service client', _detailedStats!['avg_service_rating']),
        _buildBreakdownItem('Soin du colis', _detailedStats!['avg_condition_rating']),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, dynamic value) {
    double rating = 0.0;
    if (value is num) rating = value.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: rating / 5.0,
              backgroundColor: Colors.grey[200],
              color: Colors.orange,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 30,
            child: Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sauvegarder',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
