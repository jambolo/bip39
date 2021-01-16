# bip39
BIP-39 tools using Node and implemented in Coffeescript

## encode
Encodes the input into a mnemonic string.

#### Command syntax

    encode [--words <number>] [--strict] [--language <language>] [--json] (hex|base58|base64) <input>

#### Formats (one must be specified)

| Format | Description |
|--------|-------------|
| hex    | Input is a hex value |
| base58 | Input is a Bitcoin address or private key encoded using base-58 |
| base64 | Input is a base-64 value |

#### Options

| Option         | Description |
|----------------|-------------|
| --words, -n    | Number of words to be generated. The input is truncated or padded with 0's if it doesn't match the specified value. If --strict is specified and the input doesn't match, the encode will fail. |
| --strict, -s   | The length of the input must match the number of words (if specified). |
| --language, -l | The wordlist to use. Currently, only *english* is supported and it is the default. |
| --json, -j     | Outputs the words in json format |

#### Notes

* The size of a BIP-39 source must be a multiple of 32 bits. If the size of the input is not a multiple of 32 bits, then it is automatically padded with 0's.
* If the input is _automatically_ padded (i.e, padded without the use of `--words` ), the length of the input (up to 255) is stored in the last byte of the padding. This is an incomplete solution to the problem of the varying size of a WIF-encoded private key. If you don't want this value in the padding, use `--words`.

## decode
Decodes a mnemonic string back to the source value.

#### Command syntax

    decode [--language <language>] (address|wif|base58|base64|hex) <mnemonic phrase>

#### Formats (one must be specified)

| Format   | Description |
|----------|-------------|
|  address | Decoded into a bitcoin address.  |
|  wif     | Decoded into a WIF-formatted private key. |
|  base58  | Output format is base-58. |
|  base64  | Output format is base-64. |
|  hex     | Output format is hex. |

#### Options

| Option          | Description |
|-----------------|-------------|
|  --language, -l | The wordlist to be used to validate the mnemonic phrase. Currently, only *english* is supported and it is the default. (optional) |


## seed
Generates a seed from a mnemonic string.

#### Command syntax

    seed [--passphrase <passphrase>] [--validate] [--language <language>] <mnemonic phrase>

#### Options

| Option           | Description |
|------------------|-------------|
| --passphrase, -p | Passphrase. (optional) |
| --validate, -v   | If specified, the mnemonic phrase is validated. (optional) |
| --language, -l   | The wordlist used to validate the mnemonic phrase. Currently, only *english* is supported and it is the default. (optional) |

## share
Uses Shamir Secret Sharing or XOR to create multiple mnemonic phrases that can be joined to recreate the original.

#### Command syntax

    share [--language <language>] [--json] sss <M> <N> <mnemonic phrase>
    share [--language <language>] [--json] xor <N>     <mnemonic phrase>

#### Methods

| Method | Description |
|--------|-------------|
| sss    | Shamir Secret Sharing |
| xor    | XOR |

#### Sharing Parameters

| Sharing Parameter  | Description |
|--------------------|-------------|
| M                  | Minimum shares necessary to recreate the original. |
| N                  | Number of shares |

#### Options

| Option         | Description |
|----------------|-------------|
| --language, -l | The wordlist to be used. Currently, only *english* is supported and it is the default. (optional) |
| --json, -j     | Outputs the words in json format. (optional) |

One method of sharing is a secret is Shamir Secret Sharing (SSS). A description can be found here: [Wikipedia](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing). Using SSS you can generate *N* shares, of which *M* are required in order to recreate the original mnemonic.

Another method for for sharing a secret is called the XOR method. This implementation is based on the implementation described here: [XOR Seed Splitting: Theory and Practice](https://github.com/mmgen/mmgen/wiki/XOR-Seed-Splitting:-Theory-and-Practice). In this scheme, all shares are required.

This program decodes the mnemonic and generates the shares, which are then re-encoded. Note that while the encoded share phrases have the standard BIP-39 error-detection, there is no way to ensure that the value recreated by joining shares matches the original value.

## join
Uses Shamir Secret Sharing or XOR method to recreate the original mnemonic phrase from shares read from stdin.

#### Command syntax

    join [--language <language>] [--json] (sss|xor)

#### Methods (one must be specified)

| Method | Description |
|--------|-------------|
| sss    | Shamir Secret Sharing |
| xor    | XOR |

#### Options

| Option         | Description |
|----------------|-------------|
| --language, -l | The wordlist to be used. Currently, only *english* is supported and it is the default. (optional) |
| --json, -j     | Outputs the words in json format. (optional) |

The shares are read from stdin, one per line and joined using SSS or the XOR method.

## missing
Generates all possible mnemonic phrases, given a partial mnemonic phrase.

#### Command syntax

    missing [--language <language>] [--indexes <list>|--end|--any] [--count <N>] [--verbose] [--json] <mnemonic phrase>

#### Options

| Option         | Description |
|----------------|-------------|
| --any, -a      | Signifies that the missing words in the phrase can be at any location. (optional) |
| --count, -n    | Total number of words in the mnemonic phrase. (default is a multiple of 3 and depends on how many are known) |
| --end, -e      | Signifies that the last words in phrase are missing. (default) |
| --indexes, -i  | List of the possible locations of the missing words. The first location is 1. Use - to end the list if it is not followed by another option. (optional) |
| --json, -j     | The possible mnemonics are listed in json format. (optional)
| --language, -l | The wordlist to be used. Currently, only *english* is supported and it is the default. (optional)
| --verbose, -v  | Displays helpful information in addition to the results. (optional)

#### Examples:

* All but the last two words of a 12-word mnemonic are known:

      missing crisp three spoil enhance dial client moment melt parade aisle

* Two missing words could be anywhere:

      missing --any crisp three enhance dial client melt parade aisle analyst case

* The two missing words could be at locations 1, 3, or 7:

      missing --indexes 1 3 7 --count 12 crisp three enhance dial client melt parade aisle analyst case

* A count should be specified because eight known words implies a 9-word phrase and this one has 12 words:

      missing --count 12 crisp three spoil enhance dial client moment melt:
