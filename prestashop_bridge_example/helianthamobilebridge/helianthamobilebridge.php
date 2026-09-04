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
        $this->description = 'Pont privé entre FastAPI et PrestaShop.';
    }

    public function install()
    {
        return parent::install()
            && Configuration::updateValue(
                'HELIANTHA_MOBILE_BRIDGE_SECRET',
                Tools::passwdGen(64)
            );
    }

    public function uninstall()
    {
        return Configuration::deleteByName(
            'HELIANTHA_MOBILE_BRIDGE_SECRET'
        ) && parent::uninstall();
    }

    public function getContent()
    {
        $html = '';

        if (Tools::isSubmit('submitHelianthaMobileBridge')) {
            $secret = trim((string) Tools::getValue('bridge_secret'));
            if (strlen($secret) < 32) {
                $html .= $this->displayError(
                    'Le secret doit contenir au moins 32 caractères.'
                );
            } else {
                Configuration::updateValue(
                    'HELIANTHA_MOBILE_BRIDGE_SECRET',
                    $secret
                );
                $html .= $this->displayConfirmation('Secret enregistré.');
            }
        }

        $secret = Configuration::get(
            'HELIANTHA_MOBILE_BRIDGE_SECRET'
        );

        $html .= '
        <form method="post">
            <div class="panel">
                <h3>Heliantha Mobile Bridge</h3>
                <label>Secret partagé FastAPI</label>
                <input type="text"
                       name="bridge_secret"
                       value="' . htmlspecialchars($secret) . '" />
                <br><br>
                <button class="btn btn-primary"
                        name="submitHelianthaMobileBridge"
                        type="submit">
                    Enregistrer
                </button>
            </div>
        </form>';

        return $html;
    }
}
