<?php

class HelianthaMobileBridgeAuthModuleFrontController
    extends ModuleFrontController
{
    public $ajax = true;

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

    public function postProcess()
    {
        if (!$this->authorized()) {
            $this->respond(401, [
                'success' => false,
                'error' => [
                    'code' => 'UNAUTHORIZED_BRIDGE',
                    'message' => 'Accès refusé.',
                ],
            ]);
        }

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

        $email = trim((string) ($body['email'] ?? ''));
        $password = (string) ($body['password'] ?? '');

        $action = (string) Tools::getValue('action', 'login');
        if ($action === 'register') {
            $this->registerCustomer($body, $email, $password);
            return;
        }

        if (!Validate::isEmail($email) || $password === '') {
            $this->respond(422, [
                'success' => false,
                'error' => [
                    'code' => 'INVALID_CREDENTIALS',
                    'message' => 'Email ou mot de passe invalide.',
                ],
            ]);
        }

        $customer = new Customer();

        /*
         * Customer::getByEmail avec mot de passe délègue la validation
         * au mécanisme PrestaShop de la version installée.
         * À vérifier sur la version réelle avant production.
         */
        $loaded = $customer->getByEmail($email, $password);

        if (!$loaded || !$customer->id || !$customer->active) {
            $this->respond(401, [
                'success' => false,
                'error' => [
                    'code' => 'BAD_LOGIN',
                    'message' => 'Email ou mot de passe incorrect.',
                ],
            ]);
        }

        $this->respond(200, [
            'success' => true,
            'data' => [
                'id' => (int) $customer->id,
                'email' => (string) $customer->email,
                'firstname' => (string) $customer->firstname,
                'lastname' => (string) $customer->lastname,
            ],
        ]);
    }

    private function registerCustomer($body, $email, $password)
    {
        $firstname = trim((string) ($body['firstname'] ?? ''));
        $lastname = trim((string) ($body['lastname'] ?? ''));

        if (!Validate::isEmail($email)
            || $password === ''
            || $firstname === ''
            || $lastname === '') {
            $this->respond(422, [
                'success' => false,
                'error' => [
                    'code' => 'INVALID_REGISTER_DATA',
                    'message' => 'Informations de création de compte invalides.',
                ],
            ]);
        }

        if (Customer::customerExists($email)) {
            $this->respond(409, [
                'success' => false,
                'error' => [
                    'code' => 'CUSTOMER_EXISTS',
                    'message' => 'Un compte existe déjà avec cet email.',
                ],
            ]);
        }

        $customer = new Customer();
        $customer->firstname = $firstname;
        $customer->lastname = $lastname;
        $customer->email = $email;
        $customer->passwd = Tools::hash($password);
        $customer->active = 1;
        $customer->is_guest = 0;

        $fields = $customer->validateFields(false, true);
        if ($fields !== true) {
            $this->respond(422, [
                'success' => false,
                'error' => [
                    'code' => 'INVALID_CUSTOMER_FIELDS',
                    'message' => 'Informations client invalides.',
                ],
            ]);
        }

        if (!$customer->add()) {
            $this->respond(500, [
                'success' => false,
                'error' => [
                    'code' => 'CUSTOMER_CREATE_FAILED',
                    'message' => 'Compte non créé.',
                ],
            ]);
        }

        $this->respond(200, [
            'success' => true,
            'data' => [
                'id' => (int) $customer->id,
                'email' => (string) $customer->email,
                'firstname' => (string) $customer->firstname,
                'lastname' => (string) $customer->lastname,
            ],
        ]);
    }
}
