# bip39
BIP-39 tools using Node and implemented in Coffeescript

## encode
Encodes the input into a mnemonic string.

#### Command syntax

    encode (hex|base58|base64) [--words <number>] [--strict] [--language english] [--json] <input>

#### Formats (one must be specified)

| Formats | Description |
|---------|-------------|
| hex     | Input is a hex value |
| base58  | Input is a Bitcoin address or private key encoded using base-58 |
| base64  | Input is a base-64 value |

#### Options (all are optional)

| Options                       | Description |
|-------------------------------|-------------|
| --words `number`, -n `number` | Number of words to be generated. The input is truncated or padded with 0's if it doesn't match the specified value. If --strict is specified and the input doesn't match, the encode will fail. |
| --strict, -s                  | The length of the input must match the number of words (if specified). |
| --language, -l                | The wordlist to use. Currently, only english is supported and it is the default. |
| --json, -j                    | Outputs the words in json format |

#### Notes

* The size of a BIP-39 source must be a multiple of 32 bits. If the size of the input is not a multiple of 32 bits, then it is automatically padded with 0's.
* If the input is _automatically_ padded (i.e, padded without the use of `--words` ), the length of the input (up to 255) is stored in the last byte of the padding. This is an incomplete solution to the problem of the varying size of a WIF-encoded private key. If you don't want this value in the padding, use `--words`.

## decode
Decodes a mnemonic string back to the source value.

#### Command syntax

    decode (address|wif|base58|base64|hex) [--language english] <mnemonic phrase>

#### Formats (one must be specified)

| Formats  | Description |
|----------|-------------|
|  address | Decoded into a bitcoin address.  |
|  wif     | Decoded into a WIF-formatted private key. |
|  base58  | Output format is base-58. |
|  base64  | Output format is base-64. |
|  hex     | Output format is hex. |

#### Options (all are optional)

| Options         | Description |
|-----------------|-------------|
|  --language, -l | The wordlist to be used to validate the mnemonic phrase (optional). |


## seed
Generates a seed from a mnemonic string.

#### Command syntax

    seed [--passphrase <passphrase>] [--validate] [--language english] <mnemonic phrase>

#### Options (all are optional)

| Options | Description |
|---------|-------------|
| --passphrase, -p | Passphrase. (optional) |
| --validate, -v   | If specified, the mnemonic phrase is validated (optional). |
| --language, -l   | The wordlist to be used to validate the mnemonic phrase. Currently, only english is supported and it is the default. |
