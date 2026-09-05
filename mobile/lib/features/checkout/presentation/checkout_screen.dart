import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/address.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../addresses/providers/addresses_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../domain/checkout_models.dart';
import '../providers/checkout_provider.dart';


class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstname = TextEditingController();
  final _lastname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  Future<CheckoutPreview>? _previewFuture;
  String _mode = 'guest';
  String _title = 'M.';
  bool _createAccount = false;
  bool _terms = false;
  bool _loginLoading = false;
  bool _confirming = false;
  bool _orderConfirmed = false;
  bool _successHandled = false;
  bool _successNavigationDone = false;
  String? _message;
  int? _selectedCarrierId;
  String? _selectedPaymentModule;
  int? _activeAddressId;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = DateTime.now().microsecondsSinceEpoch.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        final addresses = ref.read(addressesProvider).valueOrNull;
        final firstAddress = addresses?.firstOrNull;
        if (firstAddress != null) {
          _activeAddressId = firstAddress.id;
        }
      }
      _loadPreview(addressId: _activeAddressId);
    });
  }

  @override
  void dispose() {
    _firstname.dispose();
    _lastname.dispose();
    _email.dispose();
    _password.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _loadPreview({int? carrierId, int? addressId, bool keepCarrier = false}) {
    final lines = CheckoutLineRequest.fromCart(ref.read(cartProvider));
    setState(() {
      if (!keepCarrier) {
        _selectedCarrierId = carrierId;
      }
      if (addressId != null) {
        _activeAddressId = addressId;
      }
      _selectedPaymentModule = null;
      _previewFuture = ref.read(checkoutRepositoryProvider).preview(
            lines: lines,
            carrierId: carrierId,
            addressId: addressId ?? _activeAddressId,
          );
    });
  }

  void _recalculateForCarrier(int carrierId) {
    setState(() {
      _selectedCarrierId = carrierId;
      _message = null;
      _previewFuture = ref.read(checkoutRepositoryProvider).preview(
            lines: CheckoutLineRequest.fromCart(ref.read(cartProvider)),
            carrierId: carrierId,
            addressId: _activeAddressId,
          );
    });
  }

  void _ensureCheckoutSelections(CheckoutPreview preview) {
    final carrierIds = preview.carriers.map((carrier) => carrier.id).toSet();
    final paymentModules = preview.payments
        .map((payment) => payment.module)
        .where((module) => module.isNotEmpty)
        .toSet();
    final nextCarrierId = carrierIds.contains(_selectedCarrierId)
        ? _selectedCarrierId
        : (carrierIds.contains(preview.selectedCarrierId)
            ? preview.selectedCarrierId
            : null);
    final nextPaymentModule = paymentModules.contains(_selectedPaymentModule)
        ? _selectedPaymentModule
        : (preview.payments.isEmpty ? null : preview.payments.first.module);

    if (nextCarrierId != _selectedCarrierId ||
        nextPaymentModule != _selectedPaymentModule) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedCarrierId = nextCarrierId;
          _selectedPaymentModule = nextPaymentModule;
        });
      });
    }
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = 'Renseignez votre email et mot de passe.');
      return;
    }

    setState(() {
      _loginLoading = true;
      _message = null;
    });

    try {
      await ref.read(authRepositoryProvider).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      ref.invalidate(currentUserProvider);
      ref.invalidate(addressesProvider);
      setState(() => _message = 'Connexion réussie.');
    } catch (_) {
      setState(() => _message = 'Connexion impossible pour ce compte.');
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  Future<void> _confirm(
    CheckoutPreview preview, {
    required bool isConnected,
    required AddressModel? userAddress,
  }) async {
    if (_confirming || _orderConfirmed) {
      return;
    }
    if (!_terms) {
      setState(() => _message = 'Acceptez les conditions générales.');
      return;
    }
    if (!preview.stockOk) {
      setState(() => _message = 'Stock insuffisant pour confirmer.');
      return;
    }
    final carrierId = _selectedCarrierId;
    final paymentModule = _selectedPaymentModule ??
        (preview.payments.isEmpty ? null : preview.payments.first.module);
    if (preview.carriers.isNotEmpty && carrierId == null) {
      setState(() => _message = 'Sélectionnez un mode de livraison.');
      return;
    }
    if (paymentModule == null || paymentModule.isEmpty) {
      setState(() => _message = 'Sélectionnez un moyen de paiement.');
      return;
    }

    if (isConnected) {
      if (userAddress == null) {
        setState(() =>
            _message = 'Veuillez ajouter une adresse de livraison pour continuer.');
        return;
      }
    } else {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }
    }

    setState(() {
      _confirming = true;
      _message = null;
    });

    try {
      final effectiveMode = isConnected ? 'login' : _mode;
      final result = await ref.read(checkoutRepositoryProvider).confirm(
            lines: CheckoutLineRequest.fromCart(ref.read(cartProvider)),
            mode: effectiveMode,
            idempotencyKey: _idempotencyKey,
            guest: !isConnected && effectiveMode == 'guest'
                ? {
                    'title': _title,
                    'firstname': _firstname.text.trim(),
                    'lastname': _lastname.text.trim(),
                    'email': _email.text.trim(),
                    'create_account': _createAccount,
                    if (_createAccount && _password.text.isNotEmpty)
                      'password': _password.text,
                  }
                : null,
            address: isConnected
                ? null
                : {
                    'firstname': _firstname.text.trim(),
                    'lastname': _lastname.text.trim(),
                    'address1': _address.text.trim(),
                    'city': _city.text.trim(),
                    if (_phone.text.trim().isNotEmpty)
                      'phone': _phone.text.trim(),
                  },
            addressId: isConnected ? userAddress?.id : null,
            carrierId: carrierId,
            paymentModule: paymentModule,
          );
      if (!mounted) return;
      setState(() {
        _orderConfirmed = true;
        _confirming = false;
      });
      _handleSuccessfulOrder(result, preview);
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? (error.response?.data['detail']?.toString())
          : null;
      setState(
        () => _message = detail?.isNotEmpty == true
            ? detail
            : 'Impossible de confirmer cette commande.',
      );
    } catch (_) {
      setState(
        () => _message = 'Impossible de confirmer cette commande.',
      );
    } finally {
      if (mounted && !_orderConfirmed) {
        setState(() => _confirming = false);
      }
    }
  }

  Future<void> _handleSuccessfulOrder(
    CheckoutConfirmResult result,
    CheckoutPreview preview,
  ) async {
    if (_successHandled) {
      return;
    }
    _successHandled = true;
    ref.read(cartProvider.notifier).clear();
    await _showOrderSuccessDialog(result, preview);
  }

  Future<void> _showOrderSuccessDialog(
    CheckoutConfirmResult result,
    CheckoutPreview preview,
  ) async {
    var closedByAction = false;
    Future<void> navigateTo(String location) async {
      if (_successNavigationDone || !mounted) {
        return;
      }
      _successNavigationDone = true;
      closedByAction = true;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      context.go(location);
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (!closedByAction && mounted && !_successNavigationDone) {
        navigateTo('/orders');
      }
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _OrderSuccessDialog(
        result: result,
        fallbackTotal: preview.totals.totalTtc,
        fallbackCurrency: preview.totals.currencySymbol,
        onOrders: () => navigateTo('/orders'),
        onHome: () => navigateTo('/'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final authState = ref.watch(currentUserProvider);
    final user = authState.valueOrNull;
    final isConnected = user != null;

    final addressesAsync = isConnected ? ref.watch(addressesProvider) : null;
    final userAddresses = addressesAsync?.valueOrNull;
    final userAddress = userAddresses?.firstOrNull;

    ref.listen(addressesProvider, (previous, next) {
      final address = next.valueOrNull?.firstOrNull;
      if (address != null && address.id != _activeAddressId) {
        _loadPreview(
          carrierId: _selectedCarrierId,
          addressId: address.id,
          keepCarrier: true,
        );
      }
    });

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Checkout',
        showBack: true,
        backFallbackLocation: '/cart',
      ),
      body: SafeArea(
        child: cartItems.isEmpty
            ? ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Panier vide',
                  message: 'Ajoutez des produits avant de commander.',
                  action: FilledButton.icon(
                    onPressed: () => context.go('/catalog'),
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Ouvrir le catalogue'),
                  ),
                ),
              )
            : FutureBuilder<CheckoutPreview>(
                future: _previewFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return ResponsivePagePadding(
                      child: AppStatusPanel(
                        icon: Icons.cloud_off_rounded,
                        title: 'Checkout indisponible',
                        message:
                            'Impossible de préparer le checkout PrestaShop.',
                        action: OutlinedButton.icon(
                          onPressed: () => _loadPreview(addressId: _activeAddressId),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      ),
                    );
                  }

                  final preview = snapshot.data!;
                  _ensureCheckoutSelections(preview);
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ResponsivePagePadding(
                        bottom: 96,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isConnected) ...[
                                _ModeSelector(
                                  mode: _mode,
                                  onChanged: (value) {
                                    setState(() {
                                      _mode = value;
                                      _message = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),
                                if (_mode == 'guest')
                                  _GuestStep(
                                    title: _title,
                                    firstname: _firstname,
                                    lastname: _lastname,
                                    email: _email,
                                    password: _password,
                                    createAccount: _createAccount,
                                    onTitleChanged: (value) =>
                                        setState(() => _title = value),
                                    onCreateAccountChanged: (value) => setState(
                                      () => _createAccount = value,
                                    ),
                                  )
                                else
                                  _LoginStep(
                                    email: _email,
                                    password: _password,
                                    loading: _loginLoading,
                                    onLogin: _login,
                                  ),
                                const SizedBox(height: 14),
                                _AddressStep(
                                  address: _address,
                                  city: _city,
                                  phone: _phone,
                                ),
                              ] else ...[
                                _UsedAddressPanel(
                                  address: userAddress,
                                  isLoading: addressesAsync?.isLoading ?? false,
                                  onManageAddress: () async {
                                    await context.push(
                                      '/addresses?from=checkout',
                                    );
                                    if (mounted) {
                                      ref.invalidate(addressesProvider);
                                    }
                                  },
                                ),
                              ],
                              const SizedBox(height: 14),
                              _CheckoutOptions(
                                preview: preview,
                                selectedCarrierId: _selectedCarrierId,
                                selectedPaymentModule: _selectedPaymentModule,
                                onCarrierChanged: (value) {
                                  if (value != null) {
                                    _recalculateForCarrier(value);
                                  }
                                },
                                onPaymentChanged: (value) => setState(
                                  () => _selectedPaymentModule = value,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _CheckoutSummary(preview: preview),
                              const SizedBox(height: 14),
                              Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: _terms,
                                  onChanged: (value) {
                                    setState(() => _terms = value ?? false);
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: const Text(
                                    "J'accepte les conditions générales de vente",
                                  ),
                                ),
                              ),
                              if (_message != null) ...[
                                const SizedBox(height: 8),
                                _Notice(message: _message!),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _confirming || _orderConfirmed
                                      ? null
                                      : () => _confirm(
                                            preview,
                                            isConnected: isConnected,
                                            userAddress: userAddress,
                                          ),
                                  icon: _confirming
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle_rounded),
                                  label: Text(
                                    _confirming
                                        ? 'Confirmation en cours...'
                                        : _orderConfirmed
                                            ? 'Commande confirmée'
                                            : preview.writeEnabled
                                                ? 'Confirmer la commande'
                                                : 'Vérifier la commande',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'guest',
          icon: Icon(Icons.person_add_alt_1_rounded),
          label: Text("Commander en tant qu'invité"),
        ),
        ButtonSegment(
          value: 'login',
          icon: Icon(Icons.login_rounded),
          label: Text('Connexion'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class _GuestStep extends StatelessWidget {
  const _GuestStep({
    required this.title,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.password,
    required this.createAccount,
    required this.onTitleChanged,
    required this.onCreateAccountChanged,
  });

  final String title;
  final TextEditingController firstname;
  final TextEditingController lastname;
  final TextEditingController email;
  final TextEditingController password;
  final bool createAccount;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<bool> onCreateAccountChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Informations personnelles',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: title,
            decoration: const InputDecoration(labelText: 'Titre'),
            items: const [
              DropdownMenuItem(value: 'M.', child: Text('M.')),
              DropdownMenuItem(value: 'Mme', child: Text('Mme')),
            ],
            onChanged: (value) {
              if (value != null) onTitleChanged(value);
            },
          ),
          const SizedBox(height: 12),
          _RequiredField(controller: firstname, label: 'Prénom'),
          const SizedBox(height: 12),
          _RequiredField(controller: lastname, label: 'Nom'),
          const SizedBox(height: 12),
          _RequiredField(
            controller: email,
            label: 'E-mail',
            keyboardType: TextInputType.emailAddress,
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: createAccount,
              onChanged: (value) => onCreateAccountChanged(value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Créer votre compte'),
            ),
          ),
          if (createAccount)
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
        ],
      ),
    );
  }
}

class _LoginStep extends StatelessWidget {
  const _LoginStep({
    required this.email,
    required this.password,
    required this.loading,
    required this.onLogin,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Connexion',
      child: Column(
        children: [
          _RequiredField(
            controller: email,
            label: 'E-mail',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _RequiredField(
            controller: password,
            label: 'Mot de passe',
            obscureText: true,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onLogin,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(loading ? 'Connexion...' : 'Connexion'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({
    required this.address,
    required this.city,
    required this.phone,
  });

  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController phone;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Adresse',
      child: Column(
        children: [
          _RequiredField(controller: address, label: 'Adresse'),
          const SizedBox(height: 12),
          _RequiredField(controller: city, label: 'Ville'),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutOptions extends StatelessWidget {
  const _CheckoutOptions({
    required this.preview,
    required this.selectedCarrierId,
    required this.selectedPaymentModule,
    required this.onCarrierChanged,
    required this.onPaymentChanged,
  });

  final CheckoutPreview preview;
  final int? selectedCarrierId;
  final String? selectedPaymentModule;
  final ValueChanged<int?> onCarrierChanged;
  final ValueChanged<String?> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Livraison et paiement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.carriers.isEmpty)
            const _MutedLine('Aucun transporteur retourné par PrestaShop')
          else
            for (final carrier in preview.carriers)
              _ChoiceLine(
                selected: carrier.id == selectedCarrierId,
                icon: Icons.local_shipping_rounded,
                title: Text(carrier.name),
                subtitle: (carrier.priceLabel ?? carrier.delay) == null
                    ? null
                    : Text((carrier.priceLabel ?? carrier.delay)!),
                onTap: () => onCarrierChanged(carrier.id),
              ),
          const Divider(height: 24),
          if (preview.payments.isEmpty)
            const _MutedLine('Aucun paiement retourné par PrestaShop')
          else
            for (final payment in preview.payments)
              _ChoiceLine(
                selected: payment.module == selectedPaymentModule,
                icon: Icons.payments_rounded,
                title: Text(payment.name),
                subtitle: const Text('Disponible pour ce panier'),
                onTap: () => onPaymentChanged(payment.module),
              ),
        ],
      ),
    );
  }
}

class _ChoiceLine extends StatelessWidget {
  const _ChoiceLine({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final IconData icon;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.softBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.leaf : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSuccessDialog extends StatelessWidget {
  const _OrderSuccessDialog({
    required this.result,
    required this.fallbackTotal,
    required this.fallbackCurrency,
    required this.onOrders,
    required this.onHome,
  });

  final CheckoutConfirmResult result;
  final double fallbackTotal;
  final String fallbackCurrency;
  final VoidCallback onOrders;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final total = result.total ?? fallbackTotal;
    final currency = result.currency ?? fallbackCurrency;
    final formattedTotal = formatMoney(total, currency: currency);

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.softLeaf,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.leaf,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Commande confirmée !',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre commande a bien été enregistrée.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(
                  children: [
                    if (result.reference?.isNotEmpty == true)
                      _SuccessMetaRow(
                        label: 'Référence',
                        value: result.reference!,
                      ),
                    _SuccessMetaRow(
                      label: 'Total',
                      value: formattedTotal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vous pouvez suivre son état depuis Mes commandes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOrders,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Voir ma commande'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text("Retour à l'accueil"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessMetaRow extends StatelessWidget {
  const _SuccessMetaRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.preview});

  final CheckoutPreview preview;

  @override
  Widget build(BuildContext context) {
    final totals = preview.totals;
    return _Panel(
      title: 'Récapitulatif',
      child: Column(
        children: [
          for (final line in preview.lines) _LineStatus(line: line),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Sous-total',
            value: formatMoney(totals.subtotal,
                currency: totals.currency, symbol: totals.currencySymbol),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Livraison', value: totals.shippingLabel),
          if (totals.discounts > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Réductions',
              value: formatMoney(totals.discounts,
                  currency: totals.currency, symbol: totals.currencySymbol),
            ),
          ],
          const Divider(height: 24),
          _SummaryRow(
            label: 'Total TTC',
            value: formatMoney(totals.totalTtc,
                currency: totals.currency, symbol: totals.currencySymbol),
            strong: true,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Taxes incluses',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineStatus extends StatelessWidget {
  const _LineStatus({required this.line});

  final CheckoutLine line;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          line.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Quantité ${line.quantity}'),
        trailing: Icon(
          line.available ? Icons.check_circle_rounded : Icons.error_rounded,
          color: line.available ? AppColors.leaf : AppColors.danger,
        ),
      ),
    );
  }
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Champ obligatoire';
        }
        return null;
      },
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softSun,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: strong ? AppColors.ink : AppColors.muted,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: strong ? AppColors.blue : AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _UsedAddressPanel extends StatelessWidget {
  const _UsedAddressPanel({
    required this.address,
    required this.isLoading,
    required this.onManageAddress,
  });

  final AddressModel? address;
  final bool isLoading;
  final VoidCallback onManageAddress;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Adresse de livraison',
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          : address != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.softBlue,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (address!.fullName.isNotEmpty)
                                Text(
                                  address!.fullName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                ),
                              Text(
                                address!.address1,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                              ),
                              if (address!.address2?.trim().isNotEmpty == true)
                                Text(
                                  address!.address2!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              Text(
                                [address!.postcode, address!.city]
                                    .whereType<String>()
                                    .where((s) => s.trim().isNotEmpty)
                                    .join(' '),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                              ),
                              if (address!.phone?.trim().isNotEmpty == true ||
                                  address!.phoneMobile?.trim().isNotEmpty ==
                                      true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_rounded,
                                      size: 14,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (address!.phoneMobile?.trim().isNotEmpty ==
                                                  true
                                              ? address!.phoneMobile
                                              : address!.phone) ??
                                          '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onManageAddress,
                        icon: const Icon(
                          Icons.edit_location_alt_rounded,
                          size: 16,
                        ),
                        label: const Text('Modifier mon adresse'),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.softSun,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Aucune adresse enregistrée sur votre compte.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onManageAddress,
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: const Text('Ajouter une adresse de livraison'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
