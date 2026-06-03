# Secure Boot / MOK assets for the laptop

Expected private key/certificate bundle:

```text
/etc/kernel/secureboot/MOK.pem
```

Expected public certificate for MOK enrollment:

```text
/etc/kernel/secureboot/MOK.cer
```

`MOK.pem` contains the private key. Keep it local, owned by root, and never share it.

Generate locally:

```bash
sudo /etc/kernel/secureboot/generate_mok.sh
```

Enroll public certificate:

```bash
sudo mokutil --import /etc/kernel/secureboot/MOK.cer
```

After reboot, enter MOK Manager and enroll the key.

The laptop `make.conf` points these variables here:

```bash
SECUREBOOT_SIGN_KEY="/etc/kernel/secureboot/MOK.pem"
SECUREBOOT_SIGN_CERT="/etc/kernel/secureboot/MOK.pem"
MODULES_SIGN_KEY="/etc/kernel/secureboot/MOK.pem"
MODULES_SIGN_CERT="/etc/kernel/secureboot/MOK.pem"
```
