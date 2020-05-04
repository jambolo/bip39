# bip39
BIP-39 tools using Node and implemented in Coffeescript

## encode
Encodes the input into a mnemonic string.

Note that the size of a BIP-39 source must be a multiple of 32 bits. If the size of the input is not a multiple of 32 bits, then it is padded with 0's.

#### Command syntax:

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

## decode
Decodes a mnemonic string back to the source value.

## seed
Generates a seed from a mnemonic string.

#### Command syntax

    seed [--passphrase <passphrase>] [--validate] [--language english] <mnemonic phrase>

#### Options

| Options | Description |
|---------|-------------|
| --passphrase, -p | Passphrase. (optional) |
| --validate, -v   | If specified, the mnemonic phrase is validated (optional). |
| --language, -l   | The wordlist to be used to validate the mnemonic phrase. Currently, only english is supported and it is the default. |
