let
  yubikey = "age1yubikey1qw2vls742p5ze0kas05yqy0zwtxqs2emyd08jshkr85rnqcqzr60v329pht";
  workstation = "age1f0yks700exlasn6jus303nl75wetygq5r2latlkqcdg208t2gskq0ft7hn";
  thinkpad-z13 = "age1sfm9tdux8938qz7g8h2n922rdrt7pmzhthum06zxnahwj5umfppq2fcek2";
  nas = "age1njvrlp0n02uulwjtd7eh5vlxgel4x7u4c5mprkxy9mrlwm4nav4sq3w7hn";
in
{
  "miko-password.age".publicKeys = [
    yubikey
    workstation
    thinkpad-z13
    nas
  ];
  "wg-server-key.age".publicKeys = [
    yubikey
    nas
  ];
  "wg-thinkpad-env.age".publicKeys = [
    yubikey
    thinkpad-z13
  ];
  "cloudflare-dns-token.age".publicKeys = [
    yubikey
    nas
  ];
  "proton-nas-key.age".publicKeys = [
    yubikey
    nas
  ];
  "proton-thinkpad-env.age".publicKeys = [
    yubikey
    thinkpad-z13
  ];
  "proton-workstation-env.age".publicKeys = [
    yubikey
    workstation
  ];
}
