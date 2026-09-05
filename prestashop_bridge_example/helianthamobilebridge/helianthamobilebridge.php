<?php
if (!defined('_PS_VERSION_')) {
    exit;
}

class HelianthaMobileBridge extends Module
{
    public function __construct()
    {
        $this->name = 'helianthamobilebridge';
        $this->tab = 'administration';
        $this->version = '0.1.0';
        $this->author = 'Heliantha';
        $this->need_instance = 0;
        $this->bootstrap = true;

        parent::__construct();

        $this->displayName = 'Heliantha Mobile Bridge';
        $this->description = 'Pont prive entre FastAPI et PrestaShop.';
    }

    public function install()
    {
        return parent::install()
            && $this->registerHook('actionOrderStatusPostUpdate')
            && $this->registerHook('actionUpdateQuantity')
            && Configuration::updateValue(
                'HELIANTHA_MOBILE_BRIDGE_SECRET',
                Tools::passwdGen(64)
            )
            && Configuration::updateValue(
                'HELIANTHA_MOBILE_NOTIFICATION_SECRET',
                Tools::passwdGen(64)
            );
    }

    public function uninstall()
    {
        return Configuration::deleteByName('HELIANTHA_MOBILE_BRIDGE_SECRET')
            && Configuration::deleteByName('HELIANTHA_MOBILE_NOTIFICATION_SECRET')
            && Configuration::deleteByName('HELIANTHA_MOBILE_API_URL')
            && parent::uninstall();
    }

    public function hookActionOrderStatusPostUpdate($params)
    {
        $orderId = (int) ($params['id_order'] ?? 0);
        $state = $params['newOrderStatus'] ?? null;
        if ($orderId <= 0 || !Validate::isLoadedObject($state)) {
            return;
        }

        $this->postMobileNotificationEvent('/v1/notifications/prestashop-event', [
            'type' => 'ORDER_STATUS',
            'order_id' => $orderId,
            'status_key' => 'order-' . (int) $state->id,
            'metadata' => ['source' => 'actionOrderStatusPostUpdate'],
        ]);

        if ((bool) $state->paid) {
            $this->postMobileNotificationEvent('/v1/notifications/prestashop-event', [
                'type' => 'PAYMENT_STATUS',
                'order_id' => $orderId,
                'status_key' => 'payment-paid-' . (int) $state->id,
                'metadata' => ['source' => 'actionOrderStatusPostUpdate'],
            ]);
        }
    }

    public function hookActionUpdateQuantity($params)
    {
        $productId = (int) ($params['id_product'] ?? 0);
        if ($productId <= 0) {
            return;
        }

        $quantity = (int) ($params['quantity'] ?? 0);
        $product = new Product($productId, false, (int) $this->context->language->id);
        $name = Validate::isLoadedObject($product) ? (string) $product->name : '';

        $this->postMobileNotificationEvent('/v1/notifications/favorite-stock', [
            'product_id' => $productId,
            'quantity' => $quantity,
            'product_name' => $name,
            'id_shop' => (int) $this->context->shop->id,
        ]);
    }

    private function postMobileNotificationEvent($path, $payload)
    {
        $apiUrl = rtrim((string) Configuration::get('HELIANTHA_MOBILE_API_URL'), '/');
        $secret = (string) Configuration::get('HELIANTHA_MOBILE_NOTIFICATION_SECRET');
        if ($apiUrl === '' || $secret === '' || strpos($apiUrl, 'https://') !== 0) {
            return;
        }

        $ch = curl_init($apiUrl . $path);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 1);
        curl_setopt($ch, CURLOPT_TIMEOUT, 2);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'X-Heliantha-Bridge-Secret: ' . $secret,
        ]);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        if ($status >= 400) {
            PrestaShopLogger::addLog(
                'HelianthaMobileBridge notification HTTP ' . $status,
                2
            );
        }
        curl_close($ch);
    }

    public function getContent()
    {
        $html = '';

        if (Tools::isSubmit('submitHelianthaMobileBridge')) {
            $bridgeSecret = trim((string) Tools::getValue('bridge_secret'));
            $notificationSecret = trim((string) Tools::getValue('notification_secret'));
            $apiUrl = trim((string) Tools::getValue('mobile_api_url'));

            if (strlen($bridgeSecret) < 32 || strlen($notificationSecret) < 32) {
                $html .= $this->displayError('Les secrets doivent contenir au moins 32 caracteres.');
            } elseif ($apiUrl !== '' && strpos($apiUrl, 'https://') !== 0) {
                $html .= $this->displayError('URL API mobile: utilisez une URL HTTPS publique.');
            } else {
                Configuration::updateValue('HELIANTHA_MOBILE_BRIDGE_SECRET', $bridgeSecret);
                Configuration::updateValue('HELIANTHA_MOBILE_NOTIFICATION_SECRET', $notificationSecret);
                Configuration::updateValue('HELIANTHA_MOBILE_API_URL', $apiUrl);
                $html .= $this->displayConfirmation('Configuration enregistree.');
            }
        }

        $bridgeSecret = Configuration::get('HELIANTHA_MOBILE_BRIDGE_SECRET');
        $notificationSecret = Configuration::get('HELIANTHA_MOBILE_NOTIFICATION_SECRET');
        $apiUrl = Configuration::get('HELIANTHA_MOBILE_API_URL');

        $html .= '
        <form method="post">
            <div class="panel">
                <h3>Heliantha Mobile Bridge</h3>
                <label>Secret bridge checkout/auth/adresses</label>
                <input type="text" name="bridge_secret" value="' . htmlspecialchars($bridgeSecret) . '" />
                <br><br>
                <label>Secret webhooks notifications</label>
                <input type="text" name="notification_secret" value="' . htmlspecialchars($notificationSecret) . '" />
                <br><br>
                <label>URL HTTPS publique API mobile FastAPI</label>
                <input type="text" name="mobile_api_url" value="' . htmlspecialchars($apiUrl) . '" />
                <p class="help-block">Laisser vide en developpement local. Ne pas utiliser http://127.0.0.1:8000 sur le serveur PrestaShop.</p>
                <br>
                <button class="btn btn-primary" name="submitHelianthaMobileBridge" type="submit">
                    Enregistrer
                </button>
            </div>
        </form>';

        return $html;
    }
}
