<?php

class HelianthaMobileBridgeCheckoutModuleFrontController
    extends ModuleFrontController
{
    public $ajax = true;

    private function fail($status, $code, $message, $detail = null)
    {
        PrestaShopLogger::addLog(
            'HelianthaMobileBridge checkout ' . $code . ': ' . $message
            . ($detail ? ' detail=' . substr((string) $detail, 0, 1000) : ''),
            3
        );
        $payload = [
            'success' => false,
            'error' => [
                'code' => $code,
                'message' => $message,
            ],
        ];
        if ($detail !== null) {
            $payload['error']['detail'] = substr((string) $detail, 0, 1000);
        }
        $this->respond($status, $payload);
    }

    private function respond($status, $payload)
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        die(json_encode($payload));
    }

    private function authorized()
    {
        $expected = (string) Configuration::get(
            'HELIANTHA_MOBILE_BRIDGE_SECRET'
        );
        $provided = '';
        if (isset($_SERVER['HTTP_X_HELIANTHA_BRIDGE_SECRET'])) {
            $provided = (string) $_SERVER[
                'HTTP_X_HELIANTHA_BRIDGE_SECRET'
            ];
        }

        return $expected !== ''
            && $provided !== ''
            && hash_equals($expected, $provided);
    }

    private function jsonBody()
    {
        $raw = file_get_contents('php://input');
        $body = json_decode($raw, true);
        if (!is_array($body)) {
            $this->respond(400, [
                'success' => false,
                'error' => [
                    'code' => 'INVALID_JSON',
                    'message' => 'JSON invalide.',
                ],
            ]);
        }
        return $body;
    }

    public function postProcess()
    {
        register_shutdown_function([$this, 'handleFatalError']);

        try {
            if (!$this->authorized()) {
                $this->fail(401, 'UNAUTHORIZED_BRIDGE', 'Accès refusé.');
            }

            $action = Tools::getValue('action', 'preview');
            $body = $this->jsonBody();

            if ($action === 'confirm') {
                $this->confirm($body);
                return;
            }

            $this->preview($body);
        } catch (Throwable $e) {
            $this->fail(
                500,
                'BRIDGE_EXCEPTION',
                'Erreur checkout PrestaShop.',
                get_class($e) . ': ' . $e->getMessage()
            );
        }
    }

    public function handleFatalError()
    {
        $error = error_get_last();
        if (!$error) {
            return;
        }

        $fatalTypes = [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR];
        if (!in_array((int) $error['type'], $fatalTypes, true)) {
            return;
        }

        if (headers_sent()) {
            return;
        }

        $this->fail(
            500,
            'PHP_FATAL_ERROR',
            'Erreur fatale checkout PrestaShop.',
            'type=' . (int) $error['type']
            . ' message=' . (string) $error['message']
            . ' file=' . basename((string) $error['file'])
            . ' line=' . (int) $error['line']
        );
    }

    private function currencyForCart($cart)
    {
        $currency = new Currency((int) $cart->id_currency);
        if (!Validate::isLoadedObject($currency)) {
            $currency = $this->context->currency;
        }

        if (!Validate::isLoadedObject($currency) || empty($currency->iso_code)) {
            $this->fail(
                500,
                'INVALID_CURRENCY',
                'Devise PrestaShop introuvable pour le checkout.'
            );
        }

        return $currency;
    }

    private function formatCurrencyAmount($amount, $cart)
    {
        $currency = $this->currencyForCart($cart);

        return Tools::getContextLocale($this->context)->formatPrice(
            (float) $amount,
            (string) $currency->iso_code
        );
    }

    private function preview($body)
    {
        $cart = $this->buildCart($body, false);
        $summary = $cart->getSummaryDetails(null, true);
        foreach (['total_products_wt', 'total_shipping', 'total_price'] as $key) {
            if (!array_key_exists($key, $summary)) {
                $this->fail(
                    500,
                    'MISSING_CHECKOUT_TOTAL',
                    'Total checkout absent de la réponse PrestaShop.',
                    'key=' . $key
                );
            }
        }

        $currency = $this->currencyForCart($cart);
        $carriers = $this->availableCarriers($cart);
        $payments = $this->availablePayments($cart);
        $shipping = (float) $summary['total_shipping'];
        $selectedCarrierId = (int) $cart->id_carrier > 0
            ? (int) $cart->id_carrier
            : null;

        $this->respond(200, [
            'success' => true,
            'data' => [
                'totals' => [
                    'subtotal' => (float) $summary['total_products_wt'],
                    'subtotal_label' => $this->formatCurrencyAmount($summary['total_products_wt'], $cart),
                    'shipping' => $shipping,
                    'shipping_label' => $shipping == 0.0
                        ? 'Gratuit'
                        : $this->formatCurrencyAmount($shipping, $cart),
                    'discounts' => (float) ($summary['total_discounts'] ?? 0),
                    'discounts_label' => $this->formatCurrencyAmount($summary['total_discounts'] ?? 0, $cart),
                    'total_ttc' => (float) $summary['total_price'],
                    'total_ttc_label' => $this->formatCurrencyAmount($summary['total_price'], $cart),
                    'taxes_included' => true,
                    'currency' => (string) $currency->iso_code,
                    'currency_symbol' => (string) $currency->sign,
                    'source' => 'prestashop_cart',
                ],
                'carriers' => $carriers,
                'delivery_options' => $carriers,
                'selected_carrier_id' => $selectedCarrierId,
                'payments' => $payments,
                'stock_ok' => true,
                'reasons' => [
                    'carriers' => empty($carriers)
                        ? 'Aucun transporteur retourné par PrestaShop pour ce panier/adresse.'
                        : null,
                    'payments' => empty($payments)
                        ? 'Aucun module de paiement actif retourné par PrestaShop.'
                        : null,
                ],
            ],
        ]);
    }

    private function confirm($body)
    {
        $idempotencyKey = trim((string) ($body['idempotency_key'] ?? ''));
        if ($idempotencyKey === '') {
            $this->respond(422, [
                'success' => false,
                'error' => [
                    'code' => 'MISSING_IDEMPOTENCY_KEY',
                    'message' => 'Clé idempotency absente.',
                ],
            ]);
        }

        $existing = Configuration::get(
            'HELIANTHA_ORDER_' . md5($idempotencyKey)
        );
        if ($existing) {
            $this->respond(409, [
                'success' => false,
                'error' => [
                    'code' => 'DUPLICATE_CHECKOUT',
                    'message' => 'Cette confirmation a déjà été traitée.',
                    'order_id' => (int) $existing,
                ],
            ]);
        }

        $cart = $this->buildCart($body, true);
        $paymentModule = (string) ($body['payment_module'] ?? '');
        $availablePayments = array_map(function ($payment) {
            return (string) ($payment['module'] ?? '');
        }, $this->availablePayments($cart));
        if ($paymentModule === ''
            || !Module::isEnabled($paymentModule)
            || !in_array($paymentModule, $availablePayments, true)) {
            $this->respond(422, [
                'success' => false,
                'error' => [
                    'code' => 'INVALID_PAYMENT',
                    'message' => 'Moyen de paiement indisponible pour ce panier.',
                ],
            ]);
        }

        $module = Module::getInstanceByName($paymentModule);
        if (!Validate::isLoadedObject($module)) {
            $this->respond(422, [
                'success' => false,
                'error' => [
                    'code' => 'INVALID_PAYMENT',
                    'message' => 'Module de paiement introuvable.',
                ],
            ]);
        }

        $secureKey = (string) $cart->secure_key;
        $total = (float) $cart->getOrderTotal(true, Cart::BOTH);
        $state = (int) Configuration::get('PS_OS_PREPARATION');
        $module->validateOrder(
            (int) $cart->id,
            $state,
            $total,
            $module->displayName,
            null,
            [],
            (int) $cart->id_currency,
            false,
            $secureKey
        );

        Configuration::updateValue(
            'HELIANTHA_ORDER_' . md5($idempotencyKey),
            (int) $module->currentOrder
        );
        $order = new Order((int) $module->currentOrder);

        $this->respond(200, [
            'success' => true,
            'data' => [
                'order_id' => (int) $module->currentOrder,
                'reference' => Validate::isLoadedObject($order)
                    ? (string) $order->reference
                    : null,
                'total' => $total,
                'currency' => (string) $this->currencyForCart($cart)->iso_code,
                'payment_module' => $paymentModule,
            ],
        ]);
    }

    private function buildCart($body, $persistAddress)
    {
        $cart = new Cart();
        $cart->id_lang = (int) ($body['language_id'] ?? Configuration::get('PS_LANG_DEFAULT'));
        $cart->id_currency = (int) ($body['currency_id'] ?? Configuration::get('PS_CURRENCY_DEFAULT'));
        $cart->id_shop = (int) Context::getContext()->shop->id;
        $cart->id_shop_group = (int) Context::getContext()->shop->id_shop_group;

        $customerId = (int) ($body['customer_id'] ?? 0);
        if ($customerId > 0) {
            $customer = new Customer($customerId);
            if (!Validate::isLoadedObject($customer) || !$customer->active) {
                $this->fail(
                    422,
                    'INVALID_CUSTOMER',
                    'Client PrestaShop introuvable ou inactif.'
                );
            }
        } else {
            $guest = is_array($body['guest'] ?? null) ? $body['guest'] : [];
            $customer = new Customer();
            $customer->firstname = (string) ($guest['firstname'] ?? 'Invite');
            $customer->lastname = (string) ($guest['lastname'] ?? 'Heliantha');
            $customer->email = (string) ($guest['email'] ?? ('guest-' . time() . '@heliantha.ma'));
            $customer->passwd = Tools::hash(Tools::passwdGen(16));
            $customer->is_guest = 1;
            $customer->active = 1;
            if ($persistAddress) {
                $customer->add();
            }
        }

        if (Validate::isLoadedObject($customer)) {
            $cart->id_customer = (int) $customer->id;
            $cart->secure_key = (string) $customer->secure_key;
        }

        $this->attachExistingAddressIfProvided($cart, $customer, $body);
        $cart->add();

        foreach (($body['lines'] ?? []) as $line) {
            $productId = (int) ($line['product_id'] ?? 0);
            $attributeId = (int) ($line['product_attribute_id'] ?? 0);
            $quantity = (int) ($line['quantity'] ?? 0);
            if ($productId <= 0 || $quantity <= 0) {
                continue;
            }

            $product = new Product(
                $productId,
                false,
                (int) $cart->id_lang,
                (int) $cart->id_shop
            );
            if (!Validate::isLoadedObject($product)
                || !(bool) $product->active
                || !(bool) $product->available_for_order) {
                $this->fail(
                    422,
                    'PRODUCT_NOT_ORDERABLE',
                    'Produit indisponible à la commande.',
                    'product_id=' . $productId
                );
            }

            $updated = $cart->updateQty($quantity, $productId, $attributeId);
            if (!$updated) {
                $availableQuantity = StockAvailable::getQuantityAvailableByProduct(
                    $productId,
                    $attributeId,
                    (int) $cart->id_shop
                );
                $this->fail(
                    409,
                    'INSUFFICIENT_STOCK',
                    'Stock insuffisant ou produit refusé par le panier PrestaShop.',
                    'product_id=' . $productId
                    . ' product_attribute_id=' . $attributeId
                    . ' requested=' . $quantity
                    . ' available=' . (int) $availableQuantity
                );
            }
        }

        if ($persistAddress && (int) $cart->id_address_delivery <= 0) {
            $this->attachAddress($cart, $customer, $body);
        }

        $this->applyCarrierIfProvided($cart, $body);

        return $cart;
    }

    private function attachExistingAddressIfProvided($cart, $customer, $body)
    {
        $addressId = (int) ($body['address_id'] ?? 0);
        if ($addressId <= 0) {
            return;
        }

        $address = new Address($addressId);
        if (!Validate::isLoadedObject($address) || (bool) $address->deleted) {
            $this->fail(
                422,
                'INVALID_ADDRESS',
                'Adresse PrestaShop introuvable.'
            );
        }

        if (Validate::isLoadedObject($customer)
            && (int) $address->id_customer !== (int) $customer->id) {
            $this->fail(
                403,
                'ADDRESS_FORBIDDEN',
                'Cette adresse n’appartient pas au client connecté.'
            );
        }

        $country = new Country((int) $address->id_country);
        if (!Validate::isLoadedObject($country)
            || !(bool) $country->active
            || strtoupper(trim((string) $country->iso_code)) !== 'MA') {
            $this->fail(
                422,
                'COUNTRY_NOT_ALLOWED',
                'Seules les adresses au Maroc sont acceptées.'
            );
        }

        // Compléter uniquement si vide depuis customer, sans écraser si déjà présent
        $needsUpdate = false;
        if (trim((string) $address->firstname) === '' && Validate::isLoadedObject($customer)) {
            $address->firstname = trim((string) $customer->firstname);
            $needsUpdate = true;
        }
        if (trim((string) $address->lastname) === '' && Validate::isLoadedObject($customer)) {
            $address->lastname = trim((string) $customer->lastname);
            $needsUpdate = true;
        }
        if ($needsUpdate) {
            $address->update();
        }

        $cart->id_address_delivery = (int) $address->id;
        $cart->id_address_invoice = (int) $address->id;
    }

    private function attachAddress($cart, $customer, $body)
    {
        $data = is_array($body['address'] ?? null) ? $body['address'] : [];
        $moroccoCountryId = $this->moroccoCountryIdFromBody($body);
        $requestedCountryId = (int) ($data['country_id'] ?? 0);
        if ($requestedCountryId > 0 && $requestedCountryId !== $moroccoCountryId) {
            $this->fail(
                422,
                'COUNTRY_NOT_ALLOWED',
                'Seules les adresses au Maroc sont acceptées.'
            );
        }
        $address = new Address();
        $address->id_customer = (int) $customer->id;

        $firstname = trim((string) ($data['firstname'] ?? ''));
        if ($firstname === '' && Validate::isLoadedObject($customer)) {
            $firstname = trim((string) $customer->firstname);
        }
        if ($firstname === '') {
            $firstname = 'Client';
        }

        $lastname = trim((string) ($data['lastname'] ?? ''));
        if ($lastname === '' && Validate::isLoadedObject($customer)) {
            $lastname = trim((string) $customer->lastname);
        }
        if ($lastname === '') {
            $lastname = 'Heliantha';
        }

        $address->firstname = $firstname;
        $address->lastname = $lastname;
        $address->address1 = (string) ($data['address1'] ?? '');
        $address->address2 = (string) ($data['address2'] ?? '');
        $address->postcode = (string) ($data['postcode'] ?? '');
        $address->city = (string) ($data['city'] ?? '');
        $address->phone = (string) ($data['phone'] ?? '');
        $address->id_country = $moroccoCountryId;
        $address->alias = 'Adresse mobile';
        $address->add();

        $cart->id_address_delivery = (int) $address->id;
        $cart->id_address_invoice = (int) $address->id;
        $cart->update();
    }


    private function moroccoCountryIdFromBody($body)
    {
        $countryId = (int) ($body['morocco_country_id'] ?? 0);
        if ($countryId > 0) {
            $country = new Country($countryId);
            if (Validate::isLoadedObject($country) && (bool) $country->active) {
                return $countryId;
            }
        }

        $id = (int) Country::getByIso('MA');
        if ($id > 0) {
            return $id;
        }

        $this->fail(422, 'MISSING_MOROCCO_COUNTRY', 'Pays Maroc absent.');
    }


    private function applyCarrierIfProvided($cart, $body)
    {
        $carrierId = (int) ($body['carrier_id'] ?? 0);
        if ($carrierId <= 0) {
            return;
        }

        $availableCarrierIds = array_map(function ($carrier) {
            return (int) ($carrier['id'] ?? 0);
        }, $this->availableCarriers($cart));
        if (!in_array($carrierId, $availableCarrierIds, true)) {
            $this->respond(422, [
                'success' => false,
                'error' => [
                    'code' => 'INVALID_CARRIER',
                    'message' => 'Transporteur indisponible pour ce panier.',
                ],
            ]);
        }

        $cart->id_carrier = $carrierId;
        $cart->setDeliveryOption([
            (int) $cart->id_address_delivery => $carrierId . ',',
        ]);
        $cart->update();
    }

    private function availableCarriers($cart)
    {
        $deliveryOptions = $cart->getDeliveryOptionList();
        $output = [];
        foreach ($deliveryOptions as $addressOptions) {
            foreach ($addressOptions as $option) {
                foreach (($option['carrier_list'] ?? []) as $carrierId => $carrierData) {
                    $carrier = new Carrier((int) $carrierId, (int) $cart->id_lang);
                    if (!Validate::isLoadedObject($carrier)) {
                        continue;
                    }
                    $price = (float) ($carrierData['price_with_tax'] ?? 0);
                    $output[] = [
                        'id' => (int) $carrier->id,
                        'carrier_id' => (int) $carrier->id,
                        'name' => (string) $carrier->name,
                        'delay' => (string) $carrier->delay,
                        'price' => $price,
                        'price_label' => $price == 0.0 ? 'Gratuit' : $this->formatCurrencyAmount($price, $cart),
                        'formatted_price' => $price == 0.0 ? 'Gratuit' : $this->formatCurrencyAmount($price, $cart),
                    ];
                }
            }
        }
        return array_values($output);
    }

    private function availablePayments($cart)
    {
        $modules = PaymentModule::getInstalledPaymentModules();
        $output = [];
        foreach ($modules as $row) {
            $module = Module::getInstanceById((int) $row['id_module']);
            if (!$module || !Module::isEnabled($module->name)) {
                continue;
            }
            $output[] = [
                'module' => (string) $module->name,
                'name' => (string) $module->displayName,
            ];
        }
        return $output;
    }
}
