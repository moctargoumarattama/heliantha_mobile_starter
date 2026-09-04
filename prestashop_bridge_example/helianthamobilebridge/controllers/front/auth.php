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
}
