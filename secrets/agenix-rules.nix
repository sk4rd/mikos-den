let
  # YubiKey 5 NFC, serial 25869697
  yubikey-nfc = "age1yubikey1qw2vls742p5ze0kas05yqy0zwtxqs2emyd08jshkr85rnqcqzr60v329pht";
  # YubiKey 5C NFC, serial 23819186
  yubikey-5c = "age1yubikey1qvv8k4h50rz8jm5cd3f5p5cxhrk4kpcjqku9ex0ysw4z65fgkx0qs8ju4mu";

  workstation = "age1f0yks700exlasn6jus303nl75wetygq5r2latlkqcdg208t2gskq0ft7hn";
  thinkpad-z13 = "age1sfm9tdux8938qz7g8h2n922rdrt7pmzhthum06zxnahwj5umfppq2fcek2";
  nas = "age1njvrlp0n02uulwjtd7eh5vlxgel4x7u4c5mprkxy9mrlwm4nav4sq3w7hn";
in
{
  "miko-password.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    workstation
    thinkpad-z13
    nas
  ];
  "wg-server-key.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    nas
  ];
  "wg-thinkpad-env.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    thinkpad-z13
  ];
  "cloudflare-dns-token.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    nas
  ];
  "proton-nas-key.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    nas
  ];
  "gatus-env.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    nas
  ];
  "proton-thinkpad-env.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    thinkpad-z13
  ];
  "proton-workstation-env.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    workstation
  ];
  "restic-password.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    nas
  ];
  "couchdb-admin.age".publicKeys = [
    yubikey-nfc
    yubikey-5c
    nas
  ];
}
