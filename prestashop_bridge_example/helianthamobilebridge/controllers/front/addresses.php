<?php

class HelianthaMobileBridgeAddressesModuleFrontController
    extends ModuleFrontController
{
    public $ajax = true;

    private function respond($status, $payload)
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        die(json_encode($payload));
    }

    private function fail($status, $code, $message, $detail = null)
    {
        PrestaShopLogger::addLog(
            'HelianthaMobileBridge addresses ' . $code . ': ' . $message
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
            $this->fail(400, 'INVALID_JSON', 'JSON invalide.');
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

            $action = Tools::getValue('action', 'create');
            $body = $this->jsonBody();

            if ($action === 'update') {
                $this->updateAddress($body);
                return;
            }

            $this->createAddress($body);
        } catch (Throwable $e) {
            $this->fail(
                500,
                'BRIDGE_EXCEPTION',
                'Erreur adresse PrestaShop.',
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
            'Erreur fatale adresse PrestaShop.',
            'type=' . (int) $error['type']
            . ' message=' . (string) $error['message']
            . ' file=' . basename((string) $error['file'])
            . ' line=' . (int) $error['line']
        );
    }

    private function createAddress($body)
    {
        $customer = $this->customerFromBody($body);
        $address = new Address();
        $this->fillAddress($address, $customer, $body);
        $this->validateAddress($address);

        if (!$address->add()) {
            $this->fail(500, 'ADDRESS_CREATE_FAILED', 'Adresse non créée.');
        }

        $this->respondAddress($address);
    }

    private function updateAddress($body)
    {
        $customer = $this->customerFromBody($body);
        $addressId = (int) (($body['address']['address_id'] ?? 0));
        if ($addressId <= 0) {
            $this->fail(422, 'MISSING_ADDRESS_ID', 'Adresse à modifier absente.');
        }

        $address = new Address($addressId);
        if (!Validate::isLoadedObject($address) || (bool) $address->deleted) {
            $this->fail(404, 'ADDRESS_NOT_FOUND', 'Adresse introuvable.');
        }
        if ((int) $address->id_customer !== (int) $customer->id) {
            $this->fail(403, 'ADDRESS_FORBIDDEN', 'Adresse interdite.');
        }

        $this->fillAddress($address, $customer, $body);
        $this->validateAddress($address);

        if (!$address->update()) {
            $this->fail(500, 'ADDRESS_UPDATE_FAILED', 'Adresse non modifiée.');
        }

        $this->respondAddress($address);
    }

    private function customerFromBody($body)
    {
        $customerId = (int) ($body['customer_id'] ?? 0);
        if ($customerId <= 0) {
            $this->fail(422, 'MISSING_CUSTOMER', 'Client absent.');
        }

        $customer = new Customer($customerId);
        if (!Validate::isLoadedObject($customer) || !(bool) $customer->active) {
            $this->fail(422, 'INVALID_CUSTOMER', 'Client introuvable ou inactif.');
        }

        return $customer;
    }

    private function fillAddress($address, $customer, $body)
    {
        $data = is_array($body['address'] ?? null) ? $body['address'] : [];
        $moroccoCountryId = (int) ($body['morocco_country_id'] ?? 0);
        $requestedCountryId = (int) ($data['country_id'] ?? 0);

        if ($moroccoCountryId <= 0) {
            $this->fail(422, 'MISSING_MOROCCO_COUNTRY', 'Pays Maroc absent.');
        }

        if ($requestedCountryId > 0 && $requestedCountryId !== $moroccoCountryId) {
            $this->fail(
                422,
                'COUNTRY_NOT_ALLOWED',
                'Seules les adresses au Maroc sont acceptées.'
            );
        }

        $address->id_customer = (int) $customer->id;
        $address->alias = trim((string) ($data['alias'] ?? 'Adresse'));
        $address->firstname = trim((string) ($data['firstname'] ?? $customer->firstname));
        $address->lastname = trim((string) ($data['lastname'] ?? $customer->lastname));
        $address->company = trim((string) ($data['company'] ?? ''));
        $address->address1 = trim((string) ($data['address1'] ?? ''));
        $address->address2 = trim((string) ($data['address2'] ?? ''));
        $address->postcode = trim((string) ($data['postcode'] ?? ''));
        $address->city = trim((string) ($data['city'] ?? ''));
        $address->id_country = $moroccoCountryId;
        $address->id_state = (int) ($data['state_id'] ?? 0);
        $address->phone = trim((string) ($data['phone'] ?? ''));
        $address->phone_mobile = trim((string) ($data['phone_mobile'] ?? ''));
        $address->active = 1;
        $address->deleted = 0;
    }

    private function validateAddress($address)
    {
        if ((int) $address->id_country <= 0) {
            $this->fail(422, 'INVALID_COUNTRY', 'Pays obligatoire.');
        }

        $country = new Country((int) $address->id_country);
        if (!Validate::isLoadedObject($country) || !(bool) $country->active) {
            $this->fail(422, 'INVALID_COUNTRY', 'Pays PrestaShop invalide.');
        }

        $fields = $address->validateFields(false, true);
        if ($fields !== true) {
            $this->fail(422, 'INVALID_ADDRESS', 'Adresse invalide.', $fields);
        }

        $fieldsLang = $address->validateFieldsLang(false, true);
        if ($fieldsLang !== true) {
            $this->fail(422, 'INVALID_ADDRESS_LANG', 'Adresse invalide.', $fieldsLang);
        }
    }

    private function respondAddress($address)
    {
        $this->respond(200, [
            'success' => true,
            'data' => [
                'id' => (int) $address->id,
            ],
        ]);
    }
}
